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

## Send commands

Send commands to the running daemon through command-specific subcommands:

```sh
swm <domain> <command> [arguments]
```

The available domains are `query`, `window`, `space`, `config`, and `signal`. Commands print their result to standard output and return a non-zero exit status on failure. Run `swm --help`, `swm <domain> --help`, or `swm help <domain> <command>` for progressively more specific help.

Top-level options:

```text
-h, --help                 Show help
    --version              Show the version
```

Command references cover [queries](query.md), [windows](windows.md), [spaces](spaces.md), [global defaults](configuration.md#global-defaults), and [signals](signals.md).

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
