# Commit Message Convention

This project follows the [Conventional Commits](https://www.conventionalcommits.org/) specification and enforces the 50/72 rule for commit messages.

## Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Header (max 50 characters)

- **type**: The type of change (see below)
- **scope** (optional): The scope of the change (e.g., `signal`, `computed`, `effect`)
- **subject**: A brief description of the change

### Body (max 72 characters per line)

Detailed explanation of the change. This is optional but recommended for
complex changes.

### Footer (max 72 characters per line)

Breaking changes and issue references.

## Types

- **feat**: A new feature (triggers MINOR version bump)
- **fix**: A bug fix (triggers PATCH version bump)
- **perf**: Performance improvements (triggers PATCH version bump)
- **docs**: Documentation changes (triggers PATCH version bump)
- **style**: Code style changes (triggers PATCH version bump)
- **refactor**: Code refactoring (triggers PATCH version bump)
- **test**: Adding or updating tests (triggers PATCH version bump)
- **build**: Build system changes (triggers PATCH version bump)
- **ci**: CI configuration changes (triggers PATCH version bump)
- **chore**: Other changes (no version bump)
- **revert**: Revert a previous commit (triggers PATCH version bump)

## Breaking Changes

To trigger a MAJOR version bump, add `BREAKING CHANGE:` in the footer or add `!` after the type/scope:

```
feat!: remove deprecated API

BREAKING CHANGE: The old API has been removed.
```

## Examples

### Feature
```
feat(signal): add batch update support
```

### Bug Fix
```
fix(computed): prevent infinite loop in cycles
```

### Breaking Change
```
feat(effect)!: change cleanup signature

BREAKING CHANGE: Effect cleanup functions now receive
the previous result as an argument.
```

### With Body
```
refactor(scheduler): optimize dependency tracking

Implement a more efficient algorithm for tracking
dependencies that reduces memory usage by 30%.
```

## 50/72 Rule

- **Header**: Maximum 50 characters
- **Body lines**: Maximum 72 characters per line
- **Footer lines**: Maximum 72 characters per line

This ensures commit messages are readable in various tools and terminals.
