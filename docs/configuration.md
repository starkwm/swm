# Configuration

[Documentation index](index.md)

## Configuration file

At startup, the daemon executes `~/.config/swm/swmrc` if it exists. Use `--config <path>` to select another file; an explicitly selected file must exist. `swm` makes the file owner-executable when needed and stops if it exits unsuccessfully.

The file can be any executable script. A shell script is the simplest option:

```sh
#!/bin/sh

swm config layout dwindle
swm config focus-follows-mouse autofocus
swm config animation-duration 0.18
swm config window-gap 8
swm config top-padding 8
swm config bottom-padding 8
swm config left-padding 8
swm config right-padding 8
```

## Global defaults

Config commands change settings in the running daemon. Layout, padding, and gap settings also apply to spaces discovered later:

```sh
swm config layout <float|master|monocle|dwindle>
swm config focus-follows-mouse <off|autofocus|autoraise>
swm config master-ratio <ratio>
swm config master-placement <left|right|top|bottom>
swm config preserve-split <on|off>
swm config animation-duration <seconds>
swm config animation-easing <linear|ease-out-quad|ease-out-cubic|ease-out-circ|ease-in-out-quad>
swm config window-gap <points>
swm config top-padding <points>
swm config bottom-padding <points>
swm config left-padding <points>
swm config right-padding <points>
```

Built-in defaults are floating layout, focus-follows-mouse off, `0.5` master ratio, master on the left, split preservation off, animation disabled, and zero padding and gaps. Negative padding or gap values are clamped to zero.

## Window animation

Window animation is disabled by default. Run
`swm config animation-duration 0.18` to animate swaps, automatic layout reflows, and `move`, `resize`, and `grid` commands,
or set it to `0` to finish active animations and return to instant movement.
The accepted range is 0 through 1 second. macOS Reduce Motion overrides this setting.
Repeated relative moves and resizes accumulate against the pending destination.
Display transfers remain instant. With animation enabled, geometry commands return
once the movement is queued.

Use `swm config animation-easing ease-out-circ` for a circular ease-out curve like
yabai's default. Available curves are `linear`, `ease-out-quad` (the default),
`ease-out-cubic`, `ease-out-circ`, and `ease-in-out-quad`. Changes apply to newly
started or retargeted animations; active animations retain their curve.

Each active display schedules animation updates at up to 60 Hz. Without a display,
swm uses a 60 Hz timer. Each update calculates the window's position and size for the
next display frame.

Animation reads and writes use Accessibility, one call at a time per app.
A slow app does not block animation updates in other apps. New pending frames replace
older ones, and swm checks the final position and size even after display updates stop.

Add the commands to `swmrc` to apply them at startup. Animation smoothness depends on
the app. Moving a window to another display cancels its animation.

When you drag or resize a window, swm stops sending animation updates to it until you
release the mouse, then recalculates the layout. Clicking without dragging leaves the
animation running. Geometry commands return an error during a drag. Placement rules
wait until you release the mouse.

An Accessibility call already in progress can finish after swm cancels an animation.
swm discards queued updates and ignores results from the cancelled animation.
Synchronous geometry commands wait for calls in progress to finish before moving or
resizing the window.

Use [window rules](rules.md) to keep selected applications floating or place their windows.

See [space commands](spaces.md) for per-space settings, [signals](signals.md) for actions that run on events, and [keyboard shortcuts](keyboard-shortcuts.md) for hotkey bindings.
