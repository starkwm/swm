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

Guides:

- [Getting started](docs/getting-started.md): requirements, installation, and source builds.
- [Configuration](docs/configuration.md): startup scripts, global defaults, and window animation.
- [Command line](docs/cli.md): daemon startup, command syntax, help, and shell completions.
- [Keyboard shortcuts](docs/keyboard-shortcuts.md): invoke swm commands from a hotkey daemon.
- [Testing](docs/testing.md): run focused suites and benchmark the edit-build-test cycle.

Command reference:

- [Query state](docs/query.md): inspect displays, spaces, and windows as JSON.
- [Manage windows](docs/windows.md): focus, minimize, move, resize, and control tiling.
- [Configure spaces](docs/spaces.md): activation, layouts, padding, gaps, and display behavior.
- [Manage displays](docs/displays.md): focus displays by index, order, recency, or direction.
- [Signals](docs/signals.md): register shell actions for runtime events.
- [Window rules](docs/rules.md): keep windows floating or place them on a display.
