# swm

[![CI](https://github.com/starkwm/swm/actions/workflows/ci.yml/badge.svg)](https://github.com/starkwm/swm/actions/workflows/ci.yml)

**Stark Window Manager for macOS**

`swm` is inspired by [Yabai][yabai] as a client and daemon program for managing windows on macOS. While `swm` doesn't do the tiling window management, it uses similar methods for maintaining state for managing windows.

[yabai]: https://github.com/asmvik/yabai

My original window manager for macOS was [Stark][stark], which I started back at the start of 2016. I wanted to move away from the JavaScript based configuration and having to maintain a public API mapping to Swift code. I ended up slowly writing this project from scratch.

[stark]: https://github.com/starkwm/stark

## Installation

The recommended way to get `swm` installed is using [Homebrew](https://brew.sh).

    brew tap starkwm/formulae
    brew install starkwm/formulae/swm

If installed with Homebrew, you can use `brew services` to manage running `swm` in the background.

Alternatively you can build from source, which requires the latest Xcode to be installed.

    git clone git@github.com:starkwm/swm.git
    cd swm
    make # output is in .build/debug

If you build from source, you'll need to create a Launch Agent `.plist` file to run `swm` in the background.

## Usage

`swm` runs as a daemon. Commands are sent to the daemon with `-m`/`--message`.

    swm --help
    swm --version

**Query**

Use query commands to inspect the tracked displays, spaces, and windows. Add one selector to filter the result.

    swm -m query --displays
    swm -m query --spaces
    swm -m query --windows
    swm -m query --displays [--display <display-index>|--space <space-index>|--window <window-id>]
    swm -m query --spaces [--display <display-index>|--space <space-index>|--window <window-id>]
    swm -m query --windows [--display <display-index>|--space <space-index>|--window <window-id>]
    swm -m query --display [display-index]
    swm -m query --space [space-index]
    swm -m query --window <window-id>

Selector-only queries default to the matching result type: `--display` queries displays, `--space` queries spaces, and `--window` queries windows.

**Window**

Use window commands to focus, minimize, move, resize, or place windows on a grid.

    swm -m window --focus [window-id|recent]
    swm -m window --minimize [window-id|recent]
    swm -m window --unminimize [window-id|recent]
    swm -m window --move [window-id|recent] abs:<x>:<y>
    swm -m window --resize [window-id|recent] abs:<width>:<height>
    swm -m window --grid [window-id|recent] <columns>:<rows>:<x>:<y>:<width>:<height>

Use `rel:<x>:<y>` with `--move` or `rel:<width>:<height>` with `--resize` for relative changes.

**Space**

Use space commands to change padding and gap settings for the active space.

    swm -m space --toggle padding
    swm -m space --toggle gap
    swm -m space --padding abs:<top>:<right>:<bottom>:<left>
    swm -m space --gap abs:<number>

Use `rel:` instead of `abs:` for relative padding and gap changes.

**Config**

Use config commands to update defaults for all spaces.

    swm -m config window-gap <number>
    swm -m config top-padding <number>
    swm -m config right-padding <number>
    swm -m config bottom-padding <number>
    swm -m config left-padding <number>

**Signal**

Use signal commands to run shell actions after observed runtime events.

    swm -m signal --add event=window-focused action='echo $SWM_WINDOW_ID'
    swm -m signal --add event=window-created action='echo "$SWM_PROCESS_ID $SWM_WINDOW_ID"' label=created app=Safari
    swm -m signal --list
    swm -m signal --remove created

Signal actions run asynchronously through `/usr/bin/env sh -c`. Event values are exposed as
`SWM_*` environment variables, such as `SWM_PROCESS_ID`, `SWM_WINDOW_ID`, `SWM_SPACE_ID`,
`SWM_RECENT_SPACE_ID`, `SWM_DISPLAY_ID`, and `SWM_RECENT_DISPLAY_ID`.

**Keyboard Shortcuts**

`swm` does not bind keyboard shortcuts itself. Use a key binding daemon like [skbd][skbd] to run `swm` commands from shortcuts.

    hyper + h: swm -m window --grid 2:1:0:0:1:1
    hyper + l: swm -m window --grid 2:1:1:0:1:1
    hyper + f: swm -m window --grid 1:1:0:0:1:1
    hyper + r: swm -m window --focus recent

[skbd]: https://github.com/starkwm/skbd

## Configuration

`swm` is configured by a single file, `~/.config/swm/swmrc`. This file should be an executable shell script. You can call the `swm` binary to configure options.

**Window Gaps**

You can use `swm -m config window-gap <number>` to configure the size of the gap between windows, when using the `-m window --grid` command.

**Padding**

You can use the following commands to configure the padding around each edge of a macOS space.

- `swm -m config top-padding <number>`
- `swm -m config right-padding <number>`
- `swm -m config bottom-padding <number>`
- `swm -m config left-padding <number>`
