# Query state

[Documentation index](index.md)

Queries return JSON. Query all tracked objects of one type:

```sh
swm query displays
swm query spaces
swm query windows
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
