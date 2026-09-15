# Window rules

[Documentation index](index.md)

Add rules to `~/.config/swm/swmrc` to keep selected windows floating or place them
on a display. For example, leave Settings and Finder out of tiling layouts:

```sh
swm rule add label=settings bundle-id=com.apple.systempreferences manage=off
swm rule add label=finder bundle-id=com.apple.finder manage=off
```

Rules last until the daemon stops. Adding or removing a rule updates existing
windows as well as windows opened later.

## Commands

```sh
swm rule add label=finder app='^Finder$' manage=off
swm rule list
swm rule remove finder
swm rule remove 1
```

`list` returns a JSON array. Each entry has a one-based `index` and a `rule` object
with the registered properties. Indexes change after removal. Use a unique,
non-integer `label` to remove a rule by name.

`add` requires at least one action:

- `manage=on|off` allows or skips automatic tiling.
- `display=<index|uuid>` moves the window to a display without following focus.
  Indexes start at 1 and use the same order as `swm window display`. Use a UUID from
  `swm query displays` to identify a monitor regardless of its index. Rules accept
  neither `next` nor `prev`.
- `grid=<columns>:<rows>:<x>:<y>:<width>:<height>` places a floating window within
  the display's visible bounds. It uses the destination Space's padding and gaps,
  with the same coordinate clamping as `swm window grid`.

## Match windows

A rule can use these filters:

- `bundle-id=<identifier>` matches an exact, case-sensitive application identifier.
- `app=<regex>` matches the application name, which can vary with the system language.
- `title=<regex>` matches the window title.
- `app!=<regex>` or `title!=<regex>` requires the text not to match.

All filters must match. If a window's value is missing, that filter fails even
when inverted. A rule without filters matches every window.

Regexes use Foundation's ICU syntax. They are case-sensitive by default and match
substrings unless anchored with `^` and `$`. Quote them in shell scripts. swm
rejects invalid regexes, unknown properties, empty values, and duplicate properties
without adding the rule.

The last matching value for each action wins. A rule that only sets `grid` leaves
an earlier `manage` or `display` value in place. Put broad rules before exceptions:

```sh
swm rule add label=finder app='^Finder$' manage=off
swm rule add label=finder-projects app='^Finder$' title='^Projects$' manage=on
```

## Tiling

`manage=off` leaves a window out of automatic tiling and tiling cycles. Queries,
focus, and direct window commands still work. `manage=on` allows tiling if the
window supports it. It cannot force fixed-size, nonstandard, or native-fullscreen
windows into a layout.

swm checks rules before a new window's first layout, when rules change, and during
later window updates. Title changes trigger a check when the app supports title
notifications. Removing a management rule restores the earlier matching value or
the normal default.

`swm window layout float`, `tile`, and `toggle` override management rules for that
window until it closes or the daemon restarts. Rule edits preserve those choices.
`toggle` reverses the window's float/tile setting.
Rules do not change the Space's layout. A Space using `float` keeps its usual
floating-window commands and cycling.

## Display and grid placement

```sh
# Place Finder in the right half of display 2.
swm rule add label=finder app='^Finder$' manage=off display=2 grid=2:1:1:0:1:1
```

swm selects the display before calculating the grid. Without a grid, it preserves
the window's relative position and fits its size to the destination. Tiled windows
join the destination layout.

Grid placement requires a resizable, floating window. Use `manage=off`, a manual
float command, or a destination Space with the `float` layout. A grid waits until
the window meets those conditions.

Each placement action runs when it first matches or its value changes. Later
manual moves and resizes leave that action unchanged, so it does not run again.
A new display value also reapplies the matching grid on that display. Changing
only the grid does not repeat a completed display move.

Placement waits for minimized windows, windows on inactive or fullscreen Spaces,
and unavailable destination displays. swm tries again during later window or
display updates. It does not switch Spaces to place a window or apply a grid on a
substitute monitor.

Removing a placement rule leaves the current frame and display in place unless
an earlier matching value takes over. swm forgets completed actions when a window
closes or stops matching them. If an Accessibility move or resize fails, swm logs
the failure and stops retrying that action. Remove and add the rule to retry.
