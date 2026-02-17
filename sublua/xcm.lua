-- sublua/xcm.lua
-- XCM (Cross-Consensus Messaging) call builders for Substrate
-- Supports teleport and reserve transfers between relay chain and parachains

local Scale = require("sublua.scale")
local Call = require("sublua.call")

local XCM = {}

-- Helper: Convert string to hex
local function to_hex(s)
    return (s:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function from_hex(hex)
    hex = hex:gsub("^0x", "")
    return (hex:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

-- ============================================================
-- XCM Version Tags (SCALE enum indices)
-- VersionedLocation: V3 = 1, V4 = 4  (but SCALE uses enum index)
-- In practice: VersionedMultiLocation enum:
--   V2 = 1, V3 = 3, V4 = 4
-- Westend currently uses V4.
-- ============================================================

local XCM_VERSION_V3 = 3
local XCM_VERSION_V4 = 4

-- ============================================================
-- Location Encoding (XCM V4)
-- Location { parents: u8, interior: Junctions }
-- Junctions enum: Here=0, X1=1, X2=2, ...
-- Junction enum variants:
--   Parachain(u32) = 0
--   AccountId32 { network: Option<NetworkId>, id: [u8;32] } = 1
--   AccountKey20 { network: Option<NetworkId>, key: [u8;20] } = 5
-- ============================================================

-- Encode a Junction::Parachain(para_id)
function XCM.junction_parachain(para_id)
    return string.char(0) .. Scale.encode_compact(para_id)
end

-- Encode a Junction::AccountId32 { network: None, id }
function XCM.junction_account_id32(account_id)
    assert(#account_id == 32, "AccountId must be 32 bytes")
    -- Junction::AccountId32 = variant index 1
    -- network: Option<NetworkId> = None = 0x00
    return string.char(1) .. "\0" .. account_id
end

-- Encode Junctions::Here (no interior)
function XCM.junctions_here()
    return string.char(0) -- Junctions::Here = 0
end

-- Encode Junctions::X1(junction)
-- In XCM V4, X1 is encoded as a fixed-size array [Junction; 1]
-- SCALE: variant index 1, then the junction
function XCM.junctions_x1(junction)
    -- X1 variant = 1, then a Vec-like wrapper in V4
    -- Actually in V4, X1([Junction;1]) is encoded as:
    -- enum index 1, then compact length 1, then junction bytes
    -- But in practice, the SCALE encoding for X1 in V4 is:
    -- 0x01 (X1 variant) + junction bytes directly (no length prefix)
    -- This matches the Rust: Junctions::X1(Arc<[Junction; 1]>)
    -- SCALE for Arc<[T;1]> is just T
    return string.char(1) .. junction
end

-- Encode Junctions::X2(j1, j2)
function XCM.junctions_x2(j1, j2)
    return string.char(2) .. j1 .. j2
end

-- Encode a Location { parents, interior }
function XCM.encode_location(parents, interior)
    return Scale.encode_u8(parents) .. interior
end

-- Encode VersionedLocation (V4)
function XCM.encode_versioned_location(parents, interior, version)
    version = version or XCM_VERSION_V4
    -- VersionedLocation enum: V2=1, V3=3, V4=4
    -- SCALE enum index for V4 = 4
    return Scale.encode_u8(version) .. XCM.encode_location(parents, interior)
end

-- ============================================================
-- Asset Encoding (XCM V4)
-- Asset { id: AssetId, fun: Fungibility }
-- AssetId = Location (in V4, AssetId is just a Location)
-- Fungibility enum: Fungible(u128) = 0, NonFungible(AssetInstance) = 1
-- ============================================================

-- Encode Fungibility::Fungible(amount)
-- amount is a Compact<u128>
function XCM.fungibility_fungible(amount)
    return string.char(0) .. Scale.encode_compact(amount)
end

-- Encode a single Asset { id: Location, fun: Fungibility }
function XCM.encode_asset(asset_location, fungibility)
    return asset_location .. fungibility
end

-- Encode VersionedAssets (V4) — a vector of Assets
function XCM.encode_versioned_assets(assets, version)
    version = version or XCM_VERSION_V4
    -- VersionedAssets enum: V2=1, V3=3, V4=4
    local encoded_assets = Scale.encode_compact(#assets)
    for _, asset in ipairs(assets) do
        encoded_assets = encoded_assets .. asset
    end
    return Scale.encode_u8(version) .. encoded_assets
end

-- ============================================================
-- WeightLimit Encoding
-- WeightLimit enum: Unlimited = 0, Limited(Weight) = 1
-- Weight { ref_time: Compact<u64>, proof_size: Compact<u64> }
-- ============================================================

function XCM.weight_unlimited()
    return string.char(0)
end

function XCM.weight_limited(ref_time, proof_size)
    return string.char(1) .. Scale.encode_compact(ref_time) .. Scale.encode_compact(proof_size)
end

-- ============================================================
-- High-Level Call Builders
-- ============================================================

-- Build limited_teleport_assets call bytes
-- Teleports native token from relay chain to a parachain (e.g., AssetHub)
--
-- pallet_index: XcmPallet index (99 on Westend)
-- call_index: limited_teleport_assets index (9 on Westend)
-- dest_para_id: destination parachain ID (1000 for AssetHub)
-- beneficiary_pubkey: 32-byte recipient public key
-- amount: amount in smallest unit (e.g., 1_000_000_000_000 for 1 WND)
-- version: XCM version (default V4)
function XCM.encode_limited_teleport_assets(pallet_index, call_index, dest_para_id, beneficiary_pubkey, amount, version)
    version = version or XCM_VERSION_V4

    -- Call index
    local call_idx = Call.encode_index(pallet_index, call_index)

    -- dest: VersionedLocation { parents: 0, interior: X1(Parachain(para_id)) }
    local dest = XCM.encode_versioned_location(
        0,
        XCM.junctions_x1(XCM.junction_parachain(dest_para_id)),
        version
    )

    -- beneficiary: VersionedLocation { parents: 0, interior: X1(AccountId32 { network: None, id }) }
    local beneficiary = XCM.encode_versioned_location(
        0,
        XCM.junctions_x1(XCM.junction_account_id32(beneficiary_pubkey)),
        version
    )

    -- assets: VersionedAssets with one native fungible asset
    -- Native token on relay = Location { parents: 0, interior: Here }
    -- In V4, AssetId is a Location
    local native_asset_id = XCM.encode_location(0, XCM.junctions_here())
    local fungibility = XCM.fungibility_fungible(amount)
    local asset = XCM.encode_asset(native_asset_id, fungibility)
    local assets = XCM.encode_versioned_assets({asset}, version)

    -- fee_asset_item: u32 = 0 (first asset pays fees)
    local fee_asset_item = Scale.encode_u32(0)

    -- weight_limit: Unlimited
    local weight_limit = XCM.weight_unlimited()

    return call_idx .. dest .. beneficiary .. assets .. fee_asset_item .. weight_limit
end

-- Build limited_reserve_transfer_assets call bytes
-- Reserve-transfers assets from relay chain to a parachain
--
-- Same parameters as limited_teleport_assets
function XCM.encode_limited_reserve_transfer_assets(pallet_index, call_index, dest_para_id, beneficiary_pubkey, amount, version)
    version = version or XCM_VERSION_V4

    local call_idx = Call.encode_index(pallet_index, call_index)

    local dest = XCM.encode_versioned_location(
        0,
        XCM.junctions_x1(XCM.junction_parachain(dest_para_id)),
        version
    )

    local beneficiary = XCM.encode_versioned_location(
        0,
        XCM.junctions_x1(XCM.junction_account_id32(beneficiary_pubkey)),
        version
    )

    local native_asset_id = XCM.encode_location(0, XCM.junctions_here())
    local fungibility = XCM.fungibility_fungible(amount)
    local asset = XCM.encode_asset(native_asset_id, fungibility)
    local assets = XCM.encode_versioned_assets({asset}, version)

    local fee_asset_item = Scale.encode_u32(0)
    local weight_limit = XCM.weight_unlimited()

    return call_idx .. dest .. beneficiary .. assets .. fee_asset_item .. weight_limit
end

-- Build transfer_assets call bytes (newer unified API)
-- transfer_assets is a more general call that handles both teleport and reserve
--
-- pallet_index: XcmPallet index
-- call_index: transfer_assets index (11 on Westend)
-- dest_para_id: destination parachain ID
-- beneficiary_pubkey: 32-byte recipient public key
-- amount: amount in smallest unit
-- version: XCM version (default V4)
function XCM.encode_transfer_assets(pallet_index, call_index, dest_para_id, beneficiary_pubkey, amount, version)
    version = version or XCM_VERSION_V4

    local call_idx = Call.encode_index(pallet_index, call_index)

    local dest = XCM.encode_versioned_location(
        0,
        XCM.junctions_x1(XCM.junction_parachain(dest_para_id)),
        version
    )

    local beneficiary = XCM.encode_versioned_location(
        0,
        XCM.junctions_x1(XCM.junction_account_id32(beneficiary_pubkey)),
        version
    )

    local native_asset_id = XCM.encode_location(0, XCM.junctions_here())
    local fungibility = XCM.fungibility_fungible(amount)
    local asset = XCM.encode_asset(native_asset_id, fungibility)
    local assets = XCM.encode_versioned_assets({asset}, version)

    local fee_asset_item = Scale.encode_u32(0)
    local weight_limit = XCM.weight_unlimited()

    return call_idx .. dest .. beneficiary .. assets .. fee_asset_item .. weight_limit
end

-- ============================================================
-- Convenience: Build and sign a teleport using live chain state
-- ============================================================

-- Teleport native tokens from relay chain to AssetHub
-- api: RPC client
-- signer: keyring pair
-- dest_pubkey: 32-byte recipient public key (can be same as signer)
-- amount: amount in smallest unit
-- opts: { para_id = 1000, tip = 0 }
function XCM.teleport_to_parachain(api, signer, dest_pubkey, amount, opts)
    opts = opts or {}
    local para_id = opts.para_id or 1000 -- AssetHub default

    local meta = api:get_metadata()
    local xcm_pallet = meta.pallets["XcmPallet"]
    assert(xcm_pallet, "XcmPallet not found in metadata")

    local call_index = xcm_pallet.calls["limited_teleport_assets"]
    assert(call_index, "limited_teleport_assets not found in XcmPallet")

    local call_bytes = XCM.encode_limited_teleport_assets(
        xcm_pallet.index, call_index,
        para_id, dest_pubkey, amount
    )

    local Transaction = require("sublua.transaction")
    return Transaction.create_signed_from_api(api, signer, call_bytes, opts)
end

-- Reserve-transfer native tokens from relay chain to a parachain
function XCM.reserve_transfer_to_parachain(api, signer, dest_pubkey, amount, opts)
    opts = opts or {}
    local para_id = opts.para_id or 1000

    local meta = api:get_metadata()
    local xcm_pallet = meta.pallets["XcmPallet"]
    assert(xcm_pallet, "XcmPallet not found in metadata")

    local call_index = xcm_pallet.calls["limited_reserve_transfer_assets"]
    assert(call_index, "limited_reserve_transfer_assets not found in XcmPallet")

    local call_bytes = XCM.encode_limited_reserve_transfer_assets(
        xcm_pallet.index, call_index,
        para_id, dest_pubkey, amount
    )

    local Transaction = require("sublua.transaction")
    return Transaction.create_signed_from_api(api, signer, call_bytes, opts)
end

return XCM
