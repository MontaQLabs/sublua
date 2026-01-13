# 🏴‍☠️ Treasure Hunter - SubLua Blockchain Game

A complete, polished game demonstrating production-ready blockchain integration with SubLua.

## Features

- **🎮 Player Account Management**: Wallet integration with address display and balance tracking
- **💰 Token Economics**: Entry fees, play-to-earn rewards, and treasure bonuses
- **🏆 On-Chain Leaderboard**: Persistent score tracking and rankings
- **🔐 Multi-Sig Treasury**: 2-of-3 multisig for prize pool management (in production mode)
- **🌐 Network Integration**: Connects to Westend testnet (or runs in demo mode)

## Quick Start

### Option 1: Run with Love2D

```bash
# Install Love2D
# macOS: brew install love
# Ubuntu: sudo apt install love
# Windows: Download from https://love2d.org

# Run the game
cd sublua
love game/
```

### Option 2: Download Standalone

Download pre-built executables from [GitHub Releases](https://github.com/MontaQLabs/sublua/releases):

- **Windows**: `TreasureHunter-win64.zip`
- **macOS**: `TreasureHunter-macos.zip`
- **Linux**: `TreasureHunter-linux.tar.gz`

## How to Play

1. **Start Game** - Press Enter on the menu
2. **Move** - Arrow keys or WASD
3. **Collect Treasures** - 💎 gives +100 points + bonus reward
4. **Avoid Obstacles** - 🪨 blocks your path
5. **Manage Moves** - You have 20 moves per game

## Token Economics

| Action | Amount |
|--------|--------|
| Entry Fee | 0.1 WND |
| Base Reward | 0.05 WND |
| Per Treasure | 0.5 WND |
| Score Bonus | +1% per 100 points |

## Controls

| Key | Action |
|-----|--------|
| ↑/W | Move Up |
| ↓/S | Move Down |
| ←/A | Move Left |
| →/D | Move Right |
| Enter | Select |
| ESC | Back/Quit |

## Building Standalone Executables

### Using love-release (Recommended)

```bash
# Install love-release
luarocks install love-release

# Build for all platforms
cd game
love-release -W -M -L .
```

### Manual Packaging

```bash
# Create .love file
cd game
zip -r ../TreasureHunter.love .

# The .love file can be run with: love TreasureHunter.love

# For standalone executable, see Love2D wiki:
# https://love2d.org/wiki/Game_Distribution
```

## Architecture

```
game/
├── conf.lua      # Love2D configuration
├── main.lua      # Game logic + blockchain integration
└── README.md     # This file
```

## Blockchain Integration

The game integrates with SubLua for:

1. **Wallet Creation**: Sr25519 keypairs from mnemonic
2. **Balance Queries**: Real-time balance from chain
3. **Transactions**: Entry fees and reward distribution
4. **Leaderboard**: Score storage (on-chain via System.remark in production)

When SubLua is not available, the game runs in **Demo Mode** with simulated blockchain operations.

## Screenshots

```
╔═══════════════════════════════════════╗
║     🏴‍☠️ TREASURE HUNTER 🏴‍☠️             ║
╠═══════════════════════════════════════╣
║                                       ║
║     🎮  Start Game                    ║
║     👛  Wallet                        ║
║     🏆  Leaderboard                   ║
║     ❓  How to Play                   ║
║     🚪  Exit                          ║
║                                       ║
╚═══════════════════════════════════════╝
```

## Credits

- Built with [Love2D](https://love2d.org)
- Blockchain SDK: [SubLua](https://github.com/MontaQLabs/sublua)
- Network: [Westend Testnet](https://polkadot.js.org/apps/?rpc=wss://westend-rpc.polkadot.io)

## License

MIT License - See [LICENSE](../LICENSE)
