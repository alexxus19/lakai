#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/Build/DerivedData"
PRODUCT_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/Lakai.app"
OUTPUT_PATH="$ROOT_DIR/Build/Lakai.app"

mkdir -p "$ROOT_DIR/Build"

xcodebuild \
  -project "$ROOT_DIR/Lakai.xcodeproj" \
  -scheme Lakai \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

rm -rf "$OUTPUT_PATH"
ditto "$PRODUCT_PATH" "$OUTPUT_PATH"

echo "Test app available at: $OUTPUT_PATH"