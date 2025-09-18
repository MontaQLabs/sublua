package = "sublua"
version = "0.1.0-1"
source = {
   url = "git+https://github.com/MontaQLabs/sublua.git",
   tag = "v0.1.0"
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
build = {
   type = "builtin",
   modules = {
      ["sdk.init"] = "sdk/init.lua",
      ["sdk.rpc"] = "sdk/core/rpc.lua",
      ["sdk.signer"] = "sdk/core/signer.lua",
      ["sdk.chain_config"] = "sdk/core/chain_config.lua",
      ["sdk.extrinsic_builder"] = "sdk/core/extrinsic_builder.lua",
      ["sdk.extrinsic"] = "sdk/core/extrinsic.lua",
      ["sdk.metadata"] = "sdk/core/metadata.lua",
      ["sdk.util"] = "sdk/core/util.lua",
      ["sdk.polkadot_ffi"] = "sdk/polkadot_ffi.lua"
   },
   copy_directories = {
      "examples",
      "test",
      "docs",
      "polkadot-ffi-subxt"
   }
}
