# Contributing to SubLua

Thank you for your interest in contributing to SubLua!

## Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/MontaQLabs/sublua.git
   cd sublua
   ```

2. **Install dependencies:**
   ```bash
   # Install Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   
   # Install LuaJIT
   brew install luajit  # macOS
   # or: sudo apt install luajit  # Linux
   
   # Install LuaRocks
   brew install luarocks  # macOS
   # or: sudo apt install luarocks  # Linux
   ```

3. **Build FFI library:**
   ```bash
   cd polkadot-ffi-subxt
   cargo build --release
   cd ..
   ```

4. **Setup precompiled directory:**
   ```bash
   mkdir -p precompiled/macos-aarch64
   cp polkadot-ffi-subxt/target/release/libpolkadot_ffi.dylib precompiled/macos-aarch64/
   ```

5. **Configure git hooks:**
   ```bash
   git config core.hooksPath .githooks
   ```

## Running Tests

Run all tests before committing:

```bash
# Core tests
luajit test/run_tests.lua

# User API tests
luajit test/test_user_api.lua

# Advanced crypto tests
luajit test/test_advanced_crypto.lua

# WebSocket tests
luajit test/test_websocket.lua
```

Tests automatically run via pre-commit hook.

## Code Style

- **Lua**: 4 spaces indentation, no trailing whitespace
- **Rust**: Follow `rustfmt` defaults
- **Comments**: Clear, concise, explain why not what
- **Documentation**: Update docs for any API changes

## Submitting Changes

1. **Fork the repository**
2. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Write tests for new features
   - Ensure all tests pass
   - Update documentation

4. **Commit with clear messages:**
   ```bash
   git commit -m "feat: add new feature X
   
   - Detailed description
   - Why this change is needed
   - Any breaking changes"
   ```

5. **Push and create a Pull Request:**
   ```bash
   git push origin feature/your-feature-name
   ```

## Commit Message Convention

Follow conventional commits:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test updates
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `chore:` - Maintenance tasks

## Pull Request Guidelines

- Clear title and description
- Reference any related issues
- Include test coverage
- Update CHANGELOG.md if applicable
- Ensure CI passes

## Testing Guidelines

- All new features must have tests
- Tests should cover happy path and edge cases
- Use descriptive test names
- Mock external dependencies when possible

## Documentation

Update these when making changes:

- `README.md` - For user-facing changes
- `docs/API.md` - For API changes
- `docs/SECURITY.md` - For security-related changes
- Inline code comments - For complex logic

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for design questions
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
