# Manage displays

[Documentation index](index.md)

## Focus a display

```sh
swm display focus <target>
```

The target is one of:

| Target | Display |
| --- | --- |
| `<display-index>` | One-based index from `swm query displays` |
| `next`, `prev` | The next or previous display in arrangement order, wrapping at the ends |
| `first`, `last` | The first or last display in arrangement order |
| `recent` | The previously active display |
| `mouse` | The display under the mouse cursor |
| `left`, `right`, `up`, `down` | The nearest display in that direction |

Focusing a display focuses its frontmost visible window. When the display has no windows, swm moves the mouse cursor to the centre of the display and focuses its desktop. Focusing the display that is already focused does nothing.

The current display is the one holding the focused window, or the display of the active Space when no window is focused. Display focus works with System Integrity Protection enabled.
