import "../"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: page

    property string sourceText: ""
    property string statusMessage: "Loading autostart entries..."
    property var entries: []
    property string searchText: ""
    property bool fileReady: false
    property bool saveInProgress: false
    property bool queuedSave: false
    property string queuedSaveText: ""
    property string queuedSaveMessage: ""
    property var editingEntry: null
    property string draftCommand: ""
    property bool dialogIsEdit: false
    property bool closeEditorAfterSave: false
    readonly property string filePath: Quickshell.env("HOME") + "/.config/hypr/autostart.lua"

    function luaDecode(s) {
        return s.replace(/\\(u\{[0-9a-fA-F]+\}|x[0-9a-fA-F]{2}|[0-9]{1,3}|z\s*|[\s\S])/g, function(match, escape) {
            if (escape === "a")
                return "\u0007";

            if (escape === "b")
                return "\b";

            if (escape === "f")
                return "\f";

            if (escape === "n")
                return "\n";

            if (escape === "r")
                return "\r";

            if (escape === "t")
                return "\t";

            if (escape === "v")
                return "\u000b";

            if (escape === "\\")
                return "\\";

            if (escape === '"')
                return '"';

            if (escape === "'")
                return "'";

            if (escape.charAt(0) === "z")
                return "";

            if (escape.charAt(0) === "x")
                return String.fromCharCode(parseInt(escape.slice(1), 16));

            if (escape.charAt(0) === "u") {
                var codePoint = parseInt(escape.slice(2, -1), 16);
                try {
                    return String.fromCodePoint(codePoint);
                } catch (error) {
                    return match;
                }
            }
            if (/^[0-9]+$/.test(escape)) {
                var code = parseInt(escape, 10);
                return code <= 255 ? String.fromCharCode(code) : match;
            }
            if (escape === "\n" || escape === "\r")
                return "\n";

            return escape;
        });
    }

    function luaEncode(s) {
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t") + '"';
    }

    function parseEntries(text) {
        var found = [];
        var lines = text.split("\n");
        var offset = 0;
        var re = /^\s*(--\s*)?hl\.exec_cmd\s*\(\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')\s*\)\s*$/;
        for (var i = 0; i < lines.length; i++) {
            var raw = lines[i];
            var match = raw.match(re);
            if (match) {
                var literal = match[2];
                found.push({
                    "index": found.length,
                    "lineIndex": i,
                    "start": offset,
                    "end": offset + raw.length,
                    "line": raw,
                    "indent": (raw.match(/^\s*/) || [""])[0],
                    "command": luaDecode(literal.slice(1, -1)),
                    "enabled": !match[1],
                    "quote": literal.charAt(0)
                });
            }
            offset += raw.length + (i < lines.length - 1 ? 1 : 0);
        }
        return found;
    }

    function reloadFromText(text) {
        sourceText = text;
        entries = parseEntries(text);
    }

    function humanizeExecutable(executable) {
        var name = String(executable || "").split("/").pop();
        name = name.replace(/\.(desktop|appimage)$/i, "").replace(/[-_.]+/g, " ").trim();
        if (!name)
            return "Unnamed command";

        return name.replace(/\b[a-z]/g, function(letter) {
            return letter.toUpperCase();
        });
    }

    function commandTitle(command) {
        function findKnownTitle(text) {
            for (var i = 0; i < knownCommands.length; i++) {
                if (knownCommands[i].pattern.test(text))
                    return knownCommands[i].title;

            }
            return "";
        }

        var value = String(command || "").trim();
        if (!value)
            return "Unnamed command";

        var lower = value.toLowerCase();
        if (/pgrep[^\n]*waybar[\s\S]*pkill[^\n]*waybar|pkill[^\n]*waybar[\s\S]*waybar/.test(lower))
            return "Toggle Waybar";

        if (/dock-bar\s+autohidetoggle/.test(lower))
            return "Toggle Dock";

        if (/hyprquickpaper(?:\s+toggle)?/.test(lower))
            return "Wallpaper picker";

        if (/set-random\.sh/.test(lower))
            return "Random Wallpaper";

        var knownCommands = [{
            "pattern": /(^|[\s/])waybar(?=[\s/]|$)/,
            "title": "Waybar"
        }, {
            "pattern": /(^|[\s/])dock-bar(?=[\s/]|$)/,
            "title": "Dock Bar"
        }, {
            "pattern": /(^|[\s/])swaync-client(?=[\s/]|$)|(^|[\s/])swaync(?=[\s/]|$)/,
            "title": "SwayNC"
        }, {
            "pattern": /(^|[\s/])hypridle(?=[\s/]|$)/,
            "title": "Hypridle"
        }, {
            "pattern": /(^|[\s/])hyprlock(?=[\s/]|$)/,
            "title": "Hyprlock"
        }, {
            "pattern": /(^|[\s/])hyprpaper(?=[\s/]|$)/,
            "title": "Hyprpaper"
        }, {
            "pattern": /(^|[\s/])hyprsunset(?=[\s/]|$)/,
            "title": "Hyprsunset"
        }, {
            "pattern": /(^|[\s/])quickshell(?=[\s/]|$)/,
            "title": "Quickshell"
        }, {
            "pattern": /(^|[\s/])nm-applet(?=[\s/]|$)/,
            "title": "Network Manager Applet"
        }, {
            "pattern": /(^|[\s/])blueman-applet(?=[\s/]|$)/,
            "title": "Bluetooth Applet"
        }, {
            "pattern": /(^|[\s/])udiskie(?=[\s/]|$)/,
            "title": "Removable Drives"
        }, {
            "pattern": /(^|[\s/])polkit-gnome-authentication-agent-1(?=[\s/]|$)/,
            "title": "Polkit Authentication Agent"
        }, {
            "pattern": /(^|[\s/])wl-paste(?=[\s/]|$)/,
            "title": "Clipboard Monitor"
        }, {
            "pattern": /(^|[\s/])kdeconnect-indicator(?=[\s/]|$)/,
            "title": "KDE Connect"
        }, {
            "pattern": /(^|[\s/])easyeffects(?=[\s/]|$)/,
            "title": "Easy Effects"
        }, {
            "pattern": /(^|[\s/])spotify(?=[\s/]|$)/,
            "title": "Spotify"
        }, {
            "pattern": /(^|[\s/])steam(?=[\s/]|$)/,
            "title": "Steam"
        }, {
            "pattern": /(^|[\s/])kitty(?=[\s/]|$)/,
            "title": "Terminal"
        }, {
            "pattern": /(^|[\s/])swww(?=[\s/]|$)/,
            "title": "Swww"
        }, {
            "pattern": /(^|[\s/])mpvpaper(?=[\s/]|$)/,
            "title": "Video Wallpaper"
        }, {
            "pattern": /(^|[\s/])wlsunset(?=[\s/]|$)/,
            "title": "Night Light"
        }, {
            "pattern": /(^|[\s/])hyprquickpaper(?=[\s/]|$)/,
            "title": "Wallpaper picker"
        }, {
            "pattern": /(^|[\s/])hyprshot(?=[\s/]|$)/,
            "title": "Screenshot"
        }, {
            "pattern": /(^|[\s/])wf-recorder(?=[\s/]|$)/,
            "title": "Recorder"
        }, {
            "pattern": /(^|[\s/])playerctl(?=[\s/]|$)/,
            "title": "Media Controls"
        }, {
            "pattern": /(^|[\s/])brightnessctl(?=[\s/]|$)/,
            "title": "Brightness"
        }, {
            "pattern": /(^|[\s/])cliphist(?=[\s/]|$)/,
            "title": "Clipboard History"
        }, {
            "pattern": /(^|[\s/])thunar(?=[\s/]|$)/,
            "title": "File Manager"
        }, {
            "pattern": /(^|[\s/])helium-browser(?=[\s/]|$)/,
            "title": "Browser"
        }, {
            "pattern": /(^|[\s/])code(?=[\s/]|$)/,
            "title": "Visual Studio Code"
        }, {
            "pattern": /(^|[\s/])wofi(?=[\s/]|$)/,
            "title": "Application Launcher"
        }, {
            "pattern": /(^|[\s/])gsettings(?=[\s/]|$)/,
            "title": "GNOME Settings"
        }, {
            "pattern": /(^|[\s/])xwaylandvideobridge(?=[\s/]|$)/,
            "title": "XWayland Video Bridge"
        }, {
            "pattern": /(^|[\s/])settings(?=[\s/]|$)/,
            "title": "Settings"
        }];
        var knownTitle = findKnownTitle(lower);
        if (knownTitle)
            return knownTitle;

        var shellMatch = lower.match(/(?:^|\s)(?:sh|bash|zsh|fish)\s+-c\s+['"]([\s\S]*)['"]\s*$/);
        if (shellMatch) {
            var inner = shellMatch[1];
            if (/pgrep[^\n]*waybar[\s\S]*pkill[^\n]*waybar|pkill[^\n]*waybar[\s\S]*waybar/.test(inner))
                return "Toggle Waybar";

            knownTitle = findKnownTitle(inner);
            if (knownTitle)
                return knownTitle;

            var innerMatch = inner.match(/(?:^|[;&|]\s*|\s+)(?:exec\s+|nohup\s+|setsid\s+|env\s+)?((?:\.\.\/|\/)?[A-Za-z0-9_.-]+)(?=\s|$)/);
            if (innerMatch)
                return humanizeExecutable(innerMatch[1]);

        }
        var tokens = value.match(/(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[^\s]+)/g) || [];
        var wrappers = ["env", "nohup", "setsid", "exec", "command"];
        var executable = "";
        for (var tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            var token = tokens[tokenIndex].replace(/^["']|["']$/g, "");
            var base = token.split("/").pop();
            if (!base || wrappers.indexOf(base.toLowerCase()) >= 0 || /^[A-Za-z_][A-Za-z0-9_]*=/.test(base))
                continue;

            if (["sh", "bash", "zsh", "fish"].indexOf(base.toLowerCase()) >= 0 && tokenIndex + 1 < tokens.length && tokens[tokenIndex + 1] === "-c")
                continue;

            executable = base;
            break;
        }
        if (!executable)
            executable = value.split(/\s+/)[0].split("/").pop();

        if (executable.toLowerCase() === "flatpak") {
            var flatpakApp = value.match(/\bflatpak\s+run\s+(?:--[\w-]+(?:\s+[^\s]+)?\s+)*([A-Za-z0-9_.-]+\.[A-Za-z0-9_.-]+)/i);
            if (flatpakApp)
                executable = flatpakApp[1].split(".").pop();

        }
        return humanizeExecutable(executable);
    }

    function filteredEntries() {
        var query = searchText.trim().toLowerCase();
        if (!query)
            return entries;

        return entries.filter(function(entry) {
            return entry.command.toLowerCase().indexOf(query) !== -1 || commandTitle(entry.command).toLowerCase().indexOf(query) !== -1;
        });
    }

    function saveText(nextText, message) {
        sourceText = nextText;
        statusMessage = message || "Saving autostart.lua...";
        if (saveInProgress) {
            queuedSave = true;
            queuedSaveText = nextText;
            queuedSaveMessage = statusMessage;
            return true;
        }
        saveInProgress = true;
        autostartFile.setText(nextText);
        return true;
    }

    function addEntry(command) {
        var clean = command.trim();
        if (!clean) {
            statusMessage = "Enter a command";
            return false;
        }
        var startMatch = /hl\.on\s*\(\s*(["'])hyprland\.start\1\s*,\s*function\s*\(/.exec(sourceText);
        var shutdownMatch = /hl\.on\s*\(\s*(["'])hyprland\.shutdown\1\s*,\s*function\s*\(/.exec(sourceText);
        var startIndex = startMatch ? startMatch.index : -1;
        var shutdownIndex = shutdownMatch ? shutdownMatch.index : -1;
        if (startIndex < 0 || shutdownIndex < 0 || shutdownIndex <= startIndex) {
            statusMessage = "Could not find the hyprland.start callback; file unchanged";
            return false;
        }
        var callbackText = sourceText.slice(startIndex, shutdownIndex);
        var closingExpression = /^[\t ]*end[\t ]*\)[\t ]*(?:--.*)?$/gm;
        var closingMatch;
        var closeIndex = -1;
        while ((closingMatch = closingExpression.exec(callbackText)) !== null)closeIndex = startIndex + closingMatch.index
        if (closeIndex < startIndex) {
            statusMessage = "Could not find the end of hyprland.start; file unchanged";
            return false;
        }
        var prefix = sourceText.slice(0, closeIndex);
        var suffix = sourceText.slice(closeIndex);
        if (prefix.length > 0 && !prefix.endsWith("\n"))
            prefix += "\n";

        prefix += "        -- Added from Quickshell Settings · Autostart\n";
        prefix += "        hl.exec_cmd(" + luaEncode(clean) + ")\n";
        return saveText(prefix + suffix, "Adding startup command...");
    }

    function updateEntry(entry, command) {
        if (!entry || !command.trim()) {
            statusMessage = "Enter a command";
            return false;
        }
        var replacement = entry.indent + (entry.enabled ? "" : "-- ") + "hl.exec_cmd(" + luaEncode(command.trim()) + ")";
        var next = sourceText.slice(0, entry.start) + replacement + sourceText.slice(entry.end);
        return saveText(next, "Updating startup command...");
    }

    function toggleEntry(entry) {
        if (!entry)
            return ;

        var replacement = entry.indent + (entry.enabled ? "-- " : "") + "hl.exec_cmd(" + luaEncode(entry.command) + ")";
        var next = sourceText.slice(0, entry.start) + replacement + sourceText.slice(entry.end);
        saveText(next, entry.enabled ? "Disabling startup command..." : "Enabling startup command...");
    }

    function removeEntry(entry) {
        if (!entry)
            return ;

        var start = entry.start;
        var end = entry.end;
        var previousLineEnd = start > 0 && sourceText.charAt(start - 1) === "\n" ? start - 1 : start;
        var previousLineStart = sourceText.lastIndexOf("\n", previousLineEnd - 1) + 1;
        var previousLine = sourceText.slice(previousLineStart, previousLineEnd).trim();
        if (previousLine === "-- Added from Quickshell Settings · Autostart") {
            start = previousLineStart;
            if (start > 0 && sourceText.charAt(start - 1) === "\n")
                start--;

        }
        if (end < sourceText.length && sourceText.charAt(end) === "\n")
            end++;
        else if (start > 0 && sourceText.charAt(start - 1) === "\n")
            start--;
        var next = sourceText.slice(0, start) + sourceText.slice(end);
        saveText(next, "Removing startup command...");
    }

    FileView {
        id: autostartFile

        path: page.filePath
        preload: true
        watchChanges: false
        atomicWrites: true
        onLoaded: {
            page.reloadFromText(autostartFile.text());
            page.fileReady = true;
            page.statusMessage = page.entries.length + " startup commands detected";
        }
        onLoadFailed: (error) => {
            page.fileReady = false;
            page.statusMessage = "Unable to load autostart.lua";
        }
        onSaved: {
            page.saveInProgress = false;
            if (page.queuedSave) {
                var nextText = page.queuedSaveText;
                var nextMessage = page.queuedSaveMessage;
                page.queuedSave = false;
                page.queuedSaveText = "";
                page.queuedSaveMessage = "";
                page.statusMessage = nextMessage;
                page.saveInProgress = true;
                autostartFile.setText(nextText);
                return ;
            }
            page.reloadFromText(autostartFile.text());
            page.statusMessage = "Changes saved to autostart.lua";
            if (page.closeEditorAfterSave) {
                page.closeEditorAfterSave = false;
                editorDialog.close();
            }
        }
        onSaveFailed: (error) => {
            page.saveInProgress = false;
            if (page.queuedSave) {
                var nextText = page.queuedSaveText;
                var nextMessage = page.queuedSaveMessage;
                page.queuedSave = false;
                page.queuedSaveText = "";
                page.queuedSaveMessage = "";
                page.statusMessage = nextMessage;
                page.saveInProgress = true;
                autostartFile.setText(nextText);
                return ;
            }
            page.closeEditorAfterSave = false;
            page.statusMessage = "Could not save autostart.lua; reloading saved file...";
            autostartFile.reload();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "AUTOSTART"
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 19
                    font.weight: Font.Normal
                }

                Text {
                    text: page.entries.length + " startup commands · autostart.lua"
                    color: Theme.textFaint
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                }

            }

            Button {
                text: "Reload"
                implicitHeight: 28
                implicitWidth: 70
                enabled: page.fileReady
                onClicked: {
                    autostartFile.reload();
                    page.statusMessage = "Reloading startup commands...";
                }

                background: Rectangle {
                    radius: 7
                    color: parent.hovered ? Theme.bgPanel : Theme.bgCard
                    border.width: 1
                    border.color: Theme.border
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

            }

            Button {
                text: "+ Add command"
                implicitHeight: 28
                implicitWidth: 116
                enabled: page.fileReady
                onClicked: {
                    page.dialogIsEdit = false;
                    page.editingEntry = null;
                    page.draftCommand = "";
                    editorDialog.open();
                }

                background: Rectangle {
                    radius: 9
                    color: parent.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                    border.width: 1
                    border.color: Qt.lighter(Theme.accent, 1.12)
                }

                contentItem: Text {
                    text: parent.text
                    color: "#101116"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Search startup commands..."
            color: Theme.text
            font.family: Theme.fontFamily
            selectByMouse: true
            onTextChanged: page.searchText = text

            background: Rectangle {
                color: Theme.alpha(Theme.text, 0.025)
                radius: 7
                border.width: 1
                border.color: parent.activeFocus ? "#555555" : Theme.border
            }

        }

        Rectangle {
            id: cardsContainer

            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true

            ScrollView {
                id: cardsScroll

                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: cardsGrid.height
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Flow {
                    id: cardsGrid

                    width: cardsContainer.width
                    height: childrenRect.height
                    spacing: 10

                    Repeater {
                        id: entriesRepeater

                        model: page.filteredEntries()

                        delegate: Rectangle {
                            id: entryCard

                            required property var modelData
                            readonly property bool twoColumns: cardsGrid.width >= 620 && entriesRepeater.count > 1

                            width: twoColumns ? (cardsGrid.width - cardsGrid.spacing) / 2 : cardsGrid.width
                            height: 62
                            radius: 10
                            color: entryHover.hovered ? Theme.alpha(Theme.accent, 0.05) : Theme.alpha(Theme.text, 0.015)
                            border.width: 1
                            border.color: entryHover.hovered ? "#555555" : "#393939"
                            opacity: modelData.enabled ? 1 : 0.6

                            HoverHandler {
                                id: entryHover
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 9

                                Rectangle {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    radius: 7
                                    color: Theme.bgPanel
                                    border.width: 1
                                    border.color: Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        color: entryCard.modelData.enabled ? Theme.accent : Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: 15
                                    }

                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: page.commandTitle(entryCard.modelData.command)
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: entryCard.modelData.enabled ? "Enabled" : "Disabled"
                                        color: Theme.textFaint
                                        font.family: Theme.monoFont
                                        font.pixelSize: 10
                                    }

                                }

                                Switch {
                                    id: entrySwitch

                                    checked: entryCard.modelData.enabled
                                    onToggled: page.toggleEntry(entryCard.modelData)

                                    indicator: Rectangle {
                                        implicitWidth: 38
                                        implicitHeight: 20
                                        radius: 7
                                        color: entrySwitch.checked ? Theme.accent : Theme.bgPanel
                                        border.width: 1
                                        border.color: entrySwitch.checked ? Qt.lighter(Theme.accent, 1.15) : Theme.border

                                        Rectangle {
                                            x: entrySwitch.checked ? parent.width - width - 2 : 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 16
                                            height: 16
                                            radius: 8
                                            color: entrySwitch.checked ? "#101116" : Theme.textFaint

                                            Behavior on x {
                                                NumberAnimation {
                                                    duration: 150
                                                    easing.type: Easing.InOutQuad
                                                }

                                            }

                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }

                                        }

                                    }

                                }

                                Button {
                                    id: editButton

                                    implicitWidth: 28
                                    implicitHeight: 28
                                    hoverEnabled: true
                                    onClicked: {
                                        page.dialogIsEdit = true;
                                        page.editingEntry = entryCard.modelData;
                                        page.draftCommand = entryCard.modelData.command;
                                        editorDialog.open();
                                    }

                                    ToolTip {
                                        id: editCommandTooltip

                                        parent: editButton
                                        visible: editButton.hovered
                                        text: "Edit command"
                                        delay: 450
                                        timeout: -1
                                        padding: 9
                                        x: Math.round((parent.width - width) / 2)
                                        y: parent.height + 7

                                        contentItem: Row {
                                            spacing: 7

                                            Rectangle {
                                                width: 3
                                                height: 12
                                                radius: 2
                                                color: Theme.accent
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: editCommandTooltip.text
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                        }

                                        background: Rectangle {
                                            radius: 8
                                            color: "#111216"
                                            border.width: 1
                                            border.color: "#393939"
                                        }

                                    }

                                    background: Rectangle {
                                        radius: 7
                                        color: editButton.hovered ? Theme.bgCard : "transparent"
                                        border.width: 1
                                        border.color: editButton.hovered ? "#555555" : "#393939"

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 140
                                            }

                                        }

                                    }

                                    contentItem: Text {
                                        text: "󰏫"
                                        color: editButton.hovered ? Theme.accent : Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: 17
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                }

                                Button {
                                    id: removeButton

                                    implicitWidth: 28
                                    implicitHeight: 28
                                    hoverEnabled: true
                                    onClicked: page.removeEntry(entryCard.modelData)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Remove command"
                                    ToolTip.delay: 500

                                    background: Rectangle {
                                        radius: 7
                                        color: removeButton.hovered ? Theme.bgCard : "transparent"
                                        border.width: 1
                                        border.color: removeButton.hovered ? "#555555" : "#393939"

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 140
                                            }

                                        }

                                    }

                                    contentItem: Text {
                                        text: "󰆴"
                                        color: removeButton.hovered ? "#ff6b6b" : Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: 17
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                        }

                    }

                }

            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: page.fileReady && page.filteredEntries().length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰐥"
                    color: Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 32
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.searchText.trim().length > 0 ? "No matching startup commands" : "No simple hl.exec_cmd(...) entries found"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 7
                Layout.preferredHeight: 7
                radius: 4
                color: page.fileReady ? "#70c98b" : "#e5b567"
            }

            Text {
                Layout.fillWidth: true
                text: page.statusMessage
                color: Theme.textFaint
                font.family: Theme.monoFont
                font.pixelSize: 10
                elide: Text.ElideRight
            }

        }

    }

    Dialog {
        id: editorDialog

        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(470, page.width - 28)
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#111216"
            radius: 18
            border.width: 1
            border.color: "#393939"
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                spacing: 13

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 7
                    color: "#2b2e37"
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "󰐥"
                        color: Theme.accent
                        font.family: Theme.iconFont
                        font.pixelSize: 22
                    }

                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: page.dialogIsEdit ? "Edit startup command" : "Add startup command"
                        color: Theme.text
                        font.family: Theme.displayFont
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Configure program launched with Hyprland"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                spacing: 17

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        text: "COMMAND"
                        color: Theme.textFaint
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: 7
                        color: "#17191f"
                        border.width: commandField.activeFocus ? 1.5 : 1
                        border.color: commandField.activeFocus ? "#555555" : Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: ">_"
                                color: Theme.accent
                                font.family: Theme.monoFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            TextField {
                                id: commandField

                                Layout.fillWidth: true
                                text: page.draftCommand
                                placeholderText: "e.g. waybar"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: page.draftCommand = text
                                Keys.onReturnPressed: {
                                    var accepted = page.dialogIsEdit ? page.updateEntry(page.editingEntry, page.draftCommand) : page.addEntry(page.draftCommand);
                                    if (accepted)
                                        page.closeEditorAfterSave = true;

                                }

                                background: Item {
                                }

                            }

                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: "The command runs when Hyprland starts (e.g. 'waybar' or 'swaync')."
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                    }

                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                layoutDirection: Qt.RightToLeft
                Layout.margins: 16

                Button {
                    text: page.dialogIsEdit ? "Save changes" : "Add command"
                    implicitHeight: 32
                    implicitWidth: 116
                    onClicked: {
                        var accepted = page.dialogIsEdit ? page.updateEntry(page.editingEntry, page.draftCommand) : page.addEntry(page.draftCommand);
                        if (accepted)
                            page.closeEditorAfterSave = true;

                    }

                    background: Rectangle {
                        radius: 7
                        color: parent.down ? Qt.darker(Theme.accent, 1.12) : parent.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                        border.width: 1
                        border.color: Qt.lighter(Theme.accent, 1.12)
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "#101116"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                }

                Button {
                    text: "Cancel"
                    implicitHeight: 32
                    implicitWidth: 86
                    onClicked: editorDialog.close()

                    background: Rectangle {
                        radius: 7
                        color: parent.hovered ? "#2b2e36" : "#24262d"
                        border.width: 1
                        border.color: parent.hovered ? "#555555" : Theme.border
                    }

                    contentItem: Text {
                        text: parent.text
                        color: Theme.textSoft
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                }

            }

        }

    }

}
