# Omawrite

A dead-simple Markdown writing app built with Qt Quick and C++ that automatically follows system dark/light mode.

<img width="2948" height="3227" alt="screenshot-2026-06-23_15-24-08" src="https://github.com/user-attachments/assets/4e930c0d-edda-4046-b444-a59eff523329" />
<img width="2948" height="3227" alt="screenshot-2026-06-23_15-23-23" src="https://github.com/user-attachments/assets/8ced7c26-961b-4ded-b263-84403001a951" />

## Building

Omawrite targets macOS on Apple Silicon (arm64 only; no Intel/universal-binary support).

**Dependencies:**

```sh
xcode-select --install   # Xcode Command Line Tools (compiler, macOS SDK)
brew install qt          # Qt 6 (qmake, QtQuick, QtWidgets, QtPrintSupport, ...)
```

Homebrew's Qt isn't put on `PATH` by default. `bin/build` looks for `qmake6` first, which
resolves once you either run `brew link --force qt` or otherwise put Homebrew's `bin`
directory on `PATH`.

**Build:**

```sh
bin/build
```

This runs `qmake` + `make` and produces an app bundle at `build/omawrite.app`. Run it with
`open build/omawrite.app`, or launch the embedded binary directly at
`build/omawrite.app/Contents/MacOS/omawrite`.

**Test:**

```sh
bin/test
```

Builds the test suite into `build-tests/` and runs it headlessly.

## Quick Look

`bin/build` also builds a Quick Look preview extension into
`build/omawrite.app/Contents/PlugIns/OmawriteQuickLook.appex`, so pressing space on a Markdown
file in Finder renders it — headings, bold, lists, links, code, tables — in Omawrite's colours
and typeface instead of showing raw text. The app bundle also registers itself as a handler for
`.md`, so Finder's "Open With" and the preview's open button land in the editor.

macOS only loads the extension from an app bundle it knows about, and it does not go looking in
build directories, so register the build once:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f build/omawrite.app
pluginkit -a build/omawrite.app/Contents/PlugIns/OmawriteQuickLook.appex
```

Installing the app in `/Applications` is the usual alternative. `pluginkit -m -p com.apple.quicklook.preview`
lists the registered preview extensions; `qlmanage -r` reloads them after a rebuild. Note that
`qlmanage -p` itself crashes on macOS 26 for every third-party preview extension, Apple's own
included — test previews in Finder.

## Shortcuts

- `Cmd+S` saves. Unsaved documents use the native save panel.
- `Cmd+Shift+S` saves as.
- `Cmd+O` opens a Markdown file through the native open panel.
- `Cmd+P` opens the system print dialog.
- `Cmd+N` opens a new Omawrite window.
- `Cmd+Z`, `Cmd+Shift+Z`, and `Cmd+Y` handle undo and redo.
- `Cmd+Ctrl+F` toggles fullscreen.
- `Cmd+F` searches the document. Use `Enter` or `Cmd+G` for the next match and `Shift+Enter` for the previous match.
- `Cmd+H` opens find and replace.
- `Cmd+B`, `Cmd+I`, and `Cmd+K` insert bold, italic, and link Markdown.
- `Cmd+?` shows the keyboard shortcut reference.

Unsaved drafts are recovered after an abnormal exit. Omawrite also watches open files
and warns before an external change can replace local work.

The iA Writer Mono font is bundled under the SIL Open Font License 1.1; see
`fonts/OFL.txt`. The font is copyright Information Architects Inc. and based on
IBM Plex, copyright IBM Corp.
