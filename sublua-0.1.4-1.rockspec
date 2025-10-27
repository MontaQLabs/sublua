package = "sublua"
version = "0.1.4-1"
source = {
   url = "git+https://github.com/MontaQLabs/sublua.git",
   tag = "v0.1.4"
}
description = {
   summary = "A high-performance Lua SDK for Substrate blockchains",
   detailed = [[
SubLua is a comprehensive Lua SDK that enables developers to interact with 
Substrate-based blockchains using the familiar and performant Lua programming language.

Features:
- Type-safe cryptography using subxt
- Real transaction submission to Substrate chains
- Comprehensive error handling and recovery
- Professional documentation and examples
- Easy installation across platforms
- Extensive testing and validation

Perfect for:
- Blockchain gaming applications
- DeFi applications
- IoT and edge computing
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
      ["sublua"] = "sdk/init.lua",
      ["sublua.rpc"] = "sdk/rpc.lua",
      ["sublua.signer"] = "sdk/signer.lua",
      ["sublua.chain_config"] = "sdk/chain_config.lua",
      ["sublua.extrinsic_builder"] = "sdk/extrinsic_builder.lua",
      ["sublua.extrinsic"] = "sdk/extrinsic.lua",
      ["sublua.metadata"] = "sdk/metadata.lua",
      ["sublua.util"] = "sdk/util.lua",
      ["sublua.polkadot_ffi"] = "sdk/polkadot_ffi.lua"
   },
   copy_directories = {
      "examples",
      "test",
      "docs",
      "polkadot-ffi-subxt",
      "precompiled"
   }
}
