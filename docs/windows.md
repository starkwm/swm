# Manage windows

[Documentation index](index.md)

The `--window` option accepts a numeric window ID, or `recent` for the previously focused window. Commands that accept `--window` use the focused window when it is omitted.

## Focus and minimize

```sh
swm window focus <left|right|up|down|next|prev|recent|master|window-id>
swm window minimize [<recent|window-id>]
swm window unminimize <recent|window-id>
```

- `left`, `right`, `up`, and `down` focus the nearest non-minimized window on the currently visible Spaces.
- `next` and `prev` focus the next or previous window in stable layout order.
- `recent` focuses the previously focused window, and a window ID focuses that window.
- `master` focuses the master window for the focused window's layout.

`minimize` and `unminimize` accept `recent` for the previously focused window or a positive window ID. Omit the target to minimize the focused window. `unminimize` requires a target, because a minimized window is never the focused window; right after minimizing, `recent` selects the window that was minimized.

```sh
swm window minimize
swm window minimize recent
swm window unminimize recent
swm window unminimize 123
```

## Move the mouse cursor

```sh
swm window warp [<left|right|up|down|recent|window-id>]
```

`warp` moves the mouse cursor to the selected window's center without focusing or raising it,
switching Spaces, or generating a mouse movement event. Omit the target to use the focused window, or pass `recent` for the previously focused window.
Hidden, minimized, and off-Space windows are rejected. If the center is off-screen,
the cursor moves to the center of the largest part of the window visible on a display.

Directional warping chooses the nearest non-minimized, on-screen window in the requested
direction from the managed window under the cursor. If the cursor is not over an available
managed window, it starts from the focused window. Each command checks the window under the
cursor again, so repeated warps navigate between windows without changing focus. If another
window covers the destination, the next warp starts from that covering window.

## Move, resize, and place

```sh
swm window move [--window <window|recent>] [--absolute] <x> <y>
swm window resize [--window <window|recent>] [--absolute] <width> <height>
swm window grid [--window <window|recent>] <columns> <rows> <x> <y> <width> <height>
swm window move [--window <window|recent>] --display <next|prev|previous|display-index>
```

Choose one `move` mode: `<x> <y>`, `--display <target>`, or `--space <target>`. Use `--absolute` only with coordinates. Moving to a display or Space keeps the current Space active.

`move <x> <y>` and `resize <width> <height>` take integer values in points. They add offsets to the current position or size by default. Use `--absolute` to set the top-left coordinates or dimensions.

Negative values work in either position, even between options. No `--` separator is needed:

```sh
swm window move 20 0
swm window resize 40 0
swm window move --absolute 0 25
swm window resize --absolute 1200 800
swm window move -20 --window recent -10
swm window resize -40 --window 42 0
```

The old encoded `abs:...` and `rel:...` CLI arguments are rejected.

Grid cells share the padded screen bounds, with the configured gap between adjacent cells. A multi-cell span includes its internal gaps; a full-axis span uses the entire padded axis. Grid takes six integers. Columns and rows must be positive. Coordinates start at `0 0` in the top-left and are clamped to the grid. The final width and height are cell spans, clamped to at least one cell and the remaining cells on each axis. For example, this places the focused window in the right half of a 2-by-1 grid:

```sh
swm window grid 2 1 1 0 1 1
```

Moving by coordinates, resizing, and grid placement work on windows floated with `swm window float on`, windows on a Space with the `float` layout, and windows on more than one Space. swm rejects tiled windows with `window is tiled`, because the next layout reflow would put them back.

Move the focused window to the next display, or window 123 to display 2:

```sh
swm window move --display next
swm window move --window 123 --display 2
```

Display indexes are one-based. `next` and `prev` wrap around the arranged display list; `previous` is also accepted.

## Move between Spaces

```sh
swm window move [--window <window|recent>] --space <space-index|next|prev|previous>
```

Space indexes are one-based and match `swm query spaces`. `next` and `prev` cycle through normal desktop Spaces in query order, skip fullscreen Spaces, and wrap at either end. `previous` is also accepted. The command defaults to the focused window and keeps the current Space active. Moves to a Space on another display fit the window within that display's visible bounds.

Only windows belonging to one normal desktop Space can move. Fullscreen windows and windows assigned to multiple Spaces are rejected. A move to the window's current Space does not submit a bridge operation.

Movement uses a private SkyLight bridge with SIP enabled. The command polls for roughly two seconds for WindowServer to confirm the new Space membership, then updates visible tiling layouts. If the bridge is unavailable or movement cannot be confirmed, the command returns an error. A timeout does not undo a move that completes later.

Stop any running daemon and start `swm` with debug logging:

```sh
swm start --log-level debug
```

Then test from another terminal:

```sh
swm query spaces
swm window move --space next
swm window move --window <window-id> --space 3
```

## Control tiling

```sh
swm window float [--window <window|recent>] <on|off|toggle>
swm window swap [--window <window|recent>] <left|right|up|down|next|prev|master>
swm window split-ratio [--window <window|recent>] <ratio>
swm window toggle-split [--window <window|recent>]
swm window swap-split [--window <window|recent>]
```

- `float on` floats the selected window. `float off` returns it to tiling, and `float toggle` switches between the two. These choices override management rules until the window closes or the daemon restarts.
- `swap left|right|up|down` swaps tiled positions with the neighbour in that direction, or complete frames in a floating layout.
- `swap next|prev` swaps the focused tiled window with its neighbour in stable layout order, and does not accept `--window`.
- `swap master` promotes a window in a master layout.
- `split-ratio` sets the nearest dwindle split to a ratio from `0.1` through `0.9`, or adjusts it by a signed change such as `+0.05`; adjustments are clamped to that range.
- `toggle-split` switches the nearest dwindle split between columns and rows. It requires `swm config preserve-split --space current on`.
- `swap-split` exchanges the two subtrees at the nearest dwindle split.

See [space layouts](spaces.md#layouts) for master, monocle, and dwindle behavior, and [window animation](configuration.md#window-animation) for movement settings.
