# 🎮 How to Play Treasure Hunter

## Quick Start (No Installation Required!)

### Option 1: Download Standalone Executable (Easiest)

**Coming Soon**: Pre-built executables will be available in [GitHub Releases](https://github.com/MontaQLabs/sublua/releases)

- **Windows**: Download `TreasureHunter-Windows.zip`, extract, and double-click `TreasureHunter.exe`
- **macOS**: Download `TreasureHunter-macOS.zip`, extract, and double-click `TreasureHunter.app`
- **Linux**: Download `TreasureHunter-Linux.tar.gz`, extract, and run `./TreasureHunter`

No SubLua, no dependencies, just play!

---

### Option 2: Run with Love2D (Recommended for Testing)

1. **Install Love2D** (5-minute setup):

   **macOS:**
   ```bash
   brew install love
   ```

   **Windows:**
   - Download from https://love2d.org
   - Install the `.exe`

   **Ubuntu/Debian:**
   ```bash
   sudo apt install love
   ```

   **Arch Linux:**
   ```bash
   sudo pacman -S love
   ```

2. **Download and Run:**

   ```bash
   # Clone the repo (or download ZIP from GitHub)
   git clone https://github.com/MontaQLabs/sublua.git
   cd sublua
   
   # Run the game
   love game/
   ```

   **That's it!** The game runs in demo mode without blockchain features.

---

### Option 3: Package as .love File

Create a portable `.love` file that runs on any platform with Love2D:

```bash
cd game
zip -r ../TreasureHunter.love .
cd ..

# Run it
love TreasureHunter.love
```

Share `TreasureHunter.love` with anyone - they just need Love2D installed.

---

## Game Controls

| Key | Action |
|-----|--------|
| **↑** or **W** | Move Up |
| **↓** or **S** | Move Down |
| **←** or **A** | Move Left |
| **→** or **D** | Move Right |
| **Enter** / **Space** | Select Menu Option |
| **ESC** | Back to Menu / Quit |

---

## How to Play

1. **Start Game** - Press Enter on the main menu
2. **Navigate the Grid** - Use arrow keys or WASD
3. **Collect Treasures** 💎 - Walk over them for +100 points + bonus rewards
4. **Avoid Obstacles** 🪨 - They block your path
5. **Complete Before Moves Run Out** - You have 20 moves per game

### Scoring

- **+1 point** per move
- **+100 points** per treasure collected
- **Bonus rewards** scale with score

### Token Economics (Demo Mode)

- **Entry Fee**: 0.1 WND (deducted from demo balance)
- **Base Reward**: 0.05 WND
- **Per Treasure**: 0.5 WND
- **Score Bonus**: +1% per 100 points

---

## Enabling Blockchain Features (Optional)

The game works perfectly in demo mode, but if you want real blockchain integration:

1. **Install SubLua:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/MontaQLabs/sublua/main/install_sublua.sh | bash
   ```

2. **Run the game** - it will auto-detect SubLua and enable:
   - Real wallet addresses
   - Live balance queries from Westend testnet
   - Actual on-chain transactions
   - Persistent leaderboard (via System.remark)

---

## Building Standalone Executables

Want to distribute the game without requiring Love2D?

### Install love-release

```bash
luarocks install love-release
```

### Build for All Platforms

```bash
cd game
love-release -W -M -L .
```

This creates:
- `TreasureHunter-win64.zip` (Windows)
- `TreasureHunter-macos.zip` (macOS)
- `TreasureHunter-linux.tar.gz` (Linux)

Users can run these without installing anything!

---

## Screenshots

```
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║      🏴‍☠️ TREASURE HUNTER 🏴‍☠️                              ║
║      A SubLua Blockchain Game Demo                        ║
║                                                           ║
║      🎮  Start Game                                       ║
║      👛  Wallet                                           ║
║      🏆  Leaderboard                                      ║
║      ❓  How to Play                                      ║
║      🚪  Exit                                             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

Game Grid:
┌─────────────────────┐     ┌─────────────────┐
│ 🧑 . . . . . . .    │     │  📊 GAME STATUS │
│ . 🪨 . 💎 . 🪨 . .  │     │                 │
│ . . 🪨 . . . 💎 .  │     │  Score: 45      │
│ . 💎 . . 🪨 . . .  │     │  Moves: 12      │
│ . . . . . . 🪨 💎  │     │  Treasures: 2/5 │
│ . 🪨 . . . . . .   │     │                 │
│ . . . 💎 . . . .   │     │  Balance:       │
│ . . . . . . . .    │     │  9.85 WND       │
└─────────────────────┘     └─────────────────┘
```

---

## Troubleshooting

**Q: Game window doesn't open**
- Make sure Love2D is installed: `love --version`
- Try running from the terminal: `love game/`

**Q: "module 'sublua' not found" error**
- This is normal! The game detects this and runs in demo mode.
- To enable blockchain, install SubLua (see above)

**Q: Performance issues**
- Update graphics drivers
- Close other applications
- The game is optimized for 60 FPS on any modern computer

**Q: Where's my high score saved?**
- In demo mode: Scores are session-only (lost on exit)
- With SubLua: Scores can be stored on-chain (coming in v0.4.0)

---

## Development

Want to modify the game?

```bash
cd game
# Edit main.lua or conf.lua
love .   # Test your changes instantly
```

The game uses:
- Love2D 11.4+ (2D game framework)
- Pure Lua (no external dependencies for demo mode)
- Optional SubLua for blockchain features

---

## Support

- **Documentation**: https://github.com/MontaQLabs/sublua
- **Issues**: https://github.com/MontaQLabs/sublua/issues
- **Love2D Docs**: https://love2d.org/wiki/Main_Page

---

**Have fun!** 🎮🏴‍☠️💎
