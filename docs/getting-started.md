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

The development binary is written to `.build/debug/swm`. Run it once, then grant it Accessibility permission as described below:

```sh
.build/debug/swm
```

A source build is not installed as a background service automatically.

## Grant Accessibility permission

`swm` needs Accessibility permission to read and move windows. Without it, `swm` exits with an error that names the binary to add.

On macOS 27.3 and later, macOS no longer prompts for this permission, and the Accessibility list only shows apps with an Accessibility designation. Add `swm` manually:

1. Open System Settings > Privacy & Security > System & App Protection Override.
2. Click +, press Command-Shift-G, and enter the path of the `swm` binary. For a Homebrew install, use the versioned path that `realpath "$(which swm)"` prints, such as `/opt/homebrew/Cellar/swm/0.0.32/bin/swm`.
3. Start `swm` again, for example with `brew services restart swm`.

On earlier macOS versions, grant the permission when prompted, or add `swm` in System Settings > Privacy & Security > Accessibility.

macOS ties the permission to the exact binary. After `brew upgrade swm` or a source rebuild, remove the old `swm` entry and add the new binary.

## Configure swm

The default layout is floating. Create `~/.config/swm/swmrc` to choose a layout and apply settings at startup. The [configuration guide](configuration.md) includes an example script.

See [command-line usage](cli.md) for daemon options and shell completions, and [keyboard shortcuts](keyboard-shortcuts.md) to run commands from a hotkey daemon.
