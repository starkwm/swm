# Configure spaces

[Documentation index](index.md)

## Activate a Space

```sh
swm query spaces
swm space activate <space-index>
```

Activation uses the one-based `index` from `swm query spaces`. It changes the visible Desktop on the target's display without requesting keyboard-focus transfer between displays. The target display must contain only normal desktop Spaces; layouts containing native fullscreen Spaces are currently refused.

swm submits native show, hide, and set-current operations and waits up to two seconds for the target display to report the requested current Space. A timeout or cancellation after submission does not mean the Space stayed unchanged. Query the state before retrying.

Activation is implemented in Swift using private SkyLight operations. Entry points and method signatures are checked at runtime. Compatibility depends on the macOS version, and live activation remains subject to manual testing.

## Configure a Space

Space commands affect the active space by default. Use `--space <space-index>` to select another space by its one-based index from `swm query spaces`. Indexes follow the current Space ordering and may change when Spaces are reordered:

```sh
swm space layout [--space <space-index>] [float|master|monocle|dwindle]
swm space master-ratio [--space <space-index>] [<ratio>]
swm space master-placement [--space <space-index>] [left|right|top|bottom|next|prev]
swm space split-ratio [--space <space-index>] [<ratio>]
swm space preserve-split [--space <space-index>] [on|off]
swm space padding [--space <space-index>] [--top <points>] [--bottom <points>] [--left <points>] [--right <points>]
swm space gap [--space <space-index>] [<points>]
```

Run a setting without a value to print the Space's current value, in the form the command accepts:

```sh
swm space gap                # 8
swm space padding --space 2  # --top 8 --bottom 8 --left 8 --right 8
```

A plain number sets a value, and a signed number adjusts it: `swm space gap 6` sets the gap, and `swm space gap +2` or `swm space gap -2` changes it. Padding sides left out keep their current value. Master and split ratios must be between `0.1` and `0.9`; adjustments, padding, and gaps are clamped to valid values. Space settings apply to every display showing that space.

## Layouts

The layouts are:

- `float`: do not arrange windows automatically.
- `master`: place one window at the selected edge and the others in a stack.
- `monocle`: overlap every tiled window across the available bounds.
- `dwindle`: recursively split the available bounds around the focused window.

In a dwindle layout, new windows split the focused tiled window and removing a window collapses its sibling branch. Splits normally follow the longest available edge. `swm space preserve-split on` keeps each split's direction once chosen, and is required by `swm window toggle-split`. Turning it off returns every split to following the longest edge.

A dwindle split ratio is the share of a region given to its left or upper side. `swm space split-ratio 0.6` sets that ratio for new splits on the Space and rebalances every existing split to it; a signed change such as `+0.05` adjusts the Space's ratio and rebalances the same way. Use `swm window split-ratio` to change one split afterwards.

The split ratio remains the requested ratio. If an application repeatedly settles larger than requested, dwindle temporarily records the refused dimensions and chooses the closest feasible point-aligned allocation. Effective allocations can therefore differ from the requested ratio. Dynamic splits still follow each region's longest edge; preserved directions remain fixed.

Recovery waits for the whole Space/display batch to settle, then allows at most two corrective layout passes. If recovery fails, SWM attempts one restoration of the last fully verified arrangement only when its window membership, display bounds, and padding/gap settings still match. Otherwise it logs an unsatisfied layout and stops retrying that arrangement. It does not float windows or enable split preservation. A bounded geometry search can also report an unsatisfied layout when it exhausts its search budget.

Observed constraints last only for the current window lifetime. Explicit layout adjustments and completed pointer resize interactions permit a fresh attempt, allowing applications to accept smaller sizes later. Background reflows reuse observations and do not repeatedly probe a known refusal. Restoration itself can fail if an application has changed its size requirements; an arrangement that cannot physically fit is not guaranteed to recover.

Each physical display has an independent tiling layout, including when macOS's **Displays have separate Spaces** setting is disabled. Moving a tiled window between displays moves it into the destination layout. Manually moving or resizing a tiled window causes it to snap back into place.

Use [global defaults](configuration.md#global-defaults) to set the default layout, padding, and gaps. [Window tiling commands](windows.md#control-tiling) control individual windows within a layout.
