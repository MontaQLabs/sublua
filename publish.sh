#!/bin/bash

# publish.sh
# Script to publish SubLua to LuaRocks repository

set -e

echo "🚀 Publishing SubLua to LuaRocks..."

# Check if API key is provided
if [ -z "$LUAROCKS_API_KEY" ]; then
    echo "❌ Error: LUAROCKS_API_KEY environment variable not set"
    echo ""
    echo "To get your API key:"
    echo "1. Visit https://luarocks.org/"
    echo "2. Sign up/login and go to account settings"
    echo "3. Generate an API key"
    echo "4. Set it as environment variable:"
    echo "   export LUAROCKS_API_KEY=your_api_key_here"
    echo ""
    echo "Then run: ./publish.sh"
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    if ! command -v luarocks &> /dev/null; then
        echo "❌ LuaRocks not found. Please install LuaRocks."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        echo "❌ Git not found. Please install Git."
        exit 1
    fi
    
    echo "✅ Prerequisites check passed!"
}

# Clean and prepare
prepare_package() {
    echo "🧹 Preparing package..."
    
    # Clean any previous builds
    make clean
    
    # Ensure we're on the right branch and up to date
    git fetch origin
    git checkout main
    git pull origin main
    
    # Create a release tag if it doesn't exist
    if ! git tag -l | grep -q "v0.1.0"; then
        echo "📝 Creating release tag v0.1.0..."
        git tag -a v0.1.0 -m "Release version 0.1.0"
        git push origin v0.1.0
    fi
    
    echo "✅ Package prepared!"
}

# Validate rockspec
validate_rockspec() {
    echo "🔍 Validating rockspec..."
    
    if [ ! -f "sublua-0.1.0-1.rockspec" ]; then
        echo "❌ rockspec file not found: sublua-0.1.0-1.rockspec"
        exit 1
    fi
    
    # Validate the rockspec syntax
    luarocks lint sublua-0.1.0-1.rockspec
    
    echo "✅ Rockspec validation passed!"
}

# Pack the rock
pack_rock() {
    echo "📦 Packing rock..."
    
    # Create source rock
    luarocks pack sublua-0.1.0-1.rockspec
    
    if [ ! -f "sublua-0.1.0-1.src.rock" ]; then
        echo "❌ Failed to create source rock"
        exit 1
    fi
    
    echo "✅ Rock packed successfully!"
}

# Upload to LuaRocks
upload_rock() {
    echo "⬆️  Uploading to LuaRocks..."
    
    luarocks upload sublua-0.1.0-1.rockspec --api-key="$LUAROCKS_API_KEY"
    
    echo "✅ Upload successful!"
}

# Verify installation
verify_upload() {
    echo "🧪 Verifying upload..."
    
    # Wait a moment for the repository to update
    sleep 5
    
    # Try to install from the repository
    echo "Testing installation from LuaRocks repository..."
    luarocks install sublua --force
    
    # Test that it works
    lua -e "require('sdk.init'); print('✅ SubLua installed and working!')"
    
    echo "✅ Upload verification passed!"
}

# Main publishing process
main() {
    check_prerequisites
    prepare_package
    validate_rockspec
    pack_rock
    upload_rock
    verify_upload
    
    echo ""
    echo "🎉 SubLua successfully published to LuaRocks!"
    echo ""
    echo "Users can now install SubLua with:"
    echo "  luarocks install sublua"
    echo ""
    echo "Package URL: https://luarocks.org/modules/montaq/sublua"
}

# Run main function
main "$@"
