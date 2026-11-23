# Query state

[Documentation index](index.md)

Queries return JSON, indented when written to a terminal and on one line when piped to another command. Query all tracked objects of one type:

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

Display and Space indexes are one-based. Display indexes follow the physical display arrangement.

| Query | No selector | `--display` | `--space` | `--window` |
| --- | --- | --- | --- | --- |
| `swm query displays` | Array | Object | Object | Object |
| `swm query spaces` | Array | Array | Object | Object |
| `swm query windows` | Array | Array | Array | Object |

When nothing matches, an object query returns `null` and an array query returns `[]`.

Window `has-focus` compares each ID with the focused window of the frontmost application. It is `null` when focus cannot be determined; a singular window query then returns `null`.

Window `tiling` reports how the last layout update treated the window:

- `tiled`: the window is part of a tiling layout.
- `floating`: swm leaves the window's frame alone.
- `excluded`: swm does not lay out the window.
- `pending`: swm is waiting for Accessibility or Space information.
- `null`: swm has not yet laid out the window.

`tiling-reason` explains a `floating` or `excluded` state and is otherwise `null`:

| Reason | Meaning |
| --- | --- |
| `manual` | Floated with `swm window float`. |
| `rule` | A rule sets `manage=off`. |
| `float-layout` | The window's Space uses the `float` layout. |
| `multiple-spaces` | The window is on more than one Space. |
| `dialog` | The window is modal, or has a close button but no enabled full-screen button. |
| `not-resizable` | The application does not allow resizing the window. |
| `not-movable` | The application does not allow moving the window. |
| `unsupported-subrole` | The window is not a standard window, such as a panel or sheet. |
| `native-fullscreen` | The window is in macOS full screen. |
| `minimized` | The window is minimized. |

Use the returned IDs and indexes to target [window commands](windows.md) and [space commands](spaces.md).
