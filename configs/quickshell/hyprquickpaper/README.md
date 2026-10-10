# HyprQuickPaper debug notes package

- `shell.qml`: the working hoverfix5 version, with a header pointing to the debugging notes.
- `docs/debugging/README.md`: root causes, fixes, preserved animation durations, and commands to capture new logs.
- `docs/debugging/logs/`: curated log excerpts from before the fixes.

Copy `shell.qml` into your Quickshell configuration only after backing up the version you currently use. The runtime logs are not loaded by QML; the references in the QML header point human readers to the accompanying documentation.
