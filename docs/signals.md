# Run commands on events

[Documentation index](index.md)

Signals run shell actions after matching runtime events:

```sh
swm signal add event=window-focused action='echo "$SWM_WINDOW_ID"'
swm signal add event=window-created app='^Safari$' label=safari-created action='echo "$SWM_WINDOW_ID"'
swm signal list
swm signal remove <index|label>
```

`add` requires `event` and `action`. It also accepts:

- `label=<text>`: unique name used by `remove`.
- `app=<regex>` and `title=<regex>`: require a regular-expression match.
- `app!=<regex>` and `title!=<regex>`: require the value not to match.
- `active=yes|no`: filter application and window events by active or focused state.

## Events

Supported events:

- `application-launched`
- `application-terminated`
- `application-front-switched`
- `window-created`
- `window-destroyed`
- `window-focused`
- `window-moved`
- `window-resized`
- `window-minimized`
- `window-deminimized`
- `space-changed`
- `display-changed`
- `display-added`
- `display-removed`
- `display-moved`
- `display-resized`

## Actions and environment

Actions run asynchronously through `/usr/bin/env sh -c`. Depending on the event, the action receives these environment variables:

- `SWM_PROCESS_ID`
- `SWM_WINDOW_ID`
- `SWM_SPACE_ID`
- `SWM_SPACE_INDEX`
- `SWM_RECENT_SPACE_ID`
- `SWM_RECENT_SPACE_INDEX`
- `SWM_DISPLAY_ID`
- `SWM_RECENT_DISPLAY_ID`
- `SWM_EVENT_DISPLAY_ID`

Signal registrations exist only for the current daemon run, so put persistent registrations in [`swmrc`](configuration.md#configuration-file).
