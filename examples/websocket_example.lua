-- examples/websocket_example.lua
-- Demonstrates WebSocket connection management with SubLua

package.path = package.path .. ";./?.lua;./?/init.lua"
local sublua = require("sublua")

print("🌐 SubLua WebSocket Connection Management Example")
print("=" .. string.rep("=", 70))

-- Load FFI
sublua.ffi()
print("✅ FFI loaded\n")

-- WebSocket module (can use full name or short alias)
local ws = sublua.ws()  -- Alias for sublua.websocket()

-- Configuration
local WESTEND_RPC = "wss://westend-rpc.polkadot.io"
local POLKADOT_RPC = "wss://rpc.polkadot.io"

-- =================================================================
-- 1. BASIC CONNECTION
-- =================================================================

print("1️⃣  Connecting to Westend Testnet...")
local info, err = ws.connect(WESTEND_RPC)

if not info then
    print("❌ Connection failed: " .. tostring(err))
    os.exit(1)
end

print("   ✅ Connected!")
print("   URL: " .. info.url)
print("   Reconnect count: " .. (info.reconnect_count or 0))

-- =================================================================
-- 2. CONNECTION STATISTICS
-- =================================================================

print("\n2️⃣  Getting connection statistics...")
local stats, err = ws.get_stats(WESTEND_RPC)

if stats then
    print("   Uptime: " .. stats.uptime_seconds .. " seconds")
    print("   Reconnections: " .. stats.reconnect_count)
    print("   Total messages: " .. stats.total_messages)
    print("   Last ping: " .. stats.last_ping_seconds_ago .. " seconds ago")
end

-- =================================================================
-- 3. CONNECTION POOLING
-- =================================================================

print("\n3️⃣  Connection Pooling (Multiple Chains)...")

-- Connect to multiple chains
print("   Connecting to Polkadot mainnet...")
ws.connect(POLKADOT_RPC)

-- List all active connections
local connections, err = ws.list_connections()
if connections then
    print("   Active connections: " .. connections.count)
    for i, url in ipairs(connections.connections) do
        print("      " .. i .. ". " .. url)
    end
end

-- =================================================================
-- 4. QUERYING WITH WEBSOCKETS
-- =================================================================

print("\n4️⃣  Querying balance via WebSocket...")

-- Create a test account
local signer_mod = sublua.signer()
local test_account = signer_mod.from_mnemonic(
    "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
)
local address = test_account:get_ss58_address(42)  -- Westend

print("   Address: " .. address)
print("   Querying balance...")

local balance_data, err = ws.query_balance(WESTEND_RPC, address)

if balance_data then
    print("   ✅ Balance retrieved")
    print("   Data: " .. balance_data:sub(1, 100) .. "...")
    
    -- The connection automatically tracks message count
    local updated_stats = ws.get_stats(WESTEND_RPC)
    if updated_stats then
        print("   Total messages sent: " .. updated_stats.total_messages)
    end
else
    print("   ❌ Query failed: " .. tostring(err))
end

-- =================================================================
-- 5. AUTOMATIC RECONNECTION
-- =================================================================

print("\n5️⃣  Automatic Reconnection...")
print("   WebSocket connections automatically reconnect on failure:")
print("   • Exponential backoff: 100ms → 200ms → 400ms → ... → 30s")
print("   • Max 10 reconnection attempts")
print("   • Completely transparent to your code")

-- Manual reconnection (usually not needed)
print("\n   Triggering manual reconnection...")
local msg, err = ws.reconnect(WESTEND_RPC)
if msg then
    print("   " .. msg)
end

-- =================================================================
-- 6. CONNECTION MONITORING
-- =================================================================

print("\n6️⃣  Connection Monitoring...")
print("   Heartbeat monitoring runs every 30 seconds")
print("   Automatically checks connection health")

-- Get updated stats
stats = ws.get_stats(WESTEND_RPC)
if stats then
    print("   Current reconnect count: " .. stats.reconnect_count)
end

-- =================================================================
-- 7. MULTIPLE QUERIES
-- =================================================================

print("\n7️⃣  Multiple Queries (Connection Reuse)...")
print("   Subsequent queries reuse the existing connection:")

for i = 1, 3 do
    print("   Query " .. i .. "...")
    ws.query_balance(WESTEND_RPC, address)
end

stats = ws.get_stats(WESTEND_RPC)
if stats then
    print("   Total messages after 3 queries: " .. stats.total_messages)
end

-- =================================================================
-- 8. CLEANUP
-- =================================================================

print("\n8️⃣  Cleanup...")

-- Disconnect specific connection
print("   Disconnecting from Polkadot...")
ws.disconnect(POLKADOT_RPC)

-- Check remaining connections
local remaining = ws.connection_count()
print("   Remaining connections: " .. remaining)

-- Disconnect all
print("   Disconnecting all connections...")
local disconnected = ws.disconnect_all()
print("   Disconnected " .. disconnected .. " connections")

-- Verify cleanup
remaining = ws.connection_count()
print("   Final connection count: " .. remaining)

-- =================================================================
-- BENEFITS
-- =================================================================

print("\n" .. string.rep("=", 70))
print("💡 WebSocket Benefits:")
print("\n   1. Connection Pooling:")
print("      • Connections are automatically pooled and reused")
print("      • One connection per RPC endpoint")
print("      • No need to manually manage connections")

print("\n   2. Automatic Reconnection:")
print("      • Transparent reconnection on network failures")
print("      • Exponential backoff prevents server overload")
print("      • Your code doesn't need to handle reconnection logic")

print("\n   3. Connection Monitoring:")
print("      • 30-second heartbeat checks")
print("      • Automatic health monitoring")
print("      • Statistics tracking for debugging")

print("\n   4. Performance:")
print("      • Persistent connections reduce latency")
print("      • Multiple queries reuse same connection")
print("      • Efficient for real-time applications")

print("\n" .. string.rep("=", 70))
print("🔧 Use Cases:")
print("   • Real-time blockchain monitoring")
print("   • High-frequency balance queries")
print("   • Gaming applications with live data")
print("   • DeFi applications with price feeds")
print("   • Multi-chain applications")

print("\n✅ Example completed!")
print("\n📚 Next Steps:")
print("   • Use ws.query_balance() for balance queries")
print("   • Monitor connection stats for debugging")
print("   • Let automatic reconnection handle failures")
print("   • Use connection pooling for multiple chains")

