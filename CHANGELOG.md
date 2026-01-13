# Changelog

All notable changes to SubLua will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-01-14

### Fixed
- Fixed FFI auto-loading bug (nil in ipairs broke search paths)
- Fixed .app double-click (now uses absolute paths from bundle)
- Fixed examples to use correct lazy-loaded module API
- Updated test suites for local development

### Added
- Comprehensive game development guide (925 lines)
- Pre-commit git hooks for automated testing
- CONTRIBUTING.md with development guidelines
- .editorconfig for consistent code style
- Complete Treasure Hunter blockchain game
- Standalone macOS .app distribution
- One-liner installer script

### Changed
- Moved game documentation to game/ folder
- Cleaned up old duplicate docs
- Improved FFI path detection (searches 10+ locations)

### Removed
- Old install.sh and publish.sh scripts
- docs/TECHNICAL_BLOG.md (duplicate of ARTICLE.md)
- Game release workflow (distributed separately)

## [0.3.0] - 2026-01-06

### Added
- WebSocket connection management with auto-reconnection
- Connection pooling for efficient resource usage
- Heartbeat monitoring (30s intervals)
- Connection statistics tracking
- HTTP fallback when WebSocket unavailable
- 11 new WebSocket-related tests

### Changed
- Improved error handling in network operations
- Enhanced connection stability

## [0.2.0] - 2025-12-15

### Added
- Multi-signature account support
- Proxy account operations (add, remove, proxy_call)
- On-chain identity management (set, clear, query)
- 10 new tests for advanced crypto features
- Comprehensive security documentation

### Changed
- Refactored FFI layer for better type safety
- Improved error messages

## [0.1.6] - 2025-10-20

### Added
- Dynamic metadata parsing via SCALE codec
- Runtime compatibility checking
- Pallet and call discovery
- Auto-adapting to runtime upgrades

### Fixed
- Hardcoded call indices breaking on upgrades

## [0.1.5] - 2025-09-15

### Added
- Cross-platform precompiled binaries
- Automated build pipeline
- LuaRocks package distribution

### Changed
- Simplified installation process

## [0.1.4] - 2025-08-29

### Added
- Balance transfer functionality
- User-facing test suite
- Custom FFI path examples

### Fixed
- Module loading issues

## [0.1.3] - 2025-08-20

### Added
- Extrinsic builder API
- Chain configuration detection

## [0.1.2] - 2025-08-15

### Added
- Mnemonic-based wallet creation
- SS58 address encoding/decoding

## [0.1.1] - 2025-08-10

### Fixed
- FFI library loading on different platforms

## [0.1.0] - 2025-08-05

### Added
- Initial release
- Sr25519 keypair generation
- Balance queries via FFI
- Basic RPC client
- Core test suite

[0.3.1]: https://github.com/MontaQLabs/sublua/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/MontaQLabs/sublua/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/MontaQLabs/sublua/compare/v0.1.6...v0.2.0
[0.1.6]: https://github.com/MontaQLabs/sublua/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/MontaQLabs/sublua/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/MontaQLabs/sublua/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/MontaQLabs/sublua/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/MontaQLabs/sublua/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/MontaQLabs/sublua/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/MontaQLabs/sublua/releases/tag/v0.1.0
