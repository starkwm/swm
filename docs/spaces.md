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

The seven shared settings live under `config`. Omit `--space` to update all current Spaces and future defaults. Use `--space current` for the active Space, or `--space <space-index>` to select a Space by its positive one-based index from `swm query spaces`. Indexes follow the current Space ordering and may change when Spaces are reordered:

```sh
swm config layout --space <current|space-index> [float|master|monocle|dwindle]
swm config master-ratio --space <current|space-index> [<ratio>]
swm config master-placement --space <current|space-index> [left|right|top|bottom|next|prev]
swm config split-ratio --space <current|space-index> [<ratio>]
swm config preserve-split --space <current|space-index> [on|off]
swm config padding --space <current|space-index> [<points>] [--top <points>] [--bottom <points>] [--left <points>] [--right <points>]
swm config gap --space <current|space-index> [<points>]
```

Run a setting without a value to print the Space's current value, in the form the command accepts:

```sh
swm config gap --space current  # 8
swm config padding --space 2    # --top 8 --bottom 8 --left 8 --right 8
```

A plain number sets a value and a signed number adjusts it. `swm config gap --space current 6` sets the gap; `swm config gap --space current +2` adds 2 and `swm config gap --space current -2` subtracts 2.

`swm config padding --space current +2` adds 2 to each side's current padding. Side flags take precedence over the positional value, in either argument order. For example, `swm config padding --space current +2 --top 8` sets the top to 8 and adds 2 to the other sides. With side flags alone, omitted sides keep their current value.

Master and split ratios must be between `0.1` and `0.9`. swm clamps ratio adjustments to that range and padding and gaps to zero or above. Space settings apply to every display showing that space.

## Layouts

The layouts are:

- `float`: do not arrange windows automatically.
- `master`: place one window at the selected edge and the others in a stack.
- `monocle`: overlap every tiled window across the available bounds.
- `dwindle`: recursively split the available bounds around the focused window.

In a dwindle layout, new windows split the focused tiled window and removing a window collapses its sibling branch. Splits normally follow the longest available edge. `swm config preserve-split --space current on` keeps each split's direction once chosen, and is required by `swm window toggle-split`. Turning it off returns every split to following the longest edge.

A dwindle split ratio is the share of a region given to its left or upper side. `swm config split-ratio --space current 0.6` sets that ratio for new splits on the Space and rebalances every existing split to it; a signed change such as `+0.05` adjusts the Space's ratio and rebalances the same way. Use `swm window split-ratio` to change one split afterwards.

Dwindle keeps the requested split ratios and directions even when an application's minimum size exceeds its tile. SWM still requests the planned frame, but the application may remain larger, overlap neighboring tiles, or extend beyond the display. Other tiles keep their planned positions.

Background reflows do not repeatedly retry an arrangement that an application refused. Explicit layout adjustments and completed pointer resize interactions allow a fresh attempt.

Each physical display has an independent tiling layout, including when macOS's **Displays have separate Spaces** setting is disabled. Moving a tiled window between displays moves it into the destination layout. Manually moving or resizing a tiled window causes it to snap back into place.

Use [global defaults](configuration.md#global-defaults) to set the default layout, padding, and gaps. [Window tiling commands](windows.md#control-tiling) control individual windows within a layout.
