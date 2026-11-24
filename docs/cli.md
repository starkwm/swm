# Command line

[Documentation index](index.md)

## Start the daemon

Run `swm` without a subcommand to start the daemon. `swm start` is the explicit equivalent:

```sh
swm [start] [--config <path>] [--log-level <level>]
```

Daemon startup options, accepted by `swm` and `swm start`:

```text
-c, --config <path>        Use a different startup configuration file
    --log-level <level>    debug, info, warn, or error (default: info)
```

See [configuration files](configuration.md#configuration-file) for startup scripts and custom paths.

## Reload the configuration

Run the configuration file again without restarting the daemon:

```sh
swm reload [--config <path>]
```

Without `--config`, `reload` runs `~/.config/swm/swmrc`; pass the same path the daemon was started with if it uses another file.

A reload is all-or-nothing for rules:

- While the file runs, the rules it adds, removes, clears, or lists belong to the reload, which starts with none. The current rules stay in effect until the file finishes.
- If the file exits successfully, its rules replace the current ones in one step. A window whose rule placement is unchanged is not placed again, so windows you moved stay where they are.
- If the file exits unsuccessfully, `reload` exits with status 1. The daemon keeps the current rules and restores settings to their values at the start of the reload. It does the same if `swm reload` stops before the file finishes.

Settings commands such as `swm config gap 8` take effect as the file runs. Settings the file no longer sets keep their current values. A reload cannot undo window, Space, or display commands the file ran, or programs it started. Restoring a layout setting reflows the affected layouts. Restoring `split-ratio` rebalances every split to the restored ratio, and turning `preserve-split` back on cannot recover split directions the file cleared.

A failed command does not cancel the reload by itself; the file's exit status decides. Add `set -e` to a shell script to stop, and roll back, at the first failed command.

Only one reload runs at a time. A second `swm reload` fails until the first finishes. Commands sent from outside the file, such as hotkeys, still apply immediately. A successful reload replaces any rule added by a hotkey while the file ran. A failed reload undoes even a hotkey's change to a setting the file never touched. Programs the file starts inherit its `SWM_RELOAD_TOKEN` environment variable, so their commands join the reload while it runs and apply immediately once it finishes.

## Send commands

Send commands to the running daemon through command-specific subcommands:

```sh
swm <domain> <command> [arguments]
```

The available domains are `window`, `space`, `display`, `config`, `rule`, and `query`. Commands that change state print nothing when they succeed; queries and commands that report a value, such as `swm config master-placement --space current next`, print it to standard output. Errors go to standard error with an `Error:` prefix. Invalid arguments exit with status 64, and failures reported by the daemon exit with status 1. Run `swm --help`, `swm <domain> --help`, or `swm help <domain> <command>` for progressively more specific help.

The daemon cancels a command that runs for more than 4.5 seconds and reports `request timed out and was cancelled`. Cancellation stops the command at its next wait, so changes it already made, such as a submitted Space switch, remain.

Top-level options:

```text
-h, --help                 Show help
-v, --version              Show the version
```

Command references cover [queries](query.md), [windows](windows.md), [spaces](spaces.md), [displays](displays.md), [global defaults](configuration.md#global-defaults), and [rules](rules.md).

## Shell completions

`swm` can generate completion scripts for Bash, Zsh, and Fish. Homebrew installations include them automatically.

For a manual installation, generate the script into a directory loaded by your shell:

```sh
# Bash: source this file from ~/.bashrc if it is not loaded automatically.
mkdir -p ~/.local/share/bash-completion/completions
swm --generate-completion-script bash > ~/.local/share/bash-completion/completions/swm

# Zsh: add ~/.zfunc to fpath before running compinit in ~/.zshrc.
mkdir -p ~/.zfunc
swm --generate-completion-script zsh > ~/.zfunc/_swm

# Fish
mkdir -p ~/.config/fish/completions
swm --generate-completion-script fish > ~/.config/fish/completions/swm.fish
```

Restart the shell after installing a completion script.
