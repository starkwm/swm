# swm

[![CI](https://github.com/starkwm/swm/actions/workflows/ci.yml/badge.svg)](https://github.com/starkwm/swm/actions/workflows/ci.yml)

Stark Window Manager for macOS.

`swm` is a command-line window manager with optional automatic tiling. One `swm` process runs as a daemon and tracks applications, displays, spaces, and windows. Other invocations send commands to that daemon.

It is inspired by [yabai](https://github.com/asmvik/yabai) and replaces the JavaScript configuration used by its predecessor, [Stark](https://github.com/starkwm/stark), with a small shell-based command interface.

## Quick start

Requires macOS 26 or later and Accessibility permission for `swm`.

```sh
brew tap starkwm/formulae
brew install starkwm/formulae/swm
brew services start swm
```

Grant Accessibility permission when prompted. `swm` starts with a floating layout. Create `~/.config/swm/swmrc` to enable tiling and apply settings at startup.

See [getting started](docs/getting-started.md) for requirements and source builds, or the [configuration guide](docs/configuration.md) for an example startup script.

## Documentation

The [documentation index](docs/index.md) links to all guides and command references.

- [Command line](docs/cli.md)
- [Query state](docs/query.md)
- [Manage windows](docs/windows.md)
- [Configure spaces](docs/spaces.md)
- [Signals](docs/signals.md)
- [Keyboard shortcuts](docs/keyboard-shortcuts.md)
