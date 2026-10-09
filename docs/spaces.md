# Configure spaces

[Documentation index](index.md)

## Activate a Space

```sh
swm query spaces
swm space activate <space-index>
```

Activation uses the zero-based `index` from `swm query spaces`. It changes the visible Desktop on the target's display without requesting keyboard-focus transfer between displays. The target display must contain only normal desktop Spaces; layouts containing native fullscreen Spaces are currently refused.

swm submits native show, hide, and set-current operations and waits up to two seconds for the target display to report the requested current Space. A timeout or cancellation after submission does not mean the Space stayed unchanged. Query the state before retrying.

Activation is implemented in Swift using private SkyLight operations. Entry points and method signatures are checked at runtime. Compatibility depends on the macOS version, and live activation remains subject to manual testing.

## Configure a Space

Space commands affect the active space by default. Use `--space <space-index>` to select another space by its zero-based index from `swm query spaces`. Indexes follow the current Space ordering and may change when Spaces are reordered:

```sh
swm space layout [--space <space-index>] <float|master|monocle|dwindle|scrolling>
swm space master-ratio [--space <space-index>] <abs|rel>:<ratio>
swm space master-placement [--space <space-index>] <left|right|top|bottom|next|prev>
swm space preserve-split [--space <space-index>] <on|off>
swm space padding [--space <space-index>] <abs|rel>:<top>:<bottom>:<left>:<right>
swm space gap [--space <space-index>] <abs|rel>:<points>
```

Padding, gaps, and ratios are clamped to valid values. Space settings apply to every display showing that space.

## Layouts

The layouts are:

- `float`: do not arrange windows automatically.
- `master`: place one window at the selected edge and the others in a stack.
- `monocle`: overlap every tiled window across the available bounds.
- `dwindle`: recursively split the available bounds around the focused window.
- `scrolling`: arrange one window per column on a horizontal strip with stable widths.

In a dwindle layout, new windows split the focused tiled window and removing a window collapses its sibling branch. Splits normally follow the longest available edge. `swm space preserve-split on` retains each branch's chosen direction so it can be changed with `swm window toggle-split`.

Each physical display has an independent tiling layout, including when macOS's **Displays have separate Spaces** setting is disabled. Moving a tiled window between displays moves it into the destination layout. Manually moving or resizing a tiled window causes it to snap back into place.

Use [global defaults](configuration.md#global-defaults) to set the default layout, padding, and gaps. [Window tiling commands](windows.md#control-tiling) control individual windows within a layout.

## Scrolling layout

```sh
swm config scrolling-column-width 0.5
swm config scrolling-focus-fit fit
swm config layout scrolling
```

Each Space and display has its own column order and viewport. Opening a window inserts a column after the focused tiled window without resizing existing columns. Left and right focus follow column order, including off-screen columns, and stop at the strip ends. `window cycle` wraps. Up and down have no scrolling neighbour in this version.

Use `window column-width abs:0.5` or `rel:0.1` to change a column's width. `next` and `prev` cycle through one-third, one-half, two-thirds, and full width. Fractions account for gaps, so two half-width columns fit together. `window column-center` centers the selected column once, independently of the focus policy. `window swap` and `swap-cycle` move the column together with its width.

Minimized, floating, and native fullscreen windows retain their columns but do not occupy strip geometry. Returning to tiling restores their widths and order. Switching to another layout also retains scrolling state. State lasts for the current daemon session; restarting rebuilds the column order from the managed windows.

macOS shares window coordinates between displays. swm parks off-screen windows at a free display edge with a one-point sliver on their owner. It chooses another edge when the preferred edge would overlap an adjacent display. Partially visible columns that would extend onto another display are also parked until focus reveals them. Parking slivers do not trigger focus-follows-mouse.

If every parking edge intersects another display, swm leaves the frames unchanged and reports `scrollingParking` in `query layouts`. When an app refuses a narrower width, swm retains the observed minimum width and recalculates the strip. An explicit column-width command retries the requested size. A minimum wider than the display reports `scrollingColumnWidth`. Apps can also refuse off-screen positions; inspect debug logs. This initial implementation needs manual desktop testing on your display arrangement.

Floating a parked window, leaving scrolling, or stopping the daemon normally restores the window's pre-scrolling frame within its display. Minimized and native fullscreen windows are not moved while unavailable.

### Test a source build

After stopping any existing daemon, run this from the repository directory:

```sh
.build/debug/swm start --config examples/scrolling/swmrc --log-level debug
```

The [example configuration](../examples/scrolling/swmrc) uses the development binary for its commands. Open several windows, then test from another terminal:

```sh
.build/debug/swm window focus --direction right
.build/debug/swm window cycle --direction next
.build/debug/swm window column-width next
.build/debug/swm window column-center
.build/debug/swm window swap --direction left
.build/debug/swm query layouts
.build/debug/swm space layout float
```

Check that opening windows preserves existing widths, navigation reveals distant columns, and windows stay on their assigned display. Also test minimizing and restoring, native fullscreen return, Space switches, display disconnects, and stopping the daemon with Control-C.
