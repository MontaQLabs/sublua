# Root Makefile for SubLua

.PHONY: all clean build test example

all: build

build:
	$(MAKE) -C c_src

clean:
	$(MAKE) -C c_src clean
	rm -f sublua/polkadot_crypto.so

test: build
	@echo "Running core tests..."
	lua test/test_core.lua

example: build
	lua examples/transfer_demo.lua
