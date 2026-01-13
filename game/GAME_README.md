# 🎮 Treasure Hunter - SubLua Blockchain Game

A production-ready blockchain game with neon cyberpunk aesthetics, real token rewards, and live Westend integration.

## 🚀 Quick Start

### Option 1: Double-Click (macOS)

Simply double-click **TreasureHunter.app** - works right out of the box!

### Option 2: Love2D (All Platforms)

```bash
# 1. Install Love2D
brew install love  # macOS
# or download from: https://love2d.org

# 2. Run the game
love TreasureHunter.love
```

**Both options give you FULL blockchain integration with real WND rewards!**

## 🎯 Features

- ✨ **Neon Cyberpunk Graphics** - Glowing effects, animated backgrounds
- 💰 **Real Token Rewards** - Earn actual WND on Westend testnet  
- 👤 **Player Management** - Your wallet, your rewards
- 🏆 **Live Leaderboard** - Compete with other players
- 🔐 **Secure Transactions** - Multi-sig treasury, on-chain verification

## 🕹️ How to Play

1. **Movement**: Use **Arrow Keys** or **WASD**
2. **Collect**: Grab spinning gold stars (treasures) - **+0.005 WND each**
3. **Avoid**: Red X marks (obstacles)
4. **Win**: Collect all 6 treasures within 25 moves
5. **Earn**: Rewards sent to your Westend address!

## 💰 Token Economics

- **Entry**: Free (no entry fee)
- **Reward**: 0.005 WND per treasure collected
- **Max Reward**: 0.03 WND per game (6 treasures)
- **Network**: Westend Testnet
- **Treasury**: `5GH4vb4Kf25t2TBSUUHBQz99NU2etNeG5cgYZGRWn4mWcy5T`

## 🎮 Game Modes

### Live Blockchain Mode
- Real transactions on Westend
- Your mnemonic = your rewards
- Requires funded treasury (see below)

### Demo Mode  
- Falls back if treasury has no funds
- Simulated rewards (no real tokens)
- Still fun to play!

## ⚠️ IMPORTANT: Fund the Treasury

**The treasury currently has 0 WND balance. You need to fund it to enable real rewards:**

1. Go to **https://faucet.polkadot.io/westend**
2. Paste treasury address: `5GH4vb4Kf25t2TBSUUHBQz99NU2etNeG5cgYZGRWn4mWcy5T`
3. Request tokens (you'll get ~100 WND)
4. Wait 30 seconds, then the game will automatically detect funds and enable live mode!

Without funding, the game runs in **demo mode** (simulated rewards, still fun to play).

## 📦 Distribution

- **TreasureHunter.love** (2.4MB)  
  Universal file, works on macOS/Windows/Linux  
  Requires Love2D installed

- **Source code**: `game/` directory  
  Fully open-source, built with SubLua SDK

## 🛠️ Technical Stack

- **Love2D 11.5** - Game engine
- **SubLua SDK** - Blockchain integration
- **Rust FFI** - Cryptography (sr25519)
- **Westend Testnet** - Live blockchain
- **Real-time RPC** - Balance queries
- **Atomic Transfers** - Secure rewards

## 🎨 Controls

- **Arrow Keys / WASD**: Move player
- **Escape**: Quit game
- **Enter**: Select menu / Restart

## 🏗️ Building from Source

```bash
cd game/fused_game
zip -r ../../TreasureHunter.love .
cd ../..
love TreasureHunter.love
```

## 🌐 Network Details

- **Chain**: Westend (Polkadot Testnet)
- **RPC**: wss://westend-rpc.polkadot.io
- **Token**: WND (12 decimals)
- **SS58 Prefix**: 42

## 🤝 Community

- **GitHub**: https://github.com/MontaQLabs/sublua
- **Docs**: See README.md in project root
- **LuaRocks**: `luarocks install sublua`

---

**Built with SubLua** - The high-performance Lua SDK for Substrate blockchains 🚀
