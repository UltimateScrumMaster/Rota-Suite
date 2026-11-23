#!/usr/bin/env bash
# package.sh — Packaging and validation script for Rota Suite (WoW 3.3.5a / Interface 30300)
set -e

VERSION="1.0.0"
DIST_DIR="dist"
RELEASE_NAME="RotaSuite-v${VERSION}-3.3.5a"
ZIP_PATH="${DIST_DIR}/${RELEASE_NAME}.zip"

echo "=================================================="
echo " ROTA SUITE — PACKAGING PIPELINE (v${VERSION})     "
echo "=================================================="

# Step 1: Run Offline Test Runner
echo -e "\n[1/4] Running offline unit tests with Lua 5.1..."
if command -v lua5.1 >/dev/null 2>&1; then
    lua5.1 tools/test_runner.lua
    lua5.1 tools/golden.lua check
    echo ">>> All unit tests passed!"
else
    echo "WARNING: lua5.1 not found in PATH, skipping local test execution."
fi

# Step 2: Run Static Code Analysis (luacheck)
echo -e "\n[2/4] Running static analysis with luacheck..."
if command -v luacheck >/dev/null 2>&1; then
    luacheck .
    echo ">>> Luacheck validation passed with 0 errors and 0 warnings!"
else
    echo "WARNING: luacheck not found in PATH, skipping static analysis."
fi

# Step 3: Prepare Clean Distribution Directory
echo -e "\n[3/4] Preparing distribution directory (${DIST_DIR})..."
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

ADDONS=("RotaCore" "RotaEditor" "RotaClass_DK" "RotaClass_PAL" "RotaClass_WAR" "RotaClass_ROG" "RotaClass_SHA" "RotaClass_WL" "RotaClass_MAG" "RotaClass_PRI" "RotaClass_HUN" "RotaClass_DRU" "RotaProbe")

for addon in "${ADDONS[@]}"; do
    if [ -d "$addon" ]; then
        echo "  Copying $addon..."
        mkdir -p "${DIST_DIR}/${addon}"
        cp "$addon"/*.toc "${DIST_DIR}/${addon}/" 2>/dev/null || true
        cp "$addon"/*.lua "${DIST_DIR}/${addon}/" 2>/dev/null || true
    else
        echo "  WARNING: Directory $addon not found!"
    fi
done

# Step 4: Create Release Zip
echo -e "\n[4/4] Creating release archive: ${ZIP_PATH}..."
if command -v zip >/dev/null 2>&1; then
    cd "${DIST_DIR}"
    zip -r "${RELEASE_NAME}.zip" "${ADDONS[@]}" >/dev/null
    cd ..
    echo ">>> Archive successfully generated: ${ZIP_PATH}"
    ls -lh "${ZIP_PATH}"
else
    echo ">>> zip command not found; addons are prepared uncompressed in ${DIST_DIR}/"
fi

echo -e "\n=================================================="
echo " PACKAGING COMPLETE: Ready for deployment!        "
echo "=================================================="
