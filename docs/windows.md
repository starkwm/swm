# Manage windows

[Documentation index](index.md)

The `--window` option accepts a numeric window ID, or `recent` for the previously focused window. Commands that accept `--window` use the focused window when it is omitted.

## Focus and minimize

```sh
swm window focus <left|right|up|down|next|prev|recent|master|window-id>
swm window minimize [--window <window|recent>]
swm window unminimize [--window <window|recent>]
```

- `left`, `right`, `up`, and `down` focus the nearest non-minimized window on the currently visible Spaces.
- `next` and `prev` focus the next or previous window in stable layout order.
- `recent` focuses the previously focused window, and a window ID focuses that window.
- `master` focuses the master window for the focused window's layout.

## Move the mouse cursor

```sh
swm window warp [--window <window|recent> | <left|right|up|down>]
```

`warp` moves the mouse cursor to the selected window's center without focusing or raising it,
switching Spaces, or generating a mouse movement event. It defaults to the focused window.
Hidden, minimized, and off-Space windows are rejected. If the center is off-screen,
the cursor moves to the center of the largest part of the window visible on a display.

Directional warping chooses the nearest non-minimized, on-screen window in the requested
direction from the managed window under the cursor. If the cursor is not over an available
managed window, it starts from the focused window. Each command checks the window under the
cursor again, so repeated warps navigate between windows without changing focus. If another
window covers the destination, the next warp starts from that covering window.
`--window` and a direction cannot be combined.

## Move, resize, and place

```sh
swm window move [--window <window|recent>] <abs|rel>:<x>:<y>
swm window resize [--window <window|recent>] <abs|rel>:<width>:<height>
swm window grid [--window <window|recent>] <columns>:<rows>:<x>:<y>:<width>:<height>
swm window display [--window <window|recent>] <next|prev|display-index>
```

`abs` sets coordinates or dimensions; `rel` adds signed values to the current frame. Grid cells share the padded screen bounds, with the configured gap between adjacent cells. A multi-cell span includes its internal gaps; a full-axis span uses the entire padded axis. Grid coordinates start at `0:0` in the top-left. The final width and height are cell spans. For example, this places the focused window in the right half of a 2-by-1 grid:

```sh
swm window grid 2:1:1:0:1:1
```

Display indexes are one-based. `next` and `prev` wrap around the arranged display list; `previous` is also accepted.

## Move between Spaces

```sh
swm window space [--window <window|recent>] <space-index|next|prev>
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
swm window space next
swm window space --window <window-id> 0
```

## Control tiling

```sh
swm window layout [--window <window|recent>] <float|tile|toggle>
swm window swap [--window <window|recent>] <left|right|up|down|next|prev|master>
swm window split-ratio [--window <window|recent>] <ratio>
swm window toggle-split [--window <window|recent>]
swm window swap-split [--window <window|recent>]
```

- `layout` floats a window, returns it to tiling, or toggles its state.
- `swap left|right|up|down` swaps tiled positions with the neighbour in that direction, or complete frames in a floating layout.
- `swap next|prev` swaps the focused tiled window with its neighbour in stable layout order, and does not accept `--window`.
- `swap master` promotes a window in a master layout.
- `split-ratio` sets the nearest dwindle split to a ratio from `0.1` through `0.9`, or adjusts it by a signed change such as `+0.05`; adjustments are clamped to that range.
- `toggle-split` switches the nearest retained dwindle split between columns and rows.
- `swap-split` exchanges the two subtrees at the nearest dwindle split.

See [space layouts](spaces.md#layouts) for master, monocle, and dwindle behavior, and [window animation](configuration.md#window-animation) for movement settings.
