# GitSwitch

A slick little macOS app that lists every GitHub account you're logged into and
lets you switch the active one with a single click, from a window or the menu
bar. It is to `gh auth switch` what LocalPort is to `lsof`.

## Features

- Live list of every authenticated GitHub account (refreshes every few seconds)
- The active account is highlighted; one click switches to any other
- Host and token protocol shown per account; filter by login, host, or scope
- Menu bar (tray) icon shows the active login, with a quick dropdown to switch
- Auto-matches your global git commit identity (`user.name` / `user.email`) to
  the active account whenever it changes, pulling the email from the GitHub API
  (falling back to the `users.noreply.github.com` privacy address). Toggle it off
  with **Auto**, or force it any time with **Match now**
- Single-window, runs quietly in the menu bar
- Native SwiftUI, no dependencies

## How it works

It shells out to the GitHub CLI:

- `gh auth status` to list accounts and detect the active one
- `gh auth switch --hostname <host> --user <login>` to switch
- `gh api user` + `git config --global` to sync the commit identity

Because it calls the same `gh` binary that stored your credentials, the macOS
keychain access just works. A GUI app launched from Finder has a minimal `PATH`,
so GitSwitch resolves `gh` and `git` from the usual locations (and falls back to
a login shell's `command -v`).

> The active GitHub account governs which token git uses to **push/pull** over
> HTTPS. Your **commit author** identity (`user.name` / `user.email`) is separate
> — that is what "Match to active" updates.

## Requirements

- macOS 14+ and a Swift 6 toolchain (Xcode 16+)
- [GitHub CLI](https://cli.github.com) (`brew install gh`) with at least one
  account logged in (`gh auth login`)

## Build

```bash
# Run straight from source
swift run

# Build GitSwitch.app (with icon) into the project folder
./make-app.sh

# Build and install into /Applications
./make-app.sh --install
```

## Project layout

```
Sources/GitSwitch/
  GitSwitchApp.swift   App entry, window + menu bar scenes
  GitAccount.swift     One authenticated account
  GitRunner.swift      Shells out to gh/git; parses `gh auth status`
  AccountStore.swift   Observable model; polling, switching, identity sync
  ContentView.swift    Main window
  MenuBarView.swift    Tray dropdown
  Theme.swift          Colors and the per-login tint
make-icon.swift        Generates the app icon
make-app.sh            Packages (and installs) GitSwitch.app
```

## License

MIT, see [LICENSE](LICENSE).
