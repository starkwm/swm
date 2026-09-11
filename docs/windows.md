# Manage windows

[Documentation index](index.md)

The `--window` option accepts a numeric window ID, or `recent` for the previously focused window. Commands that accept `--window` use the focused window when it and any alternative target, such as `--direction`, are omitted.

## Focus and minimize

```sh
swm window focus [--window <window|recent> | --direction <left|right|up|down>]
swm window minimize [--window <window|recent>]
swm window unminimize [--window <window|recent>]
```

Directional focus chooses the nearest non-minimized window on the currently visible spaces.

## Move, resize, and place

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

## Control tiling

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

See [space layouts](spaces.md#layouts) for master, monocle, and dwindle behavior, and [window animation](configuration.md#window-animation) for movement settings.
