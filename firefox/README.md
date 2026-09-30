# Firefox styles

Use Firefox's flat dark colors and remove the close-button border in collapsed vertical tabs.

- `chrome/classic-dark.css` restores Mozilla's [Firefox 140 dark palette](https://github.com/mozilla-firefox/firefox/blob/FIREFOX_140_0_RELEASE/browser/themes/addons/dark/manifest.json). It does not change tab sizes or spacing. Private windows and forced-color mode keep Firefox's own colors.
- `chrome/tab-close-button.css` removes the close-button outline in collapsed vertical tabs, except during keyboard focus. It changes no padding, position, or size. It also works in private windows and without the dark theme.

These are local `userChrome.css` files, not add-ons. They do not appear in Firefox's theme list. The color rules override other themes in normal windows while their import stays active.

## Install

Install [uv](https://docs.astral.sh/uv/getting-started/installation/), then run the repo's `install.sh`. It checks these Firefox homes:

- macOS: `~/Library/Application Support/Firefox/`
- Linux: `~/.mozilla/firefox/`

It reads `profiles.ini` and installs into existing profiles named `default-release`. It leaves Nightly and other named profiles alone. It does not create a Firefox profile. Run Firefox once first on a new machine, then re-run the installer. Snap and Flatpak paths need an explicit profile path.

To install only the Firefox files, run from the repo root:

```sh
uv run --no-project --python 3.13 firefox/install.py
```

For another profile, open `about:support` and find Profile Folder. Pass that path:

```sh
uv run --no-project --python 3.13 firefox/install.py --profile "/path/to/profile"
```

The installer:

1. Links the two CSS files from the repo into the profile's `chrome/` folder.
2. Adds missing imports to `chrome/userChrome.css`, before other rules and after any `@charset` declaration. It preserves existing imports and custom rules.
3. Appends `user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);` to `user.js` if needed. This enables custom CSS on startup. It does not edit `prefs.js`.

It saves replaced files beside their originals as `*.pre-dotfiles`, with a numeric suffix if needed. Backups and profile settings stay outside the public repo. Re-running an unchanged install creates no new backups.

For safety, the installer refuses a symlinked `chrome/` directory, `userChrome.css`, or `user.js`. Resolve that shared setup before running it for that profile. The two managed CSS files can be symlinks.

Quit Firefox with Cmd+Q on macOS, then open it again. Closing one window is not enough.

## Edit

Edit the files in `firefox/chrome/`, then restart Firefox. The profile links point to the repo, so there is no copy step. If you move the repo, re-run the installer to update the links.

The profile loader contains:

```css
@import url("classic-dark.css");
@import url("tab-close-button.css");
```

Tests and this guide are not part of the installed theme. The installer never imports browser history, credentials, or profile settings into the repo.

## Undo

Remove the matching import from the profile's `chrome/userChrome.css`, then restart Firefox. Remove either import independently. Re-running the dotfiles installer restores missing imports.

To restore files the installer replaced, use their adjacent `*.pre-dotfiles` backups. Remove only the two managed CSS symlinks, not the whole `chrome/` folder. If you turn custom styles off entirely, remove the enabling line from `user.js` and set `toolkit.legacyUserProfileCustomizations.stylesheets` to `false` in `about:config`. Keep other settings and styles you still use.

## Test

Run installer tests from the repo root. These use temporary profiles and need no browser:

```sh
uv run --no-project --python 3.13 -m unittest discover -s firefox/tests -p test_install.py
```

Run browser checks against Firefox 157 on macOS:

```sh
uv run --no-project --with marionette-driver --python 3.13 firefox/tests/test_theme.py
uv run --no-project --with marionette-driver --python 3.13 firefox/tests/test_close_button.py
```

The browser checks use fresh, temporary headless profiles. They test colors, page isolation, tab geometry, the close-button outline, and keyboard-focus handling. They do not open your normal profile. Set `FIREFOX_BINARY` to use another Firefox executable. Browser updates can change CSS names or geometry, so a later version may need new checks.
