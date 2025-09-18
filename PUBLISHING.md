# Publishing SubLua to LuaRocks

This guide explains how to publish SubLua to the LuaRocks repository, making it available for `luarocks install sublua`.

## 🎯 Overview

LuaRocks is the standard package repository for Lua, similar to:
- **PyPI** for Python packages
- **npm** for Node.js packages  
- **Crates.io** for Rust packages

Once published, users can install SubLua with a simple command:
```bash
luarocks install sublua
```

## 📋 Prerequisites

### 1. LuaRocks Account
- Visit [luarocks.org](https://luarocks.org/)
- Sign up for a free account
- Verify your email address

### 2. API Key
- Log into your LuaRocks account
- Go to **Account Settings**
- Generate an **API Key**
- Keep this key secure - you'll need it for publishing

### 3. Local Setup
- LuaRocks installed locally
- Git configured with your credentials
- Access to the SubLua repository

## 🚀 Publishing Process

### Method 1: Automated Script (Recommended)

```bash
# Set your API key
export LUAROCKS_API_KEY=your_api_key_here

# Run the publishing script
./publish.sh
```

The script will:
1. ✅ Check prerequisites
2. 🧹 Clean and prepare the package
3. 🔍 Validate the rockspec
4. 📦 Pack the source rock
5. ⬆️ Upload to LuaRocks
6. 🧪 Verify the upload

### Method 2: Manual Publishing

#### Step 1: Prepare the Package
```bash
# Clean previous builds
make clean

# Ensure you're on the main branch
git checkout main
git pull origin main

# Create a release tag (if not exists)
git tag -a v0.1.0 -m "Release version 0.1.0"
git push origin v0.1.0
```

#### Step 2: Validate Rockspec
```bash
# Check rockspec syntax
luarocks lint sublua-0.1.0-1.rockspec
```

#### Step 3: Pack the Rock
```bash
# Create source rock
luarocks pack sublua-0.1.0-1.rockspec
```

This creates `sublua-0.1.0-1.src.rock`

#### Step 4: Upload to LuaRocks
```bash
# Upload with your API key
luarocks upload sublua-0.1.0-1.rockspec --api-key=YOUR_API_KEY
```

#### Step 5: Verify Upload
```bash
# Test installation from repository
luarocks install sublua --force

# Verify it works
lua -e "require('sdk.init'); print('SubLua working!')"
```

## 📦 Package Structure

Your published package will include:

```
sublua-0.1.0-1/
├── sdk/                    # Lua modules
│   ├── init.lua
│   ├── rpc.lua
│   ├── signer.lua
│   └── ...
├── examples/               # Usage examples
├── test/                   # Test suite
├── docs/                   # Documentation
└── sublua-0.1.0-1.rockspec # Package metadata
```

## 🔧 FFI Library Handling

### The Challenge
FFI libraries need to be compiled on the user's system, not pre-compiled in the package.

### The Solution
1. **Source Distribution**: Package includes Rust source code
2. **Build Instructions**: Rockspec includes build commands
3. **User Compilation**: FFI library compiles during installation

### Build Process
```bash
# During installation, LuaRocks will:
cd polkadot-ffi-subxt
cargo build --release
# Creates libpolkadot_ffi.so
```

## 📊 Version Management

### Versioning Scheme
- **Format**: `MAJOR.MINOR.PATCH-REVISION`
- **Example**: `0.1.0-1`
- **Revision**: Increment for rockspec changes without code changes

### Updating Versions
```bash
# 1. Update version in rockspec
# 2. Create new git tag
git tag -a v0.1.1 -m "Release version 0.1.1"
git push origin v0.1.1

# 3. Update rockspec filename and content
mv sublua-0.1.0-1.rockspec sublua-0.1.1-1.rockspec

# 4. Publish new version
./publish.sh
```

## 🎯 After Publishing

### Package URL
Your package will be available at:
```
https://luarocks.org/modules/montaq/sublua
```

### Installation Commands
Users can install with:
```bash
# Install latest version
luarocks install sublua

# Install specific version
luarocks install sublua 0.1.0-1

# Install with dependencies
luarocks install sublua --deps-mode=all
```

### Usage
```lua
-- Users can now simply:
local sdk = require("sdk.init")
local rpc = sdk.rpc.new("wss://westend-rpc.polkadot.io")
```

## 🔍 Troubleshooting

### Common Issues

#### 1. API Key Authentication Failed
```
Error: Authentication failed
```
**Solution**: Verify your API key is correct and active

#### 2. Package Already Exists
```
Error: Package 'sublua' already exists
```
**Solution**: Increment version number in rockspec

#### 3. Git Tag Not Found
```
Error: Tag 'v0.1.0' not found
```
**Solution**: Create and push the git tag first

#### 4. Build Dependencies Missing
```
Error: Cargo not found
```
**Solution**: Ensure Rust is installed on target systems

### Verification Commands
```bash
# Check package exists
luarocks search sublua

# View package info
luarocks show sublua

# Test installation
luarocks install sublua --force
```

## 📈 Analytics & Monitoring

### Package Statistics
- Visit your package page on LuaRocks
- View download statistics
- Monitor user feedback

### Updates & Maintenance
- Respond to issues on GitHub
- Update documentation
- Release bug fixes and features

## 🎉 Success!

Once published, SubLua will be available to the entire Lua community:

```bash
# Anyone can now install SubLua with:
luarocks install sublua

# And use it immediately:
lua -e "require('sdk.init'); print('SubLua ready!')"
```

This makes SubLua as easy to install as any other Lua package, similar to how Python developers use `pip install` or Node.js developers use `npm install`.
