#!/bin/bash
#
# Build Standalone Executables for Treasure Hunter
# Creates .exe for Windows, .app for macOS, and AppImage for Linux
#

set -e

echo "🎮 Building Treasure Hunter Standalone Executables"
echo "=================================================="

# Check if love-release is installed
if ! command -v love-release &> /dev/null; then
    echo "Installing love-release..."
    luarocks install love-release
fi

# Create .love file first
echo ""
echo "📦 Creating .love package..."
cd "$(dirname "$0")"
zip -r ../TreasureHunter.love . -x "*.sh" -x "build_standalone.sh"

cd ..
echo "✓ Created TreasureHunter.love"

# Build for all platforms
echo ""
echo "🏗️  Building platform-specific executables..."
love-release -W -M -L TreasureHunter.love

echo ""
echo "✅ Build complete!"
echo ""
echo "Created files:"
ls -lh TreasureHunter-* 2>/dev/null || true
ls -lh *.love 2>/dev/null || true

echo ""
echo "📦 Distribution packages:"
echo "  - TreasureHunter-win64.zip     (Windows)"
echo "  - TreasureHunter-macos.zip     (macOS)"
echo "  - TreasureHunter-linux.tar.gz  (Linux)"
echo "  - TreasureHunter.love          (Universal, requires Love2D)"
echo ""
echo "Users can run these without installing Love2D!"
