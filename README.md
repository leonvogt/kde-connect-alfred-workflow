<div align="center">

# KDE Connect Alfred Workflow

**Send text, files, URL's or the clipboard to paired KDE Connect devices.**

![icon](workflow/icon.png)
</div>

## Requirements

- macOS with [Alfred 5](https://www.alfredapp.com) and the Powerpack.
- [KDE Connect for macOS](https://kdeconnect.kde.org) installed in `/Applications`.
- A paired device on the same network.

## Install

Grab the latest `KDE-Connect.alfredworkflow` from the
[Releases](https://github.com/leonvogt/kde-connect-alfred-workflow/releases) page
and double-click it.

## Usage

**Universal Action**

1. Select any text, file, or URL in any macOS app (or copy something to the clipboard).
2. Invoke Alfred's Universal Action (default: `⌥⌘\`).
3. Pick **Send via KDE Connect**.
4. Single device → it sends immediately. Multiple devices → pick one.

**Keyword (clipboard)**

1. Copy text or a URL to the clipboard.
2. Open Alfred, type `kdec` (configurable — see below), press Enter.
3. Same device routing as above.

A notification confirms success or reports the failure.

## Configuration

Open the workflow in Alfred preferences and use the configuration button:

- **Keyword** — Alfred keyword for the clipboard action (default `kdec`).
- **kdeconnect-cli path** — absolute path to the CLI binary; the default
  points at the binary inside `KDE Connect.app`.

## Development

```sh
make link      # symlink workflow/ into Alfred for live editing
make unlink    # remove the symlink
make package   # build dist/KDE-Connect.alfredworkflow
make clean     # remove dist/
```

The scripts under `workflow/bin/` can be run by hand for debugging:

```sh
cd workflow
bash bin/dispatch.sh "https://example.com"
bash bin/dispatch_clipboard.sh
bash bin/choose_device.sh "/path/to/file.png"
KDECONNECT_CLI="/Applications/KDE Connect.app/Contents/MacOS/kdeconnect-cli" \
  payload="hi" payload_type=text device_id=<id> device_name=Pixel \
  bash bin/send.sh
```

To regenerate the icon from the app bundle:

```sh
sips -s format png "/Applications/KDE Connect.app/Contents/Resources/sc-apps-kdeconnect.icns" \
  --out workflow/icon.png -z 256 256
```

## Troubleshooting

Open the workflow in Alfred preferences and click the bug icon (top right of
the canvas). Alfred shows every step's stdout, stderr, and the variables that
were passed along — that's enough to diagnose nearly everything.

## License

MIT.
