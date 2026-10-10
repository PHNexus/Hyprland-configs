# HyprQuickPaper: scroll and hover debugging notes

This note records two bugs observed in a customized HyprQuickPaper/Quickshell setup and the fixes that were tested there. The log files in `logs/` are short, curated excerpts from the debugging session, not complete runtime logs.

## 1. Horizontal scrolling used the wrong lower boundary

The `ListView` reported a nonzero `originX`, while scroll clamping and the special case for returning to the first wallpaper assumed the minimum position was `0`. This allowed `contentX` and the wheel target to go below the list's actual origin.

The fix in `shell.qml` uses `originX` as the lower bound, computes the upper bound as `originX + max(0, contentWidth - width)`, and returns to `originX` for the first wallpaper. See [`logs/scroll-origin-before-fix.log`](logs/scroll-origin-before-fix.log).

## 2. Hover animation became static or repeatedly restarted during wheel scrolling

The investigation exposed more than one interaction problem:

- Pointer position changes were observed while `HoverHandler.active` was false. Discarding all such changes could leave `mouseEnabled` false and `keyboardMode` true even after moving the mouse.
- The pointer could already be inside a delegate when input mode changed, so relying only on `MouseArea.onEntered` was insufficient. The code now re-checks the hovered delegate after real pointer movement.
- During wheel scrolling, the list moves beneath a stationary cursor. Treating every resulting `MouseArea.onEntered` event as a new physical hover changed `selectedIndex` repeatedly and restarted the 500 ms size transition. The final fix ignores those wheel-induced enter transitions, cancels pending hover timers at wheel start, and uses actual pointer movement to re-evaluate hover.

See [`logs/hover-input-before-fix.log`](logs/hover-input-before-fix.log) and [`logs/wheel-hover-before-fix.log`](logs/wheel-hover-before-fix.log).

## Animation settings preserved

- Keyboard scroll: 1000 ms
- Wheel scroll: 750 ms
- Wallpaper width/height and border opacity: 500 ms

The fixes above were tested interactively in the author's customized setup. They should not be assumed to fix every version or configuration without testing.

## Capture a new diagnostic log

Run this from a terminal while reproducing the issue:

```bash
quickshell log -p ~/.config/quickshell/hyprquickpaper --tail 100 --follow 2>&1 \
  | tee /tmp/hyprquickpaper-debug.log
```

Press `Ctrl+C` when finished, then extract the relevant lines:

```bash
grep -E 'QKP_TRACE|QKP_HOVER|QML Error|QQML' \
  /tmp/hyprquickpaper-debug.log | tail -n 160
```

`console.warn()` writes to Quickshell's log stream; it does not automatically save a log file inside this project. `tee` captures the live output to a file. If you publish a report, keep only the minimum useful excerpts and review them for personal paths or other private details before committing them.

## Log labels

- `QKP_TRACE`: scroll position, target, origin, selected index, animation states, and input-mode flags.
- `QKP_HOVER`: pointer movement and delegate-hover diagnostics (present in the diagnostic build used during the investigation).
