@echo off
cd /d "%~dp0"
echo ClearSight Dehaze starting at http://127.0.0.1:8080
where py >nul 2>nul && (start "" http://127.0.0.1:8080 & py -3 -m http.server 8080 --bind 127.0.0.1 & goto :eof)
where python >nul 2>nul && (start "" http://127.0.0.1:8080 & python -m http.server 8080 --bind 127.0.0.1 & goto :eof)
echo Python 3 not found. Install Python 3 and run this file again.
pause
