# Contributing to rescript-signals

Thank you for your interest in contributing to rescript-signals! This document provides guidelines and instructions for contributing.

## Development Setup

1. Fork and clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```
3. Build the project:
   ```bash
   npm run build
   ```
4. Run tests:
   ```bash
   npm test
   ```

## Commit Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/) and enforces the **50/72 rule**:
- Subject line: Maximum 50 characters
- Body lines: Maximum 72 characters per line
- Footer lines: Maximum 72 characters per line

Please read our [Commit Convention Guide](.github/COMMIT_CONVENTION.md) for detailed information.

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Commit Types

- **feat**: New feature (minor version bump)
- **fix**: Bug fix (patch version bump)
- **perf**: Performance improvement (patch version bump)
- **docs**: Documentation changes (patch version bump)
- **style**: Code style changes (patch version bump)
- **refactor**: Code refactoring (patch version bump)
- **test**: Test changes (patch version bump)
- **build**: Build system changes (patch version bump)
- **ci**: CI changes (patch version bump)
- **chore**: Other changes (no version bump)
- **revert**: Revert previous commit (patch version bump)

### Breaking Changes

For major version bumps, add `BREAKING CHANGE:` in the footer or `!` after type:

```
feat!: remove deprecated API

BREAKING CHANGE: The old API has been completely removed.
Users should migrate to the new API.
```

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Ensure all tests pass: `npm test`
4. Ensure code builds: `npm run build`
5. Commit using conventional commits
6. Push to your fork
7. Create a pull request

### PR Requirements

- All tests must pass
- All commits must follow conventional commit format
- Code must build successfully
- Include tests for new features or bug fixes
- Update documentation if needed

## Testing

We use a simple custom test framework. Tests are located in the `tests/` directory.

### Running Tests

```bash
npm test
```

### Writing Tests

See existing tests in `tests/` for examples:

```rescript
open TestFramework
open Signals

let tests = suite(
  "My Feature Tests",
  [
    test("should do something", () => {
      let signal = Signal.make(42)
      assertEqual(Signal.peek(signal), 42, ~message="Should equal 42")
    }),
  ],
)
```

## Release Process

Releases are automated using semantic-release:

1. Commits to `main` trigger the release workflow
2. Semantic-release analyzes commit messages
3. Version is bumped based on commit types
4. CHANGELOG.md is updated
5. Package is published to npm
6. GitHub release is created

### Version Bumping

- `feat`: Minor version bump (0.x.0)
- `fix`, `perf`, `docs`, etc.: Patch version bump (0.0.x)
- `BREAKING CHANGE`: Major version bump (x.0.0)
- `chore`: No version bump

## Code Style

- Follow existing code patterns
- Use ReScript best practices
- Keep functions small and focused
- Add comments for complex logic

## Questions?

Feel free to open an issue for any questions or concerns.
