#!/bin/sh
cd "$(dirname "$0")"
echo "ClearSight Dehaze starting at http://127.0.0.1:8080"
( sleep 1; (command -v open >/dev/null && open http://127.0.0.1:8080) || (command -v xdg-open >/dev/null && xdg-open http://127.0.0.1:8080) ) &
python3 -m http.server 8080 --bind 127.0.0.1
