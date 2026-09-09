# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Omawrite is a dead-simple Markdown writing app for macOS on Apple Silicon (arm64 only), built with
Qt Quick (QML) + C++. It follows the system dark/light mode automatically.

## Commands

- `bin/build` — builds via `qmake6`/`qmake` into `build/`, producing `build/omawrite.app`.
- `bin/test` — builds the Qt test suite into `build-tests/` and runs it with `QT_QPA_PLATFORM=offscreen`.

To run a single test, build once via `bin/test` (or manually via the `tests/tests.pro` project),
then invoke the resulting binary directly with a filter, e.g.:
`QT_QPA_PLATFORM=offscreen build-tests/tst_omawrite countsWords`

Requires Qt 6 (`brew install qt`) and the Xcode Command Line Tools.

## Architecture

The app is a single QML window (`src/Main.qml`) backed by one C++ `Backend` QObject
(`src/backend.{h,cpp}`) exposed to QML as the `backend` context property. There is no other
state management layer — QML binds directly to `Backend` properties/signals, and calls its
`Q_INVOKABLE` methods for actions (open/save/print/etc). `EditorMutations.js` holds small
pure-ish helpers for mutating the `TextEdit`'s text/selection/cursor from QML (used by
bold/italic/link insertion, find & replace) — kept separate from `Main.qml` because they need
careful cursor/selection math.

Key pieces in `Backend`:
- **Document lifecycle**: `open`/`save`/`saveAs` go through Qt's native file dialogs
  (`QtQuick.Dialogs`, backed by NSOpenPanel/NSSavePanel on macOS) — `openDialog()`/`saveAsDialog()`
  emit signals that QML's `Dialogs.FileDialog` responds to, and `open(url)`/`saveAs(url)` do the
  actual I/O.
- **Crash recovery**: `writeRecovery()`/`restoreRecovery()`/`clearRecovery()` persist unsaved text
  as JSON to a recovery file on a timer (`m_recoveryTimer`), keyed by an app-local lock
  (`QLockFile`) so recovery is offered on the next launch after an abnormal exit.
- **External change detection**: `m_fileWatcher` (`QFileSystemWatcher`) watches the currently open
  file; `m_lastKnownFileContents` is compared against disk to distinguish real external edits from
  our own saves, surfaced via `externalChangeDetected(deleted, locallyModified)` →
  `ExternalChangeDialog.qml`.
- **Theme integration**: dark/light mode comes from `SystemTheme` (`src/systemtheme.{h,cpp}`),
  which follows `QGuiApplication::styleHints()->colorScheme()` (Qt's native color-scheme signal,
  backed by `NSAppearance` on macOS). `Backend::applyDefaultTheme()` maps that to a fixed
  background/foreground/accent/selection palette. Colors flow into `MarkdownHighlighter` and QML
  via `themeBackground`/`themeForeground`/etc.
- **Markdown highlighting**: `MarkdownHighlighter` (`QSyntaxHighlighter` subclass) styles headings,
  bold/italic/code/quote/links and hides Markdown markers around the caret. `inlineMarkup()` is the
  single source of truth for inline spans (bold/italic/link) — both the highlighter (styling +
  hiding markers) and `Backend::hiddenRangesAt()` (used by QML to skip the caret over hidden
  markers) depend on it, so changes to inline markup parsing affect both.
- **Word count / typography**: word counting and typographic post-processing of pasted/typed text
  are scheduled on timers (`m_wordCountTimer`) rather than run synchronously on every keystroke, to
  avoid doing this work on large documents on every edit.

`tests/tst_omawrite.cpp` is a QtTest suite that links `backend.cpp`/`markdownhighlighter.cpp`
directly (no QML engine needed for most cases) and exercises the static/pure helpers
(`Backend::countWords`, `Backend::normalizedLinkUrl`, `Backend::suggestedFileName`,
`MarkdownHighlighter::inlineMarkup`) plus `Backend` behavior with an isolated `QTemporaryDir`
settings path (set up in `initTestCase`) so tests don't touch the real user config.

The iA Writer Mono font is bundled (`fonts/`, SIL OFL 1.1) and loaded in `main.cpp` via
`QFontDatabase::addApplicationFont` from the Qt resource system (`src/resources.qrc`); it's also
used as the app's interface font, scaled by `Backend::textScale` (currently always 1.0 — there's
no system-wide text-scale setting to follow on macOS, but the plumbing stays in case that changes).
