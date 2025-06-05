local polkadot = require("polkadot")

-- Example seed (32 bytes in hex)
local seed = "0000000000000000000000000000000000000000000000000000000000000001"

-- Example extrinsic data (this would normally be your SCALE-encoded extrinsic)
local extrinsic = "0400" -- Example extrinsic data

-- Sign the extrinsic
local result = polkadot.sign_extrinsic(seed, extrinsic)

if result.success then
    print("Signature:", result.data)
else
    print("Error:", result.error)
end 