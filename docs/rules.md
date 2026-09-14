# Window rules

[Documentation index](index.md)

Rules choose whether matching windows participate in automatic tiling. Add these
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

`add` requires `manage=on|off`. Optional properties are:

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

The last matching rule wins. Put broad rules before exceptions:

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
