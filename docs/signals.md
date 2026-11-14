# Run commands on events

[Documentation index](index.md)

Signals run shell actions after matching runtime events:

```sh
swm signal add event=window-focused action='echo "$SWM_WINDOW_ID"'
swm signal add event=window-created app='^Safari$' label=safari-created action='echo "$SWM_WINDOW_ID"'
swm signal list
swm signal remove <index|label>
swm signal clear
```

`add` requires `event` and `action`. It also accepts:

- `label=<text>`: unique non-integer name used by `remove`. Numeric selectors remove by one-based index. Rename any existing numeric labels before registering them.
- `app=<regex>` and `title=<regex>`: require a regular-expression match.
- `app!=<regex>` and `title!=<regex>`: require the value not to match.
- `active=on|off`: filter application and window events by active or focused state.

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

`SWM_SPACE_INDEX` and `SWM_RECENT_SPACE_INDEX` are one-based and match `swm query spaces`.

Up to four actions run at once, and up to 128 more wait in a queue. swm drops actions that arrive while the queue is full. Each action reads standard input from `/dev/null`. An action still running after 30 seconds is sent `SIGTERM`, along with every command it started, and `SIGKILL` two seconds later, so a hung action cannot hold a slot.

While a window is dragged it can emit many `window-moved` and `window-resized` events. A waiting action for the same registration, event, and window is replaced by the newest one, so it runs once with the latest values.

## Permissions

Signal actions run as child processes of the daemon. macOS checks their privacy permissions against the same app as the daemon, so every action, and every program an action starts, can use the Accessibility access granted to swm, or to the terminal or service manager that started it. An action can read and control the windows of any app, just as swm can.

Only register actions you trust. Keep `swmrc` and the scripts that actions run writable only by your user, because anyone who can change them can use this access.

Signal registrations exist only for the current daemon run, so put persistent registrations in [`swmrc`](configuration.md#configuration-file).
