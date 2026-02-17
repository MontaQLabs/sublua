-- test/test_xcm.lua
-- Unit tests for XCM module

package.cpath = "./sublua/?.so;" .. package.cpath
package.path = "./?.lua;./?/init.lua;" .. package.path

local XCM = require("sublua.xcm")
local Scale = require("sublua.scale")
local Keyring = require("sublua.keyring")

local passed = 0
local failed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("✅ " .. name)
    else
        failed = failed + 1
        print("❌ " .. name .. ": " .. tostring(err))
    end
end

local function to_hex(s)
    return (s:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

print("=== XCM Module Tests ===\n")

-- Junction tests
test("XCM: Junction Parachain(1000)", function()
    local j = XCM.junction_parachain(1000)
    -- Parachain variant = 0x00, then Compact(1000)
    -- Compact(1000) = 1000*4+1 = 4001 = 0xA10F as u16 LE = 0xa1, 0x0f
    -- Wait: Compact(1000) -> 1000 < 16384 -> two-byte mode: (1000 << 2) | 1 = 4001
    -- 4001 = 0x0FA1 -> LE bytes: 0xA1, 0x0F
    assert(to_hex(j) == "00a10f", "got: " .. to_hex(j))
end)

test("XCM: Junction AccountId32", function()
    local alice = Keyring.from_uri("//Alice")
    local j = XCM.junction_account_id32(alice.pubkey)
    -- AccountId32 variant = 0x01, network = None = 0x00, then 32 bytes
    assert(#j == 34, "expected 34 bytes, got " .. #j)
    assert(string.byte(j, 1) == 1, "variant should be 1")
    assert(string.byte(j, 2) == 0, "network should be None")
    assert(j:sub(3) == alice.pubkey, "pubkey mismatch")
end)

-- Junctions tests
test("XCM: Junctions Here", function()
    local j = XCM.junctions_here()
    assert(to_hex(j) == "00", "got: " .. to_hex(j))
end)

test("XCM: Junctions X1(Parachain(1000))", function()
    local j = XCM.junctions_x1(XCM.junction_parachain(1000))
    -- X1 = 0x01, then Parachain junction
    assert(string.byte(j, 1) == 1, "X1 variant")
    assert(to_hex(j) == "0100a10f", "got: " .. to_hex(j))
end)

test("XCM: Junctions X2", function()
    local j = XCM.junctions_x2(
        XCM.junction_parachain(1000),
        XCM.junction_account_id32(string.rep("\0", 32))
    )
    assert(string.byte(j, 1) == 2, "X2 variant")
end)

-- Location tests
test("XCM: Location { parents: 1, interior: Here }", function()
    local loc = XCM.encode_location(1, XCM.junctions_here())
    assert(to_hex(loc) == "0100", "got: " .. to_hex(loc))
end)

test("XCM: Location { parents: 0, interior: X1(Parachain(1000)) }", function()
    local loc = XCM.encode_location(0, XCM.junctions_x1(XCM.junction_parachain(1000)))
    assert(to_hex(loc) == "000100a10f", "got: " .. to_hex(loc))
end)

-- VersionedLocation tests
test("XCM: VersionedLocation V4", function()
    local vloc = XCM.encode_versioned_location(0, XCM.junctions_x1(XCM.junction_parachain(1000)))
    -- V4 enum index = 4, then Location
    assert(string.byte(vloc, 1) == 4, "V4 tag")
    assert(to_hex(vloc) == "04000100a10f", "got: " .. to_hex(vloc))
end)

-- Asset tests
test("XCM: Fungibility Fungible(1 WND)", function()
    local f = XCM.fungibility_fungible(1000000000000)
    -- Fungible variant = 0x00, then Compact(1000000000000)
    assert(string.byte(f, 1) == 0, "Fungible variant")
    assert(#f > 1, "should have compact amount")
end)

test("XCM: VersionedAssets V4 with one native asset", function()
    local asset_id = XCM.encode_location(0, XCM.junctions_here())
    local fun = XCM.fungibility_fungible(1000000000000)
    local asset = XCM.encode_asset(asset_id, fun)
    local vassets = XCM.encode_versioned_assets({asset})
    -- V4 tag = 4, then Compact(1) for vector length, then asset
    assert(string.byte(vassets, 1) == 4, "V4 tag")
    assert(string.byte(vassets, 2) == 4, "Compact(1) = 0x04")
end)

-- WeightLimit tests
test("XCM: WeightLimit Unlimited", function()
    local w = XCM.weight_unlimited()
    assert(to_hex(w) == "00", "got: " .. to_hex(w))
end)

test("XCM: WeightLimit Limited", function()
    local w = XCM.weight_limited(1000000, 65536)
    assert(string.byte(w, 1) == 1, "Limited variant")
    assert(#w > 1, "should have weight data")
end)

-- Full call encoding tests
test("XCM: limited_teleport_assets call encoding", function()
    local alice = Keyring.from_uri("//Alice")
    local call = XCM.encode_limited_teleport_assets(99, 9, 1000, alice.pubkey, 1000000000000)
    -- Should start with call index [99, 9] = 0x6309
    assert(string.byte(call, 1) == 99, "pallet index")
    assert(string.byte(call, 2) == 9, "call index")
    -- Should end with weight_limit Unlimited = 0x00
    assert(string.byte(call, #call) == 0, "weight unlimited at end")
    -- Should contain fee_asset_item u32(0) = 00000000 before weight_limit
    local tail = to_hex(call:sub(-5))
    assert(tail == "0000000000", "fee_asset_item(0) + weight_unlimited")
end)

test("XCM: limited_reserve_transfer_assets call encoding", function()
    local alice = Keyring.from_uri("//Alice")
    local call = XCM.encode_limited_reserve_transfer_assets(99, 8, 1000, alice.pubkey, 500000000000)
    assert(string.byte(call, 1) == 99, "pallet index")
    assert(string.byte(call, 2) == 8, "call index")
end)

test("XCM: transfer_assets call encoding", function()
    local alice = Keyring.from_uri("//Alice")
    local call = XCM.encode_transfer_assets(99, 11, 2000, alice.pubkey, 1000000000000)
    assert(string.byte(call, 1) == 99, "pallet index")
    assert(string.byte(call, 2) == 11, "call index")
end)

test("XCM: Different amounts produce different encodings", function()
    local alice = Keyring.from_uri("//Alice")
    local call1 = XCM.encode_limited_teleport_assets(99, 9, 1000, alice.pubkey, 1000000000000)
    local call2 = XCM.encode_limited_teleport_assets(99, 9, 1000, alice.pubkey, 2000000000000)
    assert(call1 ~= call2, "different amounts should produce different calls")
end)

test("XCM: Different parachains produce different encodings", function()
    local alice = Keyring.from_uri("//Alice")
    local call1 = XCM.encode_limited_teleport_assets(99, 9, 1000, alice.pubkey, 1000000000000)
    local call2 = XCM.encode_limited_teleport_assets(99, 9, 2000, alice.pubkey, 1000000000000)
    assert(call1 ~= call2, "different parachains should produce different calls")
end)

test("XCM: Different beneficiaries produce different encodings", function()
    local alice = Keyring.from_uri("//Alice")
    local bob = Keyring.from_uri("//Bob")
    local call1 = XCM.encode_limited_teleport_assets(99, 9, 1000, alice.pubkey, 1000000000000)
    local call2 = XCM.encode_limited_teleport_assets(99, 9, 1000, bob.pubkey, 1000000000000)
    assert(call1 ~= call2, "different beneficiaries should produce different calls")
end)

print("\n=== XCM Module Test Results ===")
print("Passed: " .. passed)
print("Failed: " .. failed)

if failed > 0 then
    os.exit(1)
else
    print("🎉 All XCM tests passed!")
    os.exit(0)
end
