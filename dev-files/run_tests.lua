-- Print current directory
print("Current directory:", io.popen("pwd"):read("*l"))

-- Add the current directory to the Lua path
package.path = package.path .. ";./?.lua;./sdk/?.lua;./sdk/?/init.lua"

-- Print the Lua path
print("Lua path:", package.path)

-- Print SDK files
print("\nChecking SDK files:")
local function check_file(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        print("Found:", path)
    else
        print("Missing:", path)
    end
end

check_file("sdk/init.lua")
check_file("sdk/core/extrinsic.lua")
check_file("sdk/core/signer.lua")
check_file("sdk/scale/encoder.lua")
check_file("sdk/scale/decoder.lua")

print("\nRunning tests...")
-- Run the tests
dofile("tests/sdk_test.lua") 