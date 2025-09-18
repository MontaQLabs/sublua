# Makefile for SubLua
# Simple installation and management

.PHONY: install uninstall test clean build-ffi

# Default target
all: install

# Install SubLua
install: build-ffi
	@echo "🚀 Installing SubLua..."
	@luarocks install sublua-scm-0.rockspec
	@echo "✅ Installation complete!"

# Build FFI library
build-ffi:
	@echo "🔧 Building FFI library..."
	@cd polkadot-ffi-subxt && cargo build --release
	@echo "✅ FFI library built!"

# Uninstall SubLua
uninstall:
	@echo "🗑️  Uninstalling SubLua..."
	@luarocks remove sublua
	@echo "✅ Uninstallation complete!"

# Run tests
test: install
	@echo "🧪 Running tests..."
	@luajit test/run_tests.lua

# Test installation
test-install: install
	@echo "🧪 Testing installation..."
	@luajit test/test_installation.lua

# Run basic example
example: install
	@echo "💡 Running basic example..."
	@luajit examples/basic_usage.lua

# Run game integration example
game: install
	@echo "🎮 Running game integration example..."
	@luajit examples/game_integration.lua

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@cd polkadot-ffi-subxt && cargo clean
	@echo "✅ Clean complete!"

# Show help
help:
	@echo "SubLua Makefile Commands:"
	@echo "  install      - Install SubLua via LuaRocks"
	@echo "  build-ffi    - Build the FFI library"
	@echo "  uninstall    - Remove SubLua"
	@echo "  test         - Run test suite"
	@echo "  test-install - Test installation"
	@echo "  example      - Run basic usage example"
	@echo "  game         - Run game integration example"
	@echo "  clean        - Clean build artifacts"
	@echo "  help         - Show this help"
