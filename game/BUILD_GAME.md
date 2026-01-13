# Building Standalone Treasure Hunter Executables

## Quick Build (.love file - works on all platforms)

```bash
cd game
zip -r ../TreasureHunter.love .
```

Users can double-click `TreasureHunter.love` if they have Love2D installed, or:
```bash
love TreasureHunter.love
```

---

## Platform-Specific Executables

### Windows (.exe)

1. Download Love2D Windows build from https://love2d.org
2. Create standalone:

```bash
cd game
zip -r game.zip .
cat /path/to/love.exe game.zip > TreasureHunter.exe
```

Or use the official tool:
```bash
# Download love-11.5-win64.zip
# Extract it
cd game
zip -r game.love .
copy /b "C:\path\to\love.exe"+"game.love" "TreasureHunter.exe"
```

### macOS (.app)

```bash
cd game
zip -r game.love .

# Download Love2D.app
cp -r /Applications/love.app TreasureHunter.app
cp game.love TreasureHunter.app/Contents/Resources/
# Edit TreasureHunter.app/Contents/Info.plist to rename
```

Or simpler - use our script:

```bash
./build_macos_app.sh
```

### Linux (AppImage)

```bash
cd game
zip -r game.love .

# Use love-appimage tool
# Or distribute the .love file (most Linux users have Love2D)
```

---

## Automated Build (GitHub Actions)

Our CI/CD automatically builds for all platforms on release. See `.github/workflows/game-release.yml`

When you push a tag like `game-v1.0.0`, it will:
1. Build .love file
2. Package for Windows (with love.exe)
3. Package for macOS (.app bundle)
4. Package for Linux (AppImage)
5. Upload all to GitHub Releases

---

## Distribution

Upload to:
- **GitHub Releases**: Automatic via CI
- **itch.io**: Upload .love + platform builds
- **Steam**: Use Love2D Steam wrapper
- **Game Jolt**: Direct upload

---

## Current Status

✅ Game works standalone (no blockchain)  
✅ Game works with SubLua (blockchain enabled)  
✅ .love file can be created manually  
⏳ Automated CI builds (needs workflow file)  
⏳ macOS .app bundling script  
⏳ Windows .exe packaging  

---

## For Users

**Easiest**: Download from [GitHub Releases](https://github.com/MontaQLabs/sublua/releases)

- Windows users: Download `TreasureHunter-Windows.zip`, extract, run `.exe`
- macOS users: Download `TreasureHunter-macOS.zip`, extract, run `.app`
- Linux users: Download `TreasureHunter-Linux.tar.gz`, extract, run binary

**Alternative**: If you have Love2D:
```bash
love TreasureHunter.love
```

No installation, no dependencies, just play!
