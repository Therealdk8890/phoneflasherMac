#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi

source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r build-requirements.txt

pyinstaller --noconfirm --clean --windowed --name "PhoneFlasherMac" --distpath dist --workpath build src/phoneflasher.py

echo "Built dist/PhoneFlasherMac.app"
