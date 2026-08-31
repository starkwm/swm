# swm

[![CI](https://github.com/starkwm/swm/actions/workflows/ci.yml/badge.svg)](https://github.com/starkwm/swm/actions/workflows/ci.yml)

Stark Window Manager for macOS.

`swm` is a command-line window manager with optional automatic tiling. One `swm` process runs as a daemon and tracks applications, displays, Spaces, and windows. Other invocations send commands to that daemon.

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

Run `swm` without `--message` to start the daemon:

```sh
swm [--config <path>] [--log-level <level>]
```

Send a command to the running daemon with `--message` or `-m`:

```sh
swm -m <domain> <command> [arguments]
```

The available domains are `query`, `window`, `space`, `config`, and `signal`. Commands print their result to standard output and return a non-zero exit status on failure.

Other top-level options:

```text
-h, --help                 Show help
-v, --version              Show the version
-c, --config <path>        Use a different startup configuration file
    --log-level <level>    debug, info, warn, or error (default: info)
```

Window commands use the focused window when `[window]` is omitted. Supply a numeric window ID, or `recent` for the previously focused window.

## Query state

Queries return JSON. Query all tracked objects of one type:

```sh
swm -m query --displays
swm -m query --spaces
swm -m query --windows
```

Add at most one selector to filter the result:

```sh
swm -m query --windows --display 1
swm -m query --windows --space 0
swm -m query --windows --window 12345
```

A selector can be used on its own. Without a value it selects the focused object:

```sh
swm -m query --display [display-index]
swm -m query --space [space-index]
swm -m query --window [window-id]
```

Display indexes are one-based and follow the physical display arrangement. Space indexes are zero-based. A filtered query returns one JSON object when the selector identifies the same type as the query; otherwise it returns an array of related objects.

## Manage windows

### Focus and minimize

```sh
swm -m window --focus [window|recent|left|right|up|down]
swm -m window --minimize [window|recent]
swm -m window --unminimize [window|recent]
```

Directional focus chooses the nearest non-minimized window on the currently visible Spaces.

### Move, resize, and place

```sh
swm -m window --move [window|recent] <abs|rel>:<x>:<y>
swm -m window --resize [window|recent] <abs|rel>:<width>:<height>
swm -m window --grid [window|recent] <columns>:<rows>:<x>:<y>:<width>:<height>
swm -m window --display [window|recent] <next|prev|display-index>
```

`abs` sets coordinates or dimensions; `rel` adds signed values to the current frame. Grid coordinates start at `0:0` in the top-left. The final width and height are cell spans. For example, this places the focused window in the right half of a 2-by-1 grid:

```sh
swm -m window --grid 2:1:1:0:1:1
```

Display indexes are one-based. `next` and `prev` wrap around the arranged display list; `previous` is also accepted.

### Control tiling

```sh
swm -m window --layout [window|recent] <float|tile|toggle>
swm -m window --cycle <next|prev>
swm -m window --swap-cycle <next|prev>
swm -m window --swap [window|recent] <left|right|up|down>
swm -m window --swap-with-master [window|recent]
swm -m window --focus-master [window|recent]
swm -m window --split-ratio [window|recent] <abs|rel>:<ratio>
swm -m window --toggle-split [window|recent]
swm -m window --swap-split [window|recent]
```

- `--layout` floats a window, returns it to tiling, or toggles its state.
- `--cycle` focuses the next or previous window in stable layout order.
- `--swap-cycle` swaps the focused tiled window with its ordered neighbour.
- `--swap` swaps tiled positions, or complete frames in a floating layout.
- `--swap-with-master` promotes a window in a master layout.
- `--focus-master` focuses the master window for the selected window's layout.
- `--split-ratio` changes the nearest dwindle split; ratios are clamped to `0.1...0.9`.
- `--toggle-split` switches the nearest retained dwindle split between columns and rows.
- `--swap-split` exchanges the two subtrees at the nearest dwindle split.

## Configure the active Space

Space commands affect the active Space for the current daemon run:

```sh
swm -m space --layout <float|master|monocle|dwindle>
swm -m space --master-ratio <abs|rel>:<ratio>
swm -m space --master-placement <left|right|top|bottom|next|prev>
swm -m space --preserve-split <on|off>
swm -m space --padding <abs|rel>:<top>:<bottom>:<left>:<right>
swm -m space --gap <abs|rel>:<points>
```

Padding, gaps, and ratios are clamped to valid values. Space settings apply to every display showing that Space.

The layouts are:

- `float`: do not arrange windows automatically.
- `master`: place one window at the selected edge and the others in a stack.
- `monocle`: overlap every tiled window across the available bounds.
- `dwindle`: recursively split the available bounds around the focused window.

In a dwindle layout, new windows split the focused tiled window and removing a window collapses its sibling branch. Splits normally follow the longest available edge. `--preserve-split on` retains each branch's chosen direction so it can be changed with `window --toggle-split`.

Each physical display has an independent tiling layout, including when macOS's **Displays have separate Spaces** setting is disabled. Moving a tiled window between displays moves it into the destination layout. Manually moving or resizing a tiled window causes it to snap back into place.

## Set global defaults

Config commands update every current Space and become the defaults for Spaces discovered later:

```sh
swm -m config layout <float|master|monocle|dwindle>
swm -m config master-ratio <ratio>
swm -m config master-placement <left|right|top|bottom>
swm -m config preserve-split <on|off>
swm -m config window-gap <points>
swm -m config top-padding <points>
swm -m config bottom-padding <points>
swm -m config left-padding <points>
swm -m config right-padding <points>
```

Built-in defaults are floating layout, `0.5` master ratio, master on the left, split preservation off, and zero padding and gaps. Negative padding or gap values are clamped to zero.

## Configuration file

At startup, the daemon executes `~/.config/swm/swmrc` if it exists. Use `--config <path>` to select another file; an explicitly selected file must exist. `swm` makes the file owner-executable when needed and stops if it exits unsuccessfully.

The file can be any executable script. A shell script is the simplest option:

```sh
#!/bin/sh

swm -m config layout dwindle
swm -m config window-gap 8
swm -m config top-padding 8
swm -m config bottom-padding 8
swm -m config left-padding 8
swm -m config right-padding 8
```

## Run commands on events

Signals run shell actions after matching runtime events:

```sh
swm -m signal --add event=window-focused action='echo "$SWM_WINDOW_ID"'
swm -m signal --add event=window-created app='^Safari$' label=safari-created action='echo "$SWM_WINDOW_ID"'
swm -m signal --list
swm -m signal --remove <index|label>
```

`--add` requires `event` and `action`. It also accepts:

- `label=<text>`: unique name used by `--remove`.
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
hyper + h: swm -m window --grid 2:1:0:0:1:1
hyper + l: swm -m window --grid 2:1:1:0:1:1
hyper + f: swm -m window --grid 1:1:0:0:1:1
hyper + r: swm -m window --focus recent
```
