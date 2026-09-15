# Window rules

[Documentation index](index.md)

Rules control automatic tiling, display selection, and grid placement. Add these
commands to `~/.config/swm/swmrc` to leave Settings and Finder floating:

```sh
swm rule add label=settings bundle-id=com.apple.systempreferences manage=off
swm rule add label=finder bundle-id=com.apple.finder manage=off
```

Registrations last for the current daemon run. Rules also apply immediately to
existing windows when added or removed.

## Commands

```sh
swm rule add label=finder app='^Finder$' manage=off
swm rule list
swm rule remove finder
swm rule remove 1
```

`list` returns a JSON array with a one-based `index` and a `rule` object containing
the registered properties. Indexes change after removal. Labels must be unique
and cannot be integers.

`add` requires at least one action:

- `manage=on|off`: choose automatic tiling participation.
- `display=<index|uuid>`: move to the display's visible normal Space without following focus.
  Indexes are one-based, using the same arrangement as `swm window display`.
  Use a UUID from `swm query displays` for a stable monitor identity. Relative
  targets such as `next` and `prev` are not accepted in rules.
- `grid=<columns>:<rows>:<x>:<y>:<width>:<height>`: place a floating window within
  the display's visible bounds, respecting the destination Space's padding and gaps.
  This uses the same parsing and clamping as `swm window grid`.

Optional matching and naming properties are:

- `label=<text>`: a name for removing the rule.
- `bundle-id=<identifier>`: exact, case-sensitive application bundle identifier.
- `app=<regex>`: application name, which may depend on the system language.
- `title=<regex>`: window title.
- `app!=<regex>` or `title!=<regex>`: invert a regex filter.

All filters in a rule must match. A missing value fails its filter, including an
inverted filter. Regexes use Foundation's ICU syntax, are case-sensitive by
default, and match substrings unless anchored with `^` and `$`. Quote regexes in
shell scripts. Invalid regexes, unknown properties, empty values, and duplicate
properties are rejected without registering a rule. A rule without filters
matches every window.

## Precedence and window behavior

The last matching value for each property wins independently. A rule that only
sets `grid` preserves an earlier matching `manage` or `display` value. Put broad
rules before exceptions:

```sh
swm rule add label=finder app='^Finder$' manage=off
swm rule add label=finder-projects app='^Finder$' title='^Projects$' manage=on
```

`manage=off` removes the window from automatic layout geometry and tiling cycles.
The window remains available to queries, focus, and direct window commands.
`manage=on` allows normal tiling eligibility checks; it does not force fixed-size,
nonstandard, or native-fullscreen windows into a layout.

Rules are evaluated during window reconciliation, including discovery, title
changes, and rule edits. Removing a rule restores the remaining matching rule or
the normal default. New windows are evaluated before their first layout.

Explicit `swm window layout float`, `tile`, and `toggle` commands override rules
for that window until it closes or the daemon restarts. `toggle` uses the window's
current effective participation. Rule edits preserve these manual choices.

Floating rules do not change the Space's layout. In a Space configured with the
`float` layout, ordinary floating-window commands and cycling still apply.

## Display and grid placement

```sh
# Keep Finder floating on display 2, occupying its right half.
swm rule add label=finder app='^Finder$' manage=off display=2 grid=2:1:1:0:1:1
```

Display selection happens before grid placement. Display-only rules preserve the
window's relative position and fit its size to the destination, like the window
command. A tiled window joins the destination layout. Grid rules do not make a
window float: use `manage=off`, a manual float override, or a destination Space
with the `float` layout. Grid placement waits while the window is tiled or cannot
resize.

Each placement property applies once when it first matches or its effective value
changes. Moving or resizing a window manually does not replay an unchanged rule.
Changing the display action also reapplies the matching grid on the new display;
changing only the grid leaves any completed display action alone.

Rules apply to existing windows when registered. Minimized windows, windows on
inactive or fullscreen Spaces, and unavailable destination displays defer
placement until a later reconciliation has the required facts. An unavailable
display does not apply the grid on the wrong monitor. Placement does not activate
a Space or force unsupported windows to move.

Removing a placement rule does not restore the previous frame or display. If an
earlier matching value remains, that value takes effect. Placement state clears
when the window closes or stops matching. Failed Accessibility mutations are
logged and are not repeatedly retried; removing and adding the rule retries it.
