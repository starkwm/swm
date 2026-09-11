# Keyboard shortcuts

[Documentation index](index.md)

`swm` does not bind keys. Use a hotkey daemon such as [skbd](https://github.com/starkwm/skbd) to invoke its commands:

```text
hyper + h: swm window grid 2:1:0:0:1:1
hyper + l: swm window grid 2:1:1:0:1:1
hyper + f: swm window grid 1:1:0:0:1:1
hyper + r: swm window focus --window recent
```

See [window commands](windows.md) for movement, focus, and tiling commands, and [space commands](spaces.md) for layouts and spacing.
