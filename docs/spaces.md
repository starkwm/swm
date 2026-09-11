# Configure spaces

[Documentation index](index.md)

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

## Layouts

The layouts are:

- `float`: do not arrange windows automatically.
- `master`: place one window at the selected edge and the others in a stack.
- `monocle`: overlap every tiled window across the available bounds.
- `dwindle`: recursively split the available bounds around the focused window.

In a dwindle layout, new windows split the focused tiled window and removing a window collapses its sibling branch. Splits normally follow the longest available edge. `swm space preserve-split on` retains each branch's chosen direction so it can be changed with `swm window toggle-split`.

Each physical display has an independent tiling layout, including when macOS's **Displays have separate Spaces** setting is disabled. Moving a tiled window between displays moves it into the destination layout. Manually moving or resizing a tiled window causes it to snap back into place.

Use [global defaults](configuration.md#global-defaults) to set the default layout, padding, and gaps. [Window tiling commands](windows.md#control-tiling) control individual windows within a layout.
