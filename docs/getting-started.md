# Getting started

[Documentation index](index.md)

## Requirements

- macOS 26 or later
- Accessibility permission for `swm`
- Xcode 26 or later when building from source

`swm` uses private macOS frameworks. A macOS update may change behavior that it relies on.

## Installation

### Homebrew

Install the latest release with Homebrew:

```sh
brew tap starkwm/formulae
brew install starkwm/formulae/swm
```

Start it now and at login:

```sh
brew services start swm
```

### Build from source

Build from source:

```sh
git clone https://github.com/starkwm/swm.git
cd swm
make build
```

The development binary is written to `.build/debug/swm`. Run it once and grant the requested Accessibility permission:

```sh
.build/debug/swm
```

A source build is not installed as a background service automatically.

## Configure swm

The default layout is floating. Create `~/.config/swm/swmrc` to choose a layout and apply settings at startup. The [configuration guide](configuration.md) includes an example script.

See [command-line usage](cli.md) for daemon options and shell completions, and [keyboard shortcuts](keyboard-shortcuts.md) to run commands from a hotkey daemon.
