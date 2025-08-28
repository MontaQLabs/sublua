-- package.lua
-- SubLua package configuration

return {
    name = "sublua",
    version = "0.1.0",
    description = "A high-performance Lua SDK for Substrate blockchains",
    author = "SubLua Contributors",
    license = "MIT",
    homepage = "https://github.com/your-org/sublua",
    
    -- Dependencies
    dependencies = {
        "luasocket >= 3.0",
        "lua-cjson >= 2.1", 
        "luasec >= 1.0"
    },
    
    -- Main module
    main = "sdk.init",
    
    -- Available modules
    modules = {
        "sdk.init",
        "sdk.rpc",
        "sdk.signer",
        "sdk.chain_config",
        "sdk.extrinsic_builder",
        "sdk.extrinsic",
        "sdk.metadata",
        "sdk.util",
        "sdk.polkadot_ffi"
    },
    
    -- Installation instructions
    install = {
        "1. Install dependencies: luarocks install luasocket lua-cjson luasec",
        "2. Build FFI: cd polkadot-ffi-subxt && cargo build --release",
        "3. Install SubLua: luarocks install sublua-scm-0.rockspec"
    },
    
    -- Quick start
    quickstart = {
        "local sdk = require('sdk.init')",
        "local rpc = sdk.rpc.new('wss://westend-rpc.polkadot.io')",
        "local signer = sdk.signer.from_mnemonic('your mnemonic')",
        "local tx_hash = signer:transfer(rpc, 'destination', amount)"
    }
}
