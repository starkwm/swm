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
swm query windows --space 1
swm query windows --window 12345
```

Singular query commands accept an optional index or ID. Without one they return the focused object:

```sh
swm query display [display-index]
swm query space [space-index]
swm query window [window-id]
```

Display and Space indexes are one-based. Display indexes follow the physical display arrangement. A filtered query returns one JSON object when the selector identifies the same type as the query; otherwise it returns an array of related objects.

Window `has-focus` compares each ID with the focused window of the frontmost application. It is `null` when focus cannot be determined; a singular window query then returns `null`.

Use the returned IDs and indexes to target [window commands](windows.md) and [space commands](spaces.md).
