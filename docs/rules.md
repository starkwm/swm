# Window rules

[Documentation index](index.md)

Add rules to `~/.config/swm/swmrc` to keep selected windows floating or place them
on a display or Space. For example, leave Settings and Finder out of tiling layouts:

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
swm rule clear
```

`list` returns a JSON array. Each entry has a one-based `index` and a `rule` object
with the registered properties. Indexes change after removal. Use a unique,
non-integer `label` to remove a rule by name.

`add` requires at least one action:

- `manage=on|off` allows or skips automatic tiling.
- `display=<index|uuid>` moves the window to a display without following focus.
  Indexes start at 1 and use the same order as `swm window move --display`. Use a UUID from
  `swm query displays` to identify a monitor regardless of its index. Rules accept
  neither `next` nor `prev`.
- `space=<index>` moves the window to a Space without switching to it. Indexes
  start at 1 and match `swm query spaces`. A rule sets `display` or `space`, not both.
- `grid=<columns>:<rows>:<x>:<y>:<width>:<height>` places a floating window within
  the display's visible bounds. It uses the destination Space's padding and gaps,
  with the same cell sizes, gaps, and coordinate clamping as `swm window grid`.

## Match windows

A rule can use these filters:

- `bundle-id=<identifier>` matches an exact, case-sensitive application identifier.
- `app=<regex>` matches the application name, which can vary with the system language.
- `title=<regex>` matches the window title.
- `bundle-id!=<identifier>`, `app!=<regex>`, or `title!=<regex>` requires the value not to match.

All filters must match. If a window's value is missing, that filter fails even
when inverted. A rule without filters matches every window.

Regexes use Foundation's ICU syntax. They are case-sensitive by default and match
substrings unless anchored with `^` and `$`. Quote them in shell scripts. swm
rejects invalid regexes, unknown properties, empty values, and duplicate properties
without adding the rule.

The last matching value for each action wins. A rule that only sets `grid` leaves
an earlier `manage` or `display` value in place. `display` and `space` both choose
a destination, so the later of the two replaces the other. Put broad rules before exceptions:

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

`swm window float on` floats a window and `swm window float off` returns it to
tiling. `swm window float toggle` switches between the two. These choices override
management rules until the window closes or the daemon restarts. Editing rules
does not reset them.
Rules do not change the Space's layout. A Space using `float` keeps its usual
floating-window commands and cycling.

## Display, Space, and grid placement

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

```sh
# Open Slack on the third Space.
swm rule add label=slack app='^Slack$' space=3
```

A Space move uses the same bridge as `swm window move --space`, so it has the same
limits: only windows on one normal desktop Space can move, and the destination
must be a normal desktop Space. A Space on another display fits the window to
that display. The window stays out of its source layout while it moves, then
joins the destination layout. A grid applies after the move, once the
destination Space is visible. Space indexes follow the current Space order, so
a rule targets a different Space after Spaces are reordered.

Placement waits for minimized windows, windows on inactive or fullscreen Spaces,
and unavailable destination displays or Spaces, including an index that names a
fullscreen Space. swm tries again during later window or
display updates. It does not switch Spaces to place a window or apply a grid on a
substitute monitor.

Removing a placement rule leaves the current frame and display in place unless
an earlier matching value takes over. swm forgets completed actions when a window
closes or stops matching them. If an Accessibility move or resize, or a Space
move, fails, swm logs the failure and stops retrying that action. Remove and add the rule to retry.
