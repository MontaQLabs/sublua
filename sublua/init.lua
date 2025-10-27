-- sublua/init.lua
-- High-level entrypoint for the Polkadot Lua SDK

local polkadot_ffi = require("sublua.polkadot_ffi")

local M = {}

-- Clean FFI API
M.ffi = polkadot_ffi.load_ffi
M.download_ffi_library = polkadot_ffi.download_ffi_library
M.detect_platform = polkadot_ffi.detect_platform
M.get_recommended_path = polkadot_ffi.get_recommended_path
M.auto_load = polkadot_ffi.auto_load

-- Core SDK modules (lazy loading to avoid dependency issues)
M.signer = function() return require("sublua.signer") end
M.extrinsic = function() return require("sublua.extrinsic") end
M.extrinsic_builder = function() return require("sublua.extrinsic_builder") end
M.metadata = function() return require("sublua.metadata") end
M.rpc = function() return require("sublua.rpc") end
M.chain_config = function() return require("sublua.chain_config") end

-- Version info
M.version = "0.1.6"

return M