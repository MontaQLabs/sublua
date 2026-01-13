# Precompiled Binaries

This directory contains precompiled FFI libraries for different platforms to avoid requiring users to have Rust installed.

## Supported Platforms

- **linux-x86_64**: Linux 64-bit (Intel/AMD)
- **macos-x86_64**: macOS 64-bit (Intel)
- **macos-aarch64**: macOS 64-bit (Apple Silicon M1/M2/M3)
- **windows-x86_64**: Windows 64-bit

## How It Works

1. **Automatic Detection**: SubLua automatically detects your platform and architecture
2. **Precompiled First**: Tries to load the precompiled binary for your platform
3. **Fallback**: If no precompiled binary exists, falls back to source compilation
4. **User Choice**: Users can still compile from source if they prefer

## Building Binaries

To build precompiled binaries for your platform:

```bash
./build_binaries.sh
```

## Adding New Platforms

1. Create a new directory: `precompiled/<platform>-<arch>/`
2. Build the FFI library for that platform
3. Copy the library to the new directory
4. Update the FFI loader in `sdk/polkadot_ffi.lua`

## File Naming

- **Linux**: `libpolkadot_ffi.so`
- **macOS**: `libpolkadot_ffi.dylib`
- **Windows**: `polkadot_ffi.dll`

## Benefits

- ✅ **No Rust required** for most users
- ✅ **Faster installation** (no compilation time)
- ✅ **Better user experience** (works out of the box)
- ✅ **Fallback support** (still works if no precompiled binary)
- ✅ **Cross-platform** (supports multiple architectures)
