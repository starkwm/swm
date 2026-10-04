# Query state

[Documentation index](index.md)

Queries return JSON. Query all tracked objects of one type:

```sh
swm query displays
swm query spaces
swm query windows
swm query layouts
```

Add at most one selector to filter the result:

```sh
swm query windows --display 1
swm query windows --space 0
swm query windows --window 12345
```

Singular query commands accept an optional index or ID. Without one they return the focused object:

```sh
swm query display [display-index]
swm query space [space-index]
swm query window [window-id]
```

Display indexes are one-based and follow the physical display arrangement. Space indexes are zero-based. A filtered query returns one JSON object when the selector identifies the same type as the query; otherwise it returns an array of related objects.

Use the returned IDs and indexes to target [window commands](windows.md) and [space commands](spaces.md).

`query layouts` always returns an array with one entry per normal Space and physical display. It accepts the same `--space`, `--display`, and `--window` selectors. A window selector matches scrolling column membership, including minimized or floating columns.

Each entry includes `space-id`, `display-id`, `layout`, and `is-visible`. Scrolling entries also contain `viewport-offset` and ordered `columns`. Each column reports its window ID, fractional width, `is-omitted`, `is-parked`, and its latest logical `frame`. These frames describe the strip, rather than physical parking coordinates. `constraint`, when present, explains why swm could not calculate or place the scrolling layout.
