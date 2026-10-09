#!/usr/bin/env python3
"""Audit/extract the user's *exact* original QGC APK; never rebuild or replace it."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import stat
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def safe_member(info: zipfile.ZipInfo) -> PurePosixPath:
    name = info.filename
    if not name or name.startswith(("/", "\\")) or "\\" in name:
        raise ValueError(f"Unsafe APK member name: {name!r}")
    p = PurePosixPath(name)
    if not p.parts or any(part in (".", "..") for part in p.parts):
        raise ValueError(f"Unsafe APK member path: {name!r}")
    if ":" in p.parts[0]:
        raise ValueError(f"Unsafe APK member drive path: {name!r}")
    kind = stat.S_IFMT(info.external_attr >> 16)
    if kind == stat.S_IFLNK:
        raise ValueError(f"Unexpected symbolic link in APK: {name!r}")
    return p


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Preserve and unpack EXACT original QGC APK, no upstream substitution."
    )
    parser.add_argument("apk", type=Path, help="Input original APK from user")
    parser.add_argument("--out", type=Path, default=Path("QGC_PRESERVED_AUDIT"))
    args = parser.parse_args()
    apk = args.apk.expanduser().resolve()
    output = args.out.expanduser().resolve()
    if not apk.is_file():
        raise FileNotFoundError(apk)
    if not zipfile.is_zipfile(apk):
        raise ValueError("Input is not a readable Android APK/ZIP container")
    if output.exists():
        raise FileExistsError(
            f"Output already exists: {output}; choose a new --out path to avoid mixing files"
        )

    archive_path = output.parent / (output.name + ".zip")
    if archive_path.exists():
        raise FileExistsError(f"Archive already exists: {archive_path}")

    original_dir = output / "original"
    files_dir = output / "unpacked"
    original_dir.mkdir(parents=True)
    files_dir.mkdir(parents=True)
    pristine_apk = original_dir / apk.name
    shutil.copy2(apk, pristine_apk)
    input_hash = sha256(apk)
    if sha256(pristine_apk) != input_hash:
        raise RuntimeError("Pristine APK copy does not match input SHA-256")

    entries = []
    with zipfile.ZipFile(apk) as src:
        bad = src.testzip()
        if bad:
            raise RuntimeError(f"APK ZIP CRC error in: {bad}")
        for info in src.infolist():
            rel = safe_member(info)
            dest = files_dir.joinpath(*rel.parts)
            if info.is_dir():
                dest.mkdir(parents=True, exist_ok=True)
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            if dest.exists():
                raise RuntimeError(f"Duplicate APK member: {info.filename}")
            h = hashlib.sha256()
            written = 0
            with src.open(info, "r") as reader, dest.open("xb") as writer:
                while True:
                    block = reader.read(1024 * 1024)
                    if not block:
                        break
                    writer.write(block)
                    written += len(block)
                    h.update(block)
            if written != info.file_size:
                raise RuntimeError(f"APK member size mismatch: {info.filename}")
            entries.append({
                "path": info.filename,
                "bytes": written,
                "sha256": h.hexdigest(),
                "compressed_bytes": info.compress_size,
                "zip_crc32": f"{info.CRC:08x}",
            })

    manifest = {
        "source_file": apk.name,
        "source_size_bytes": apk.stat().st_size,
        "source_sha256": input_hash,
        "preserved_copy_sha256": sha256(pristine_apk),
        "extracted_file_count": len(entries),
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_policy": "Original user APK only; no official QGC replacement.",
        "note": (
            "Original APK is a byte-exact copy. Extracted .so/.rcc/.dex are "
            "compiled binaries; extraction does NOT restore C++/QML source "
            "or add DEHAZING. Any modified APK needs separate integration, "
            "re-signing, and functional regression tests."
        ),
        "files": entries,
    }
    manifest_file = output / "MANIFEST_SHA256.json"
    manifest_file.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    with zipfile.ZipFile(
        archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6,
        allowZip64=True
    ) as package:
        for f in sorted(output.rglob("*")):
            if f.is_file():
                package.write(f, arcname=f"{output.name}/{f.relative_to(output).as_posix()}")
    with zipfile.ZipFile(archive_path) as check:
        broken = check.testzip()
        if broken:
            raise RuntimeError(f"Export archive CRC failed: {broken}")

    print("SOURCE APK:", apk)
    print("SOURCE SHA-256:", input_hash)
    print("PRESERVED ORIGINAL:", pristine_apk)
    print("EXTRACTED FILES:", len(entries))
    print("CONTENT INVENTORY:", manifest_file)
    print("OUTPUT ZIP:", archive_path)
    print("STATUS: Original APK bytes unchanged; DEHAZING is NOT integrated.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
