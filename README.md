# swm

[![CI](https://github.com/starkwm/swm/actions/workflows/ci.yml/badge.svg)](https://github.com/starkwm/swm/actions/workflows/ci.yml)

Stark Window Manager for macOS.

`swm` is a command-line window manager with optional automatic tiling. One `swm` process runs as a daemon and tracks applications, displays, spaces, and windows. Other invocations send commands to that daemon.

It is inspired by [yabai](https://github.com/asmvik/yabai) and replaces the JavaScript configuration used by its predecessor, [Stark](https://github.com/starkwm/stark), with a small shell-based command interface.

## Requirements

- macOS 26 or later
- Accessibility permission for `swm`
- Xcode 26 or later when building from source

`swm` uses private macOS frameworks. A macOS update may change behavior that it relies on.

## Install

Install the latest release with Homebrew:

```sh
brew tap starkwm/formulae
brew install starkwm/formulae/swm
```

Start it now and at login:

```sh
brew services start swm
```

Or build from source:

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

## How commands work

Run `swm` without a subcommand to start the daemon. `swm start` is the explicit equivalent:

```sh
swm [start] [--config <path>] [--log-level <level>]
```

Send commands to the running daemon through command-specific subcommands:

```sh
swm <domain> <command> [arguments]
```

The available domains are `query`, `window`, `space`, `config`, and `signal`. Commands print their result to standard output and return a non-zero exit status on failure. Run `swm --help`, `swm <domain> --help`, or `swm help <domain> <command>` for progressively more specific help.

Top-level options:

```text
-h, --help                 Show help
    --version              Show the version
```

Daemon startup options, accepted by `swm` and `swm start`:

```text
-c, --config <path>        Use a different startup configuration file
    --log-level <level>    debug, info, warn, or error (default: info)
```

## Query state

Queries return JSON. Query all tracked objects of one type:

```sh
swm query displays
swm query spaces
swm query windows
```

Add at most one selector to filter the result:

```sh
swm query windows --display 1
swm query windows --space 0
swm query windows --window 12345
```

Singular query commands accept an optional index or ID. Without one they return the focused object:

```sh
swm query display [display-index]
swm query space [space-index]
swm query window [window-id]
```

Display indexes are one-based and follow the physical display arrangement. Space indexes are zero-based. A filtered query returns one JSON object when the selector identifies the same type as the query; otherwise it returns an array of related objects.

## Manage windows

The `--window` option accepts a numeric window ID, or `recent` for the previously focused window. Commands that accept `--window` use the focused window when it and any alternative target, such as `--direction`, are omitted.

### Focus and minimize

```sh
swm window focus [--window <window|recent> | --direction <left|right|up|down>]
swm window minimize [--window <window|recent>]
swm window unminimize [--window <window|recent>]
```

Directional focus chooses the nearest non-minimized window on the currently visible spaces.

### Move, resize, and place

```sh
swm window move [--window <window|recent>] <abs|rel>:<x>:<y>
swm window resize [--window <window|recent>] <abs|rel>:<width>:<height>
swm window grid [--window <window|recent>] <columns>:<rows>:<x>:<y>:<width>:<height>
swm window display [--window <window|recent>] <next|prev|display-index>
```

`abs` sets coordinates or dimensions; `rel` adds signed values to the current frame. Grid coordinates start at `0:0` in the top-left. The final width and height are cell spans. For example, this places the focused window in the right half of a 2-by-1 grid:

```sh
swm window grid 2:1:1:0:1:1
```

Display indexes are one-based. `next` and `prev` wrap around the arranged display list; `previous` is also accepted.

### Control tiling

```sh
swm window layout [--window <window|recent>] <float|tile|toggle>
swm window cycle --direction <next|prev>
swm window swap-cycle --direction <next|prev>
swm window swap [--window <window|recent>] --direction <left|right|up|down>
swm window swap-with-master [--window <window|recent>]
swm window focus-master [--window <window|recent>]
swm window split-ratio [--window <window|recent>] <abs|rel>:<ratio>
swm window toggle-split [--window <window|recent>]
swm window swap-split [--window <window|recent>]
```

- `layout` floats a window, returns it to tiling, or toggles its state.
- `cycle` focuses the next or previous window in stable layout order.
- `swap-cycle` swaps the focused tiled window with its ordered neighbour.
- `swap` swaps tiled positions, or complete frames in a floating layout.
- `swap-with-master` promotes a window in a master layout.
- `focus-master` focuses the master window for the selected window's layout.
- `split-ratio` changes the nearest dwindle split; ratios are clamped to `0.1...0.9`.
- `toggle-split` switches the nearest retained dwindle split between columns and rows.
- `swap-split` exchanges the two subtrees at the nearest dwindle split.

## Configure spaces

Space commands affect the active space by default. Use `--space <space-index>` to select another space by its zero-based index from `swm query spaces`. Indexes follow the current Space ordering and may change when Spaces are reordered:

```sh
swm space layout [--space <space-index>] <float|master|monocle|dwindle>
swm space master-ratio [--space <space-index>] <abs|rel>:<ratio>
swm space master-placement [--space <space-index>] <left|right|top|bottom|next|prev>
swm space preserve-split [--space <space-index>] <on|off>
swm space padding [--space <space-index>] <abs|rel>:<top>:<bottom>:<left>:<right>
swm space gap [--space <space-index>] <abs|rel>:<points>
```

Padding, gaps, and ratios are clamped to valid values. Space settings apply to every display showing that space.

The layouts are:

- `float`: do not arrange windows automatically.
- `master`: place one window at the selected edge and the others in a stack.
- `monocle`: overlap every tiled window across the available bounds.
- `dwindle`: recursively split the available bounds around the focused window.

In a dwindle layout, new windows split the focused tiled window and removing a window collapses its sibling branch. Splits normally follow the longest available edge. `swm space preserve-split on` retains each branch's chosen direction so it can be changed with `swm window toggle-split`.

Each physical display has an independent tiling layout, including when macOS's **Displays have separate Spaces** setting is disabled. Moving a tiled window between displays moves it into the destination layout. Manually moving or resizing a tiled window causes it to snap back into place.

## Set global defaults

Config commands update every current space and become the defaults for spaces discovered later:

```sh
swm config layout <float|master|monocle|dwindle>
swm config focus-follows-mouse <off|autofocus|autoraise>
swm config master-ratio <ratio>
swm config master-placement <left|right|top|bottom>
swm config preserve-split <on|off>
swm config window-gap <points>
swm config top-padding <points>
swm config bottom-padding <points>
swm config left-padding <points>
swm config right-padding <points>
```

Built-in defaults are floating layout, focus-follows-mouse off, `0.5` master ratio, master on the left, split preservation off, and zero padding and gaps. Negative padding or gap values are clamped to zero.

## Configuration file

At startup, the daemon executes `~/.config/swm/swmrc` if it exists. Use `--config <path>` to select another file; an explicitly selected file must exist. `swm` makes the file owner-executable when needed and stops if it exits unsuccessfully.

The file can be any executable script. A shell script is the simplest option:

```sh
#!/bin/sh

swm config layout dwindle
swm config focus-follows-mouse autofocus
swm config window-gap 8
swm config top-padding 8
swm config bottom-padding 8
swm config left-padding 8
swm config right-padding 8
```

## Run commands on events

Signals run shell actions after matching runtime events:

```sh
swm signal add event=window-focused action='echo "$SWM_WINDOW_ID"'
swm signal add event=window-created app='^Safari$' label=safari-created action='echo "$SWM_WINDOW_ID"'
swm signal list
swm signal remove <index|label>
```

`add` requires `event` and `action`. It also accepts:

- `label=<text>`: unique name used by `remove`.
- `app=<regex>` and `title=<regex>`: require a regular-expression match.
- `app!=<regex>` and `title!=<regex>`: require the value not to match.
- `active=yes|no`: filter application and window events by active or focused state.

Supported events:

- `application-launched`
- `application-terminated`
- `application-front-switched`
- `window-created`
- `window-destroyed`
- `window-focused`
- `window-moved`
- `window-resized`
- `window-minimized`
- `window-deminimized`
- `space-changed`
- `display-changed`
- `display-added`
- `display-removed`
- `display-moved`
- `display-resized`

Actions run asynchronously through `/usr/bin/env sh -c`. Depending on the event, the action receives these environment variables:

- `SWM_PROCESS_ID`
- `SWM_WINDOW_ID`
- `SWM_SPACE_ID`
- `SWM_SPACE_INDEX`
- `SWM_RECENT_SPACE_ID`
- `SWM_RECENT_SPACE_INDEX`
- `SWM_DISPLAY_ID`
- `SWM_RECENT_DISPLAY_ID`
- `SWM_EVENT_DISPLAY_ID`

Signal registrations exist only for the current daemon run, so put persistent registrations in `swmrc`.

## Keyboard shortcuts

`swm` does not bind keys. Use a hotkey daemon such as [skbd](https://github.com/starkwm/skbd) to invoke its commands:

```text
hyper + h: swm window grid 2:1:0:0:1:1
hyper + l: swm window grid 2:1:1:0:1:1
hyper + f: swm window grid 1:1:0:0:1:1
hyper + r: swm window focus --window recent
```
