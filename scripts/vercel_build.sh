#!/usr/bin/env bash
set -euo pipefail

# Vercel automated Flutter Web PWA build script for Cash-IO
# Clones Flutter stable shallowly (cached by Vercel build container if present)
# and builds a self-contained offline-ready PWA bundle with local CanvasKit & SQLite WASM.

FLUTTER_DIR="${HOME}/flutter"
if [ ! -d "${FLUTTER_DIR}" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release --no-web-resources-cdn --no-tree-shake-icons

cp web/sqlite3.wasm build/web/ || true
cp web/sqflite_sw.js build/web/ || true
