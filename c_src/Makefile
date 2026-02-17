CC=gcc
CFLAGS=-O2 -Wall -fPIC -I./vendor
LDFLAGS=-shared
EXT=so

# Attempt to find Lua headers
LUA_INC_PATHS = -I/opt/homebrew/opt/lua/include \
                -I/usr/local/include \
                -I/usr/include/lua5.1 \
                -I/usr/include/lua5.4 \
                -I/usr/include/luajit-2.1

# If pkg-config exists, use it to augment/override
PKG_CONFIG_LUA = $(shell pkg-config --cflags lua5.4 2>/dev/null || pkg-config --cflags lua5.1 2>/dev/null || pkg-config --cflags lua 2>/dev/null)

CFLAGS += $(LUA_INC_PATHS) $(PKG_CONFIG_LUA)

# OS-specific linking
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	LDFLAGS += -undefined dynamic_lookup
endif

TARGET=../sublua/polkadot_crypto.so
SRC=polkadot_crypto.c vendor/monocypher.c vendor/xxhash.c vendor/tweetnacl.c

all: $(TARGET)

$(TARGET): $(SRC)
	mkdir -p ../sublua
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGET)
