package = "sublua"
version = "0.3.0-1"
source = {
   url = "git+https://github.com/MontaQLabs/sublua.git",
   tag = "v0.3.0"
}
description = {
   summary = "High-performance Lua SDK for Substrate with advanced crypto and WebSocket support",
   detailed = [[
SubLua is a comprehensive Lua SDK that enables developers to interact with 
Substrate-based blockchains using the familiar and performant Lua programming language.

Features:
- Type-safe cryptography using subxt and sp-core
- Advanced crypto: Multi-signature accounts, proxy accounts, on-chain identity
- WebSocket connection management with automatic reconnection and pooling
- Dynamic metadata parsing via SCALE codec
- Real transaction submission to Substrate chains
- Comprehensive error handling and security best practices
- Professional documentation and examples
- Easy installation across platforms
- Extensive testing and validation (100% pass rate on 21+ tests)

Perfect for:
- Blockchain gaming applications with real-time data
- DeFi applications with multi-sig treasuries
- IoT and edge computing with secure delegation
- DAO governance with proxy voting
- High-frequency blockchain monitoring
- Any Lua application needing blockchain integration
   ]],
   homepage = "https://github.com/MontaQLabs/sublua",
   license = "MIT",
   maintainer = "Abhiraj Mengade <abhiraj@montaq.org>"
}
dependencies = {
   "lua >= 5.1",
   "luasocket >= 3.0",
   "lua-cjson >= 2.1",
   "luasec >= 1.0"
}
supported_platforms = {
   "linux",
   "macosx", 
   "windows"
}
build = {
   type = "builtin",
   modules = {
      ["sublua"] = "sublua/init.lua",
      ["sublua.rpc"] = "sublua/rpc.lua",
      ["sublua.signer"] = "sublua/signer.lua",
      ["sublua.chain_config"] = "sublua/chain_config.lua",
      ["sublua.extrinsic_builder"] = "sublua/extrinsic_builder.lua",
      ["sublua.extrinsic"] = "sublua/extrinsic.lua",
      ["sublua.metadata"] = "sublua/metadata.lua",
      ["sublua.util"] = "sublua/util.lua",
      ["sublua.polkadot_ffi"] = "sublua/polkadot_ffi.lua",
      -- Advanced crypto features (v0.2.0)
      ["sublua.multisig"] = "sublua/multisig.lua",
      ["sublua.proxy"] = "sublua/proxy.lua",
      ["sublua.identity"] = "sublua/identity.lua",
      -- WebSocket management (v0.3.0)
      ["sublua.websocket"] = "sublua/websocket.lua"
   },
   copy_directories = {
      "examples",
      "test",
      "docs",
      "polkadot-ffi-subxt",
      "precompiled"
   }
}

