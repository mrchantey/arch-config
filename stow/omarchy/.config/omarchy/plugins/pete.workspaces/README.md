# pete.workspaces

Our clone of Omarchy's bar workspace widget, stowed into `~/.config/omarchy/plugins/` by the `omarchy` package. The stock widget only knows ids 1-10, so it lost its focused marker whenever focus sat on another monitor. This one treats each number as a group of synced workspaces (see the header of `stow/hypr/.config/hypr/workspaces.lua`) and switches through `hyprctl eval 'require("hypr.workspaces").show(N)'`, which keeps focus on the monitor you are on.

## Labels

Buttons keep their shortcut number and show the most recently focused Zed project's name across the group, updating on title changes and window moves without polling; other apps do not displace a Zed label. Without Zed, the most recently focused app supplies its desktop-entry name (Chrome is shortened to `Chrome`), with a cleaned-up window class as the fallback; empty groups keep just their number. The active group is colored and underlined, long names are shortened with the full name in a tooltip, and vertical bars show numbers with project tooltips.

A linked Git worktree reads the same as its main checkout, ie `~/me/worktrees/beet/misc/beet` shows `beet`, and that is accepted: Zed's title carries only the root's basename, and nothing outside Zed can reliably tell which project a window shows, since its session database keeps one row per path and has no mapping from its window IDs to Hyprland's. A task-based reporter was tried and dropped, it needed a manual trigger and cleared Zed's task rerun history.

## Files

- `Workspaces.qml`: the widget
- `Labels.js`: label logic, kept free of Quickshell so it can be tested
- `tests/tst_labels.qml`: regression tests for `Labels.js`

Run the tests from this directory with Qt 6's runner; the bare `/usr/bin/qmltestrunner` is Qt 5 and rejects the versionless imports:

```sh
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
```

Edits do not always hot-reload, Qt keeps the old component cached; `omarchy restart shell` picks them up.
