-- sdk/init.lua
-- High-level entrypoint for the Polkadot Lua SDK

local M = {}

M.ffi       = require("sdk.polkadot_ffi").lib   -- direct access if needed
M.signer    = require("sdk.core.signer")
M.extrinsic = require("sdk.core.extrinsic")
M.extrinsic_builder = require("sdk.core.extrinsic_builder")
M.metadata  = require("sdk.core.metadata")
M.rpc       = require("sdk.core.rpc")
M.chain_config = require("sdk.core.chain_config")

return M 