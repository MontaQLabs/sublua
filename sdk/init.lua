-- sdk/init.lua
-- High-level entrypoint for the Polkadot Lua SDK

local M = {}

M.ffi       = require("sdk.ffi").lib   -- direct access if needed
M.signer    = require("sdk.core.signer")
M.extrinsic = require("sdk.core.extrinsic")
M.rpc       = require("sdk.core.rpc")
M.chain_config = require("sdk.core.chain_config")

return M 