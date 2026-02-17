# Root Makefile for SubLua

.PHONY: all clean build test example

all: build

build:
	$(MAKE) -C c_src

clean:
	$(MAKE) -C c_src clean

test: build
	@echo "Running all tests..."
	@cd test && lua test_crypto.lua && lua test_scale.lua && lua test_keyring.lua && lua test_transaction.lua && lua test_rpc.lua && lua test_integration.lua

test-crypto: build
	cd test && lua test_crypto.lua

test-scale: build
	cd test && lua test_scale.lua

test-keyring: build
	cd test && lua test_keyring.lua

test-transaction: build
	cd test && lua test_transaction.lua

test-rpc: build
	cd test && lua test_rpc.lua

test-integration: build
	cd test && lua test_integration.lua

test-core: build
	cd test && lua test_core.lua

example: build
	lua examples/transfer_demo.lua

install: build
	@echo "To install, copy c_src/polkadot_crypto.so to your LUA_CPATH"
	@echo "and lua/polkadot/ to your LUA_PATH"
