package = "sublua"
version = "0.1.5-1"
source = {
   url = "git+https://github.com/MontaQLabs/sublua.git",
   tag = "v0.1.5"
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
      ["sublua"] = "sublua/init.lua",
      ["sublua.rpc"] = "sublua/rpc.lua",
      ["sublua.signer"] = "sublua/signer.lua",
      ["sublua.chain_config"] = "sublua/chain_config.lua",
      ["sublua.extrinsic_builder"] = "sublua/extrinsic_builder.lua",
      ["sublua.extrinsic"] = "sublua/extrinsic.lua",
      ["sublua.metadata"] = "sublua/metadata.lua",
      ["sublua.util"] = "sublua/util.lua",
      ["sublua.polkadot_ffi"] = "sublua/polkadot_ffi.lua"
   },
   copy_directories = {
      "examples",
      "test",
      "docs",
      "polkadot-ffi-subxt",
      "precompiled"
   }
}
