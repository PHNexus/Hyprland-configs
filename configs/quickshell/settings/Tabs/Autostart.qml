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

            if (escape === "\"")
                return "\"";

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
        return "\"" + s.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t") + "\"";
    }

    function parseEntries(text) {
        var found = [];
        var lines = text.split("\n");
        var offset = 0;
        var re = /^\s*(--\s*)?hl\.exec_cmd\s*\(\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')\s*\)\s*$/;
        for (var i = 0; i < lines.length; i++) {
            var raw = lines[i];
            var m = raw.match(re);
            if (m) {
                var literal = m[2];
                var quote = literal.charAt(0);
                var value = literal.slice(1, -1);
                found.push({
                    "index": found.length,
                    "lineIndex": i,
                    "start": offset,
                    "end": offset + raw.length,
                    "line": raw,
                    "indent": (raw.match(/^\s*/) || [""])[0],
                    "command": luaDecode(value),
                    "enabled": !m[1],
                    "quote": quote
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

    function commandTitle(command) {
        var s = command.trim();
        if (!s)
            return "Unnamed command";

        var first = s.split(/\s+/)[0];
        var bits = first.split("/");
        return bits[bits.length - 1] || first;
    }

    function filteredEntries() {
        var q = searchText.trim().toLowerCase();
        if (!q)
            return entries;

        return entries.filter(function(entry) {
            return entry.command.toLowerCase().indexOf(q) !== -1 || commandTitle(entry.command).toLowerCase().indexOf(q) !== -1;
        });
    }

    function saveText(nextText, message) {
        sourceText = nextText;
        statusMessage = message || "Saving autostart.lua...";
        if (saveInProgress) {
            queuedSave = true;
            queuedSaveText = nextText;
            queuedSaveMessage = message || "Saving autostart.lua...";
            return true;
        }
        saveInProgress = true;
        autostartFile.setText(nextText);
        return true;
    }

    function addEntry(command) {
        var clean = command.trim();
        if (!clean)
            return false;

        // Keep new commands inside the existing hyprland.start callback.
        // Appending after `return M` would place them outside setup.
        // Accept Lua's single/double quotes and harmless spacing variations.
        var startMatch = /hl\.on\s*\(\s*(["'])hyprland\.start\1\s*,\s*function\s*\(/.exec(sourceText);
        var shutdownMatch = /hl\.on\s*\(\s*(["'])hyprland\.shutdown\1\s*,\s*function\s*\(/.exec(sourceText);
        var startIndex = startMatch ? startMatch.index : -1;
        var shutdownIndex = shutdownMatch ? shutdownMatch.index : -1;
        if (startIndex < 0 || shutdownIndex < 0 || shutdownIndex <= startIndex) {
            statusMessage = "Could not find the hyprland.start callback; file unchanged";
            return false;
        }
        var callbackText = sourceText.slice(startIndex, shutdownIndex);
        var closingExpression = /\bend\s*\)/g;
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
        if (!entry || !command.trim())
            return false;

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
                    text: "Autostart Manager"
                    color: Theme.text
                    font.family: Theme.displayFont
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    text: page.entries.length + " startup commands · autostart.lua"
                    color: Theme.textFaint
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }

            }

            Button {
                text: "Reload"
                enabled: page.fileReady
                onClicked: {
                    autostartFile.reload();
                    page.statusMessage = "Reloading startup commands...";
                }

                background: Rectangle {
                    radius: 9
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

        TextField {
            Layout.fillWidth: true
            placeholderText: "Search startup commands..."
            color: Theme.text
            font.family: Theme.fontFamily
            selectByMouse: true
            onTextChanged: page.searchText = text

            background: Rectangle {
                color: Theme.bgCard
                radius: 11
                border.width: 1
                border.color: parent.activeFocus ? Theme.accent : Theme.border
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true

            ScrollView {
                anchors.fill: parent
                clip: true

                GridLayout {
                    id: cardsGrid

                    width: parent.width
                    columns: width >= 620 ? 2 : 1
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: page.filteredEntries()

                        delegate: Rectangle {
                            id: entryCard

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: (cardsGrid.width - cardsGrid.columnSpacing) / 2
                            Layout.preferredHeight: 110
                            radius: 14
                            color: entryHover.hovered ? Theme.bgPanel : Theme.bgCard
                            border.width: 1
                            border.color: entryHover.hovered ? Theme.accent : Theme.border
                            opacity: modelData.enabled ? 1 : 0.6

                            HoverHandler {
                                id: entryHover
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 13
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 10
                                        color: Theme.bgPanel
                                        border.width: 1
                                        border.color: Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰐥"
                                            color: modelData.enabled ? Theme.accent : Theme.textFaint
                                            font.family: Theme.iconFont
                                            font.pixelSize: 17
                                        }

                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: page.commandTitle(modelData.command)
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: modelData.enabled ? "Enabled" : "Disabled"
                                            color: Theme.textFaint
                                            font.family: Theme.monoFont
                                            font.pixelSize: 10
                                        }

                                    }

                                    Switch {
                                        id: entrySwitch

                                        checked: modelData.enabled
                                        onToggled: page.toggleEntry(modelData)

                                        indicator: Rectangle {
                                            implicitWidth: 38
                                            implicitHeight: 20
                                            radius: 10
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

                                        implicitWidth: 34
                                        implicitHeight: 34
                                        hoverEnabled: true
                                        onClicked: {
                                            page.dialogIsEdit = true;
                                            page.editingEntry = modelData;
                                            page.draftCommand = modelData.command;
                                            editorDialog.open();
                                        }
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Edit command"
                                        ToolTip.delay: 500

                                        background: Rectangle {
                                            radius: 10
                                            color: editButton.hovered ? Theme.bgCard : "transparent"
                                            border.width: 1
                                            border.color: editButton.hovered ? Theme.accent : "transparent"

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

                                        implicitWidth: 34
                                        implicitHeight: 34
                                        hoverEnabled: true
                                        onClicked: page.removeEntry(modelData)
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Remove command"
                                        ToolTip.delay: 500

                                        background: Rectangle {
                                            radius: 10
                                            color: removeButton.hovered ? Theme.bgCard : "transparent"
                                            border.width: 1
                                            border.color: removeButton.hovered ? "#ff6b6b" : "transparent"

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

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.command
                                    color: Theme.textDim
                                    font.family: Theme.monoFont
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
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
        anchors.centerIn: parent
        width: Math.min(470, page.width - 28)
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#202228"
            radius: 18
            border.width: 1
            border.color: "#3a3d46"
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                spacing: 13

                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46
                    radius: 14
                    color: "#2b2e37"
                    border.width: 1
                    border.color: "#444853"

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
                color: "#383b44"
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
                        implicitHeight: 48
                        radius: 11
                        color: "#17191f"
                        border.width: commandField.activeFocus ? 1.5 : 1
                        border.color: commandField.activeFocus ? Theme.accent : "#3a3d46"

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
                color: "#383b44"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                layoutDirection: Qt.RightToLeft
                Layout.margins: 16

                Button {
                    text: page.dialogIsEdit ? "Save changes" : "Add command"
                    implicitHeight: 38
                    implicitWidth: 116
                    onClicked: {
                        var accepted = page.dialogIsEdit ? page.updateEntry(page.editingEntry, page.draftCommand) : page.addEntry(page.draftCommand);
                        if (accepted)
                            page.closeEditorAfterSave = true;

                    }

                    background: Rectangle {
                        radius: 10
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
                    implicitHeight: 38
                    implicitWidth: 86
                    onClicked: editorDialog.close()

                    background: Rectangle {
                        radius: 10
                        color: parent.hovered ? "#2b2e36" : "#24262d"
                        border.width: 1
                        border.color: "#41444e"
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
