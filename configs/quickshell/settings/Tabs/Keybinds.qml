import "../"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: page

    property string sourceText: ""
    property string statusMessage: "Loading shortcuts..."
    property var bindings: []
    property string searchText: ""
    property string categoryFilter: "All"
    property var selectedBinding: null
    property string editKey: ""
    property string editCommand: ""
    property bool fileReady: false
    readonly property var categories: ["All", "Apps", "Windows", "Workspaces", "Media", "Capture", "Other"]

    function skipString(s, i) {
        var ch = s.charAt(i);
        if (ch === '"' || ch === "'") {
            var quote = ch;
            i++;
            while (i < s.length)
                if (s.charAt(i) === "\\")
                    i += 2;
                else if (s.charAt(i) === quote)
                    return i + 1;
                else
                    i++;

            return s.length;
        }
        if (ch === "[") {
            var m = s.slice(i).match(/^\[(=*)\[/);
            if (m) {
                var closing = "]" + m[1] + "]";
                var end = s.indexOf(closing, i + m[0].length);
                return end < 0 ? s.length : end + closing.length;
            }
        }
        return i;
    }

    function skipComment(s, i) {
        if (s.substr(i, 2) !== "--")
            return i;

        var m = s.slice(i + 2).match(/^\[(=*)\[/);
        if (m) {
            var closing = "]" + m[1] + "]";
            var end = s.indexOf(closing, i + 2 + m[0].length);
            return end < 0 ? s.length : end + closing.length;
        }
        var newline = s.indexOf("\n", i + 2);
        return newline < 0 ? s.length : newline + 1;
    }

    function trimRange(s, start, end) {
        while (start < end && /\s/.test(s.charAt(start)))start++
        while (end > start && /\s/.test(s.charAt(end - 1)))end--
        return {
            "start": start,
            "end": end,
            "text": s.slice(start, end)
        };
    }

    function splitArguments(s, start, end) {
        var result = [], partStart = start;
        var parens = 0, braces = 0, brackets = 0, i = start;
        while (i < end) {
            if (s.substr(i, 2) === "--") {
                i = skipComment(s, i);
                continue;
            }
            var next = skipString(s, i);
            if (next !== i) {
                i = next;
                continue;
            }
            var ch = s.charAt(i);
            if (ch === "(")
                parens++;
            else if (ch === ")")
                parens--;
            else if (ch === "{")
                braces++;
            else if (ch === "}")
                braces--;
            else if (ch === "[")
                brackets++;
            else if (ch === "]")
                brackets--;
            if (ch === "," && parens === 0 && braces === 0 && brackets === 0) {
                result.push(trimRange(s, partStart, i));
                partStart = i + 1;
            }
            i++;
        }
        if (partStart < end)
            result.push(trimRange(s, partStart, end));

        return result;
    }

    function findCalls(s) {
        var result = [], i = 0;
        while (i < s.length) {
            if (s.substr(i, 2) === "--") {
                i = skipComment(s, i);
                continue;
            }
            var next = skipString(s, i);
            if (next !== i) {
                i = next;
                continue;
            }
            if (s.substr(i, 8) === "hl.bind(") {
                var open = i + 7, depth = 1, j = open + 1;
                while (j < s.length && depth > 0) {
                    if (s.substr(j, 2) === "--") {
                        j = skipComment(s, j);
                        continue;
                    }
                    next = skipString(s, j);
                    if (next !== j) {
                        j = next;
                        continue;
                    }
                    if (s.charAt(j) === "(")
                        depth++;
                    else if (s.charAt(j) === ")")
                        depth--;
                    j++;
                }
                if (depth === 0) {
                    result.push({
                        "start": i,
                        "end": j,
                        "args": splitArguments(s, open + 1, j - 1)
                    });
                    i = j;
                    continue;
                }
            }
            i++;
        }
        return result;
    }

    function decodeLuaString(s) {
        return s.replace(/\\([\s\S])/g, function(match, ch) {
            if (ch === "n")
                return "\n";

            if (ch === "r")
                return "\r";

            if (ch === "t")
                return "\t";

            if (ch === "b")
                return "\b";

            if (ch === "f")
                return "\f";

            if (ch === "v")
                return "\v";

            return ch;
        });
    }

    function encodeLuaString(s) {
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t") + '"';
    }

    function getKey(raw) {
        var value = raw.trim();
        // Support format: mainMod .. " + B"
        if (value.indexOf("mainMod") >= 0) {
            var match = value.match(/["']([^"']*)["']/);
            if (match) {
                var cleanMatch = match[1].replace(/^\s*\+\s*/, "");
                return "SUPER + " + cleanMatch.toUpperCase();
            }
            return "SUPER";
        }
        var quoted = value.match(/^(['"])([\s\S]*)\1$/);
        if (quoted)
            return decodeLuaString(quoted[2]);

        return value;
    }

    function getCommand(raw) {
        var value = raw.trim();
        var match = value.match(/^hl\.dsp\.exec_cmd\s*\(\s*"((?:\\.|[^"\\])*)"\s*\)$/);
        if (!match)
            match = value.match(/^hl\.dsp\.exec_cmd\s*\(\s*'((?:\\.|[^'\\])*)'\s*\)$/);

        if (match)
            return {
            "editable": true,
            "command": decodeLuaString(match[1])
        };

        match = value.match(/^hl\.dsp\.exec_cmd\s*\(\s*\[(=*)\[([\s\S]*?)\]\1\]\s*\)$/);
        if (match)
            return {
            "editable": true,
            "command": match[2]
        };

        return {
            "editable": false,
            "command": ""
        };
    }

    function getCategory(key, command, raw) {
        var value = (key + " " + command + " " + raw).toLowerCase();
        if (/xf86audio|xf86monbrightness|wpctl|playerctl|brightnessctl/.test(value))
            return "Media";

        if (/wf-recorder|hyprshot|screenshot|screen.record/.test(value))
            return "Capture";

        if (/workspace|tiled_layout|focus\(|layout\(|window\.move/.test(value))
            return "Workspaces";

        if (/window\.|fullscreen|float\(|center\(|resize\(|cycle_next|bring_to_top/.test(value))
            return "Windows";

        if (/kitty|thunar|code|helium-browser|spotify|wofi|cliphist|hyprlock|swaync/.test(value))
            return "Apps";

        return "Other";
    }

    function getTitle(key, command, raw) {
        var cmd = command.trim().toLowerCase();
        if (cmd === "kitty")
            return "Terminal";

        if (cmd === "thunar")
            return "File Manager";

        if (cmd === "code")
            return "Visual Studio Code";

        if (cmd === "spotify")
            return "Spotify";

        if (cmd === "helium-browser")
            return "Browser";

        if (cmd.indexOf("hyprlock") >= 0)
            return "Lock screen";

        if (cmd.indexOf("hyprshot") >= 0)
            return "Screenshot";

        if (cmd.indexOf("wf-recorder") >= 0)
            return "Screen recorder";

        if (cmd.indexOf("playerctl") >= 0)
            return "Media controls";

        if (cmd.indexOf("wpctl") >= 0)
            return "Audio controls";

        if (cmd.indexOf("wofi") >= 0)
            return "Application launcher";

        if (cmd.indexOf("swaync") >= 0)
            return "Notifications";

        if (cmd.indexOf("hyprquickpaper") >= 0)
            return "Wallpaper";

        if (cmd.indexOf("waybar") >= 0)
            return "Toggle Waybar";

        if (cmd.indexOf("dock-bar") >= 0)
            return "Toggle Dock";

        if (cmd.indexOf("settings") >= 0)
            return "Settings";

        if (key.indexOf("Dynamic") >= 0)
            return "Dynamic keybinding";

        if (command.length > 0)
            return command.length > 42 ? command.slice(0, 39) + "..." : command;

        if (raw.indexOf("hl.dsp.window.close") >= 0)
            return "Close window";

        if (raw.indexOf("hl.dsp.exit") >= 0)
            return "Exit session";

        if (raw.indexOf("hl.dsp.focus") >= 0)
            return "Focus window";

        if (raw.indexOf("hl.dsp.window.fullscreen") >= 0)
            return "Toggle fullscreen";

        if (raw.indexOf("hl.dsp.window.float") >= 0)
            return "Toggle floating";

        if (raw.indexOf("hl.dsp.window.move") >= 0)
            return "Move window";

        if (raw.indexOf("hl.dsp.layout") >= 0)
            return "Layout control";

        return "Custom action";
    }

    function parseBindings(s) {
        var parsed = [], calls = findCalls(s);
        for (var i = 0; i < calls.length; i++) {
            var call = calls[i];
            if (call.args.length < 2)
                continue;

            var keyArg = call.args[0], actionArg = call.args[1];
            var keyRaw = keyArg.text, actionRaw = actionArg.text;
            var key = getKey(keyRaw);
            var commandInfo = getCommand(actionRaw);
            var command = commandInfo.command;
            parsed.push({
                "id": i,
                "key": key,
                "title": getTitle(key, command, actionRaw),
                "command": command,
                "category": getCategory(key, command, actionRaw),
                "keyEditable": keyRaw.indexOf("mainMod") >= 0 || /^["']/.test(keyRaw),
                "commandEditable": commandInfo.editable,
                "keyStart": keyArg.start,
                "keyEnd": keyArg.end,
                "actionStart": actionArg.start,
                "actionEnd": actionArg.end,
                "rawAction": actionRaw
            });
        }
        return parsed;
    }

    function loadBindings(text) {
        sourceText = text;
        bindings = parseBindings(text);
    }

    function visibleBindings() {
        var result = [], query = searchText.trim().toLowerCase();
        for (var i = 0; i < bindings.length; i++) {
            var b = bindings[i];
            if (categoryFilter !== "All" && b.category !== categoryFilter)
                continue;

            var searchable = (b.key + " " + b.title + " " + b.command + " " + b.category).toLowerCase();
            if (query.length && searchable.indexOf(query) < 0)
                continue;

            result.push(b);
        }
        return result;
    }

    function openEditor(binding) {
        selectedBinding = binding;
        editKey = binding.keyEditable ? binding.key : "";
        editCommand = binding.command;
        editDialog.open();
    }

    function applyEdit() {
        if (!selectedBinding)
            return ;

        var replacements = [], b = selectedBinding;
        if (b.keyEditable && editKey.trim().length > 0 && editKey !== b.key) {
            var newKeyText = editKey.trim();
            var formattedKey = "";
            if (/^SUPER\s*\+\s*/i.test(newKeyText)) {
                var actualKey = newKeyText.replace(/^SUPER\s*\+\s*/i, "").trim();
                formattedKey = 'mainMod .. " + ' + actualKey + '"';
            } else {
                formattedKey = encodeLuaString(newKeyText);
            }
            replacements.push({
                "start": b.keyStart,
                "end": b.keyEnd,
                "text": formattedKey
            });
        }
        if (b.commandEditable && editCommand !== b.command)
            replacements.push({
            "start": b.actionStart,
            "end": b.actionEnd,
            "text": "hl.dsp.exec_cmd(" + encodeLuaString(editCommand) + ")"
        });

        if (!replacements.length) {
            statusMessage = "No changes to save";
            return ;
        }
        replacements.sort(function(a, b) {
            return b.start - a.start;
        });
        var updated = sourceText;
        for (var i = 0; i < replacements.length; i++) {
            var r = replacements[i];
            updated = updated.slice(0, r.start) + r.text + updated.slice(r.end);
        }
        sourceText = updated;
        bindings = parseBindings(updated);
        keybindFile.setText(updated);
        statusMessage = "Saving keybinds.lua...";
    }

    FileView {
        id: keybindFile

        path: Quickshell.env("HOME") + "/.config/hypr/keybinds.lua"
        preload: true
        watchChanges: false
        atomicWrites: true
        onLoaded: {
            page.loadBindings(keybindFile.text());
            page.fileReady = true;
            page.statusMessage = page.bindings.length + " keybindings detected";
        }
        onLoadFailed: (error) => {
            page.fileReady = false;
            page.statusMessage = "Unable to load keybinds.lua";
        }
        onSaved: {
            page.statusMessage = "Changes saved to keybinds.lua";
            page.loadBindings(page.sourceText);
        }
        onSaveFailed: (error) => {
            return page.statusMessage = "Could not save keybinds.lua";
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
                    text: "Keybind Manager"
                    color: Theme.text
                    font.family: Theme.displayFont
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    text: page.bindings.length + " shortcuts · keybinds.lua"
                    color: Theme.textFaint
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }

            }

            Button {
                text: "Reload"
                enabled: page.fileReady
                onClicked: {
                    keybindFile.reload();
                    page.statusMessage = "Reloading shortcuts...";
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

        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Search by shortcut, action or command..."
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

        Flickable {
            Layout.fillWidth: true
            implicitHeight: 36
            contentWidth: categoryRow.implicitWidth
            contentHeight: categoryRow.implicitHeight
            clip: true

            Row {
                id: categoryRow

                spacing: 7

                Repeater {
                    model: page.categories

                    delegate: Button {
                        required property string modelData

                        text: modelData
                        onClicked: page.categoryFilter = modelData

                        background: Rectangle {
                            radius: 9
                            color: page.categoryFilter === modelData ? Theme.bgPanel : "transparent"
                            border.width: 1
                            border.color: page.categoryFilter === modelData ? Theme.accent : Theme.border
                        }

                        contentItem: Text {
                            text: modelData
                            color: page.categoryFilter === modelData ? Theme.text : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                    }

                }

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
                        model: page.visibleBindings()

                        delegate: Rectangle {
                            id: shortcutCard

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: (cardsGrid.width - cardsGrid.columnSpacing) / 2
                            Layout.preferredHeight: 132
                            radius: 14
                            color: cardHover.hovered ? Theme.bgPanel : Theme.bgCard
                            border.width: 1
                            border.color: cardHover.hovered ? Theme.accent : Theme.border

                            HoverHandler {
                                id: cardHover
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
                                            text: {
                                                switch (shortcutCard.modelData.category) {
                                                case "Apps":
                                                    return "󰀻";
                                                case "Windows":
                                                    return "󰖯";
                                                case "Workspaces":
                                                    return "󰓓";
                                                case "Media":
                                                    return "󰎆";
                                                case "Capture":
                                                    return "󰄀";
                                                default:
                                                    return "󰌌";
                                                }
                                            }
                                            color: Theme.accent
                                            font.family: Theme.iconFont
                                            font.pixelSize: 18
                                        }

                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: shortcutCard.modelData.title
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: shortcutCard.modelData.category
                                            color: Theme.textFaint
                                            font.family: Theme.monoFont
                                            font.pixelSize: 10
                                        }

                                    }

                                    Button {
                                        id: editButton

                                        implicitWidth: 34
                                        implicitHeight: 34
                                        hoverEnabled: true
                                        onClicked: page.openEditor(shortcutCard.modelData)
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Edit shortcut"
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

                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Repeater {
                                        model: shortcutCard.modelData.key.split(" + ")

                                        delegate: Rectangle {
                                            required property string modelData

                                            implicitWidth: keyLabel.implicitWidth + 18
                                            implicitHeight: 26
                                            radius: 6
                                            color: Theme.bgPanel
                                            border.width: 1
                                            border.color: Theme.border

                                            Text {
                                                id: keyLabel

                                                anchors.centerIn: parent
                                                text: modelData
                                                color: Theme.textSoft
                                                font.family: Theme.monoFont
                                                font.pixelSize: 10
                                            }

                                        }

                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: shortcutCard.modelData.command.length ? shortcutCard.modelData.command : shortcutCard.modelData.rawAction
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
                visible: page.fileReady && page.visibleBindings().length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰌌"
                    color: Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 32
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No matching shortcuts"
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
        id: editDialog

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
                        text: "󰌌"
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
                        text: page.selectedBinding ? page.selectedBinding.title : "Edit shortcut"
                        color: Theme.text
                        font.family: Theme.displayFont
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Customize this keybinding"
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
                    visible: page.selectedBinding ? page.selectedBinding.keyEditable : false

                    Label {
                        text: "KEY COMBINATION"
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
                        border.width: keyField.activeFocus ? 1.5 : 1
                        border.color: keyField.activeFocus ? Theme.accent : "#3a3d46"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "󰌌"
                                color: Theme.accent
                                font.family: Theme.iconFont
                                font.pixelSize: 16
                            }

                            TextField {
                                id: keyField

                                Layout.fillWidth: true
                                text: page.editKey
                                placeholderText: "SUPER + T"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: page.editKey = text

                                background: Item {
                                }

                            }

                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Use SUPER, SHIFT, CTRL, ALT and the key name."
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                    }

                }

                Text {
                    Layout.fillWidth: true
                    visible: page.selectedBinding ? !page.selectedBinding.keyEditable : false
                    text: "This shortcut is generated dynamically in Lua and cannot be edited here."
                    color: Theme.textFaint
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: page.selectedBinding ? page.selectedBinding.commandEditable : false

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
                                text: page.editCommand
                                placeholderText: "Command to execute"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: page.editCommand = text

                                background: Item {
                                }

                            }

                        }

                    }

                }

                Text {
                    Layout.fillWidth: true
                    visible: page.selectedBinding ? !page.selectedBinding.commandEditable : false
                    text: "Custom Lua action · Original code will be preserved."
                    color: Theme.textFaint
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
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
                    text: "Save changes"
                    implicitHeight: 38
                    implicitWidth: 116
                    onClicked: {
                        page.applyEdit();
                        editDialog.close();
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
                    onClicked: editDialog.close()

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
