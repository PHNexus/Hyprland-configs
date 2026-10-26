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
    property bool saveInProgress: false
    property bool queuedSave: false
    property string queuedSaveText: ""
    property string queuedSaveMessage: ""
    property bool closeEditorAfterSave: false
    property bool dialogIsAdd: false
    readonly property var categories: ["All", "Apps", "Windows", "Workspaces", "Media", "Capture", "Other"]

    function skipString(s, i) {
        var ch = s.charAt(i);
        if (ch === '"' || ch === "'") {
            var quote = ch;
            i++;
            while (i < s.length)if (s.charAt(i) === "\\")
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
            // Allow valid Lua whitespace between the function name and `(`.
            var bindMatch = s.slice(i).match(/^hl\.bind\s*\(/);
            if (bindMatch) {
                var open = i + bindMatch[0].length - 1, depth = 1, j = open + 1;
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
                var decimalCode = parseInt(escape, 10);
                return decimalCode <= 255 ? String.fromCharCode(decimalCode) : match;
            }
            if (escape === "\n" || escape === "\r")
                return "\n";

            return escape;
        });
    }

    function encodeLuaString(s) {
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t") + '"';
    }

    function mainModifier(source) {
        var text = source === undefined ? sourceText : source;
        var match = text.match(/(?:local\s+)?mainMod\s*=\s*["']([^"']+)["']/);
        return match ? match[1].trim().toUpperCase() : "SUPER";
    }

    function getKey(raw, source) {
        var value = raw.trim();
        // Support format: mainMod .. " + B"
        if (value.indexOf("mainMod") >= 0) {
            var match = value.match(/["']([^"']*)["']/);
            if (match) {
                var cleanMatch = match[1].replace(/^\s*\+\s*/, "");
                return mainModifier(source) + " + " + cleanMatch.toUpperCase();
            }
            return mainModifier(source);
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

    function parseBindings(s, includeDisabled) {
        var parsed = [], calls = findCalls(s);
        for (var i = 0; i < calls.length; i++) {
            var call = calls[i];
            if (call.args.length < 2)
                continue;

            var keyArg = call.args[0], actionArg = call.args[1];
            var keyRaw = keyArg.text, actionRaw = actionArg.text;
            var key = getKey(keyRaw, s);
            var commandInfo = getCommand(actionRaw);
            var command = commandInfo.command;
            var lineStart = s.lastIndexOf("\n", call.start - 1) + 1;
            var lineEnd = s.indexOf("\n", call.end);
            if (lineEnd < 0)
                lineEnd = s.length;

            parsed.push({
                "id": i,
                "key": key,
                "title": getTitle(key, command, actionRaw),
                "command": command,
                "category": getCategory(key, command, actionRaw),
                "keyEditable": /^mainMod\s*\.\.\s*["'][^"']*["']$/.test(keyRaw) || /^["'][\s\S]*["']$/.test(keyRaw),
                "commandEditable": commandInfo.editable,
                "keyStart": keyArg.start,
                "keyEnd": keyArg.end,
                "actionStart": actionArg.start,
                "actionEnd": actionArg.end,
                "rawAction": actionRaw,
                "enabled": true,
                "start": call.start,
                "end": call.end,
                "lineStart": lineStart,
                "lineEnd": lineEnd,
                "blockStart": -1,
                "blockEnd": -1
            });
        }
        if (includeDisabled === false)
            return parsed;

        // Disabled bindings are stored in reversible comment blocks so multiline Lua calls
        // can be toggled without losing their original formatting or comments.
        var markerPattern = /(^|\n)-- KEYBIND_DISABLED_BEGIN\r?\n([\s\S]*?)\r?\n-- KEYBIND_DISABLED_END/g;
        var markerMatch;
        while ((markerMatch = markerPattern.exec(s)) !== null) {
            var blockStart = markerMatch.index + markerMatch[1].length;
            var beginLineEnd = s.indexOf("\n", blockStart);
            if (beginLineEnd < 0)
                continue;

            var bodyStart = beginLineEnd + 1;
            var endMarkerStart = s.indexOf("-- KEYBIND_DISABLED_END", bodyStart);
            if (endMarkerStart < 0)
                continue;

            var bodyEnd = endMarkerStart;
            if (bodyEnd > bodyStart && s.charAt(bodyEnd - 1) === "\n")
                bodyEnd--;

            if (bodyEnd > bodyStart && s.charAt(bodyEnd - 1) === "\r")
                bodyEnd--;

            var bodyRaw = s.slice(bodyStart, bodyEnd);
            var bodyLines = bodyRaw.split("\n");
            var restoredLines = [];
            var sourceOffsets = [];
            var sourceLineOffset = bodyStart;
            for (var lineIndex = 0; lineIndex < bodyLines.length; lineIndex++) {
                var commentedLine = bodyLines[lineIndex];
                var prefixLength = commentedLine.indexOf("-- ") === 0 ? 3 : (commentedLine.indexOf("--") === 0 ? 2 : 0);
                var restoredLine = commentedLine.slice(prefixLength);
                restoredLines.push(restoredLine);
                for (var charIndex = 0; charIndex < restoredLine.length; charIndex++) sourceOffsets.push(sourceLineOffset + prefixLength + charIndex)
                if (lineIndex < bodyLines.length - 1)
                    sourceOffsets.push(sourceLineOffset + commentedLine.length);

                sourceLineOffset += commentedLine.length + (lineIndex < bodyLines.length - 1 ? 1 : 0);
            }
            var restoredText = restoredLines.join("\n");
            var innerBindings = parseBindings(restoredText, false);
            var blockEnd = endMarkerStart + "-- KEYBIND_DISABLED_END".length;
            for (var innerIndex = 0; innerIndex < innerBindings.length; innerIndex++) {
                var disabled = innerBindings[innerIndex];
                if (disabled.keyStart < 0 || disabled.keyEnd <= disabled.keyStart || disabled.keyEnd - 1 >= sourceOffsets.length)
                    continue;

                if (disabled.actionStart < 0 || disabled.actionEnd <= disabled.actionStart || disabled.actionEnd - 1 >= sourceOffsets.length)
                    continue;

                disabled.keyStart = sourceOffsets[disabled.keyStart];
                disabled.keyEnd = sourceOffsets[disabled.keyEnd - 1] + 1;
                disabled.actionStart = sourceOffsets[disabled.actionStart];
                disabled.actionEnd = sourceOffsets[disabled.actionEnd - 1] + 1;
                disabled.enabled = false;
                disabled.start = blockStart;
                disabled.end = blockEnd;
                disabled.lineStart = blockStart;
                disabled.lineEnd = blockEnd;
                disabled.blockStart = blockStart;
                disabled.blockEnd = blockEnd;
                disabled.id = parsed.length + innerIndex;
                parsed.push(disabled);
            }
        }
        parsed.sort(function(a, b) {
            return a.start - b.start;
        });
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
        dialogIsAdd = false;
        selectedBinding = binding;
        editKey = binding.keyEditable ? binding.key : "";
        editCommand = binding.command;
        editDialog.open();
    }

    function openAddDialog() {
        dialogIsAdd = true;
        selectedBinding = null;
        editKey = "";
        editCommand = "";
        editDialog.open();
    }

    function saveSource(text, message) {
        sourceText = text;
        statusMessage = message || "Saving keybinds.lua...";
        if (saveInProgress) {
            queuedSave = true;
            queuedSaveText = text;
            queuedSaveMessage = statusMessage;
            return true;
        }
        saveInProgress = true;
        keybindFile.setText(text);
        return true;
    }

    function normalizedShortcut(key) {
        return key.trim().replace(/\s*\+\s*/g, " + ").toUpperCase();
    }

    function keyExpression(input) {
        var normalized = input.trim().replace(/\s*\+\s*/g, " + ");
        var modifier = mainModifier(sourceText);
        var escapedModifier = modifier.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        var match = normalized.match(new RegExp("^" + escapedModifier + "\\s*\\+\\s*(.+)$", "i"));
        if (match) {
            var suffix = match[1].trim().replace(/\s*\+\s*/g, " + ");
            if (!suffix)
                return "";

            return "mainMod .. " + encodeLuaString(" + " + suffix);
        }
        return encodeLuaString(normalized);
    }

    function addBinding(key, command) {
        var cleanKey = key.trim().replace(/\s*\+\s*/g, " + ");
        var cleanCommand = command.trim();
        if (!cleanKey || !cleanCommand) {
            statusMessage = "Enter both a shortcut and a command";
            return false;
        }
        var expression = keyExpression(cleanKey);
        if (!expression) {
            statusMessage = "Enter a valid key combination";
            return false;
        }
        var candidate = normalizedShortcut(cleanKey);
        for (var i = 0; i < bindings.length; i++) {
            if (bindings[i].enabled && normalizedShortcut(bindings[i].key) === candidate) {
                statusMessage = "That shortcut is already assigned to another action";
                return false;
            }
        }
        var closing = /\nend\s*\n\s*return\s+M\s*$/m.exec(sourceText);
        if (!closing) {
            statusMessage = "Could not find the end of M.setup(); keybinds.lua was not changed";
            return false;
        }
        var newCall = "    hl.bind(" + expression + ", hl.dsp.exec_cmd(" + encodeLuaString(cleanCommand) + "))";
        var insertAt = closing.index;
        var updated = sourceText.slice(0, insertAt) + "\n" + newCall + "\n" + sourceText.slice(insertAt + 1);
        saveSource(updated, "Adding shortcut...");
        bindings = parseBindings(updated);
        return true;
    }

    function applyEdit() {
        if (dialogIsAdd)
            return addBinding(editKey, editCommand);

        if (!selectedBinding)
            return false;

        var replacements = [], b = selectedBinding;
        if (b.keyEditable && editKey.trim().length > 0 && editKey !== b.key) {
            var newKeyText = editKey.trim();
            var formattedKey = keyExpression(newKeyText);
            if (!formattedKey) {
                statusMessage = "Enter a valid key combination";
                return false;
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
            return false;
        }
        if (b.keyEditable && editKey.trim().length > 0 && editKey !== b.key) {
            var candidateKey = normalizedShortcut(editKey);
            for (var duplicateIndex = 0; duplicateIndex < bindings.length; duplicateIndex++) {
                var existing = bindings[duplicateIndex];
                if (existing === b || !existing.enabled)
                    continue;

                if (normalizedShortcut(existing.key) === candidateKey) {
                    statusMessage = "That shortcut is already assigned to another action";
                    return false;
                }
            }
        }
        replacements.sort(function(a, b) {
            return b.start - a.start;
        });
        var updated = sourceText;
        for (var i = 0; i < replacements.length; i++) {
            var r = replacements[i];
            updated = updated.slice(0, r.start) + r.text + updated.slice(r.end);
        }
        saveSource(updated, "Updating shortcut...");
        bindings = parseBindings(updated);
        return true;
    }

    function toggleBinding(binding) {
        if (!binding || !fileReady)
            return ;

        var updated;
        if (binding.enabled) {
            var start = binding.lineStart;
            var end = binding.lineEnd;
            if (start < 0 || end <= start || end > sourceText.length) {
                statusMessage = "Could not locate shortcut in keybinds.lua";
                return ;
            }
            var original = sourceText.slice(start, end);
            var commented = "-- KEYBIND_DISABLED_BEGIN\n" + original.split("\n").map(function(line) {
                return "-- " + line;
            }).join("\n") + "\n-- KEYBIND_DISABLED_END";
            updated = sourceText.slice(0, start) + commented + sourceText.slice(end);
            saveSource(updated, "Disabling shortcut...");
        } else {
            var blockStart = binding.blockStart;
            var blockEnd = binding.blockEnd;
            if (blockStart < 0 || blockEnd <= blockStart || blockEnd > sourceText.length) {
                statusMessage = "Could not locate disabled shortcut in keybinds.lua";
                return ;
            }
            var blockLines = sourceText.slice(blockStart, blockEnd).split("\n");
            if (blockLines.length < 3) {
                statusMessage = "Could not restore disabled shortcut";
                return ;
            }
            var restored = blockLines.slice(1, -1).map(function(line) {
                return line.indexOf("-- ") === 0 ? line.slice(3) : (line.indexOf("--") === 0 ? line.slice(2) : line);
            }).join("\n");
            updated = sourceText.slice(0, blockStart) + restored + sourceText.slice(blockEnd);
            saveSource(updated, "Enabling shortcut...");
        }
        bindings = parseBindings(updated);
    }

    function removeBinding(binding) {
        if (!binding || !fileReady)
            return ;

        var start = binding.enabled ? binding.lineStart : binding.blockStart;
        var end = binding.enabled ? binding.lineEnd : binding.blockEnd;
        if (start < 0 || end <= start || end > sourceText.length) {
            statusMessage = "Could not locate shortcut in keybinds.lua";
            return ;
        }
        if (end < sourceText.length && sourceText.charAt(end) === "\n")
            end++;
        else if (start > 0 && sourceText.charAt(start - 1) === "\n")
            start--;
        var updated = sourceText.slice(0, start) + sourceText.slice(end);
        saveSource(updated, "Removing shortcut...");
        bindings = parseBindings(updated);
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
            page.saveInProgress = false;
            if (page.queuedSave) {
                var nextText = page.queuedSaveText;
                var nextMessage = page.queuedSaveMessage;
                page.queuedSave = false;
                page.queuedSaveText = "";
                page.queuedSaveMessage = "";
                page.statusMessage = nextMessage;
                page.saveInProgress = true;
                keybindFile.setText(nextText);
                return ;
            }
            page.loadBindings(keybindFile.text());
            page.statusMessage = "Changes saved to keybinds.lua";
            if (page.closeEditorAfterSave) {
                page.closeEditorAfterSave = false;
                editDialog.close();
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
                keybindFile.setText(nextText);
                return ;
            }
            page.closeEditorAfterSave = false;
            page.statusMessage = "Could not save keybinds.lua; reloading saved file...";
            keybindFile.reload();
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
                    text: "KEYBINDS"
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 19
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
                implicitHeight: 28
                implicitWidth: 70
                enabled: page.fileReady
                onClicked: {
                    keybindFile.reload();
                    page.statusMessage = "Reloading shortcuts...";
                }

                background: Rectangle {
                    radius: 7
                    color: parent.hovered ? Theme.bgPanel : Theme.bgCard
                    border.width: 1
                    border.color: parent.hovered ? "#555555" : "#393939"
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
                text: "+ Add shortcut"
                implicitHeight: 28
                implicitWidth: 116
                enabled: page.fileReady
                onClicked: page.openAddDialog()

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
            placeholderText: "Search by shortcut, action or command..."
            color: Theme.text
            font.family: Theme.fontFamily
            selectByMouse: true
            onTextChanged: page.searchText = text

            background: Rectangle {
                color: Theme.alpha(Theme.text, 0.015)
                radius: 7
                border.width: 1
                border.color: parent.activeFocus ? Theme.accent : Theme.border
            }

        }

        Flickable {
            Layout.fillWidth: true
            implicitHeight: 40
            contentWidth: categoryRow.implicitWidth
            contentHeight: categoryRow.implicitHeight
            clip: true

            Row {
                id: categoryRow

                spacing: 8

                Repeater {
                    model: page.categories

                    delegate: Button {
                        required property string modelData

                        text: modelData
                        onClicked: page.categoryFilter = modelData
                        implicitHeight: 34
                        implicitWidth: Math.max(62, categoryLabel.implicitWidth + 26)
                        hoverEnabled: true

                        background: Rectangle {
                            radius: 9
                            color: page.categoryFilter === modelData ? Theme.alpha(Theme.accent, 0.15) : (parent.hovered ? Theme.alpha(Theme.accent, 0.05) : Theme.bgCard)
                            border.width: 1
                            border.color: page.categoryFilter === modelData ? Theme.accent : Theme.border

                            Behavior on color {
                                ColorAnimation {
                                    duration: 130
                                }

                            }

                        }

                        contentItem: Text {
                            id: categoryLabel

                            text: modelData
                            color: page.categoryFilter === modelData ? Theme.accent : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: page.categoryFilter === modelData ? Font.DemiBold : Font.Medium
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
                            Layout.preferredHeight: 100
                            radius: 10
                            color: cardHover.hovered ? Theme.alpha(Theme.accent, 0.05) : Theme.alpha(Theme.text, 0.015)
                            opacity: shortcutCard.modelData.enabled ? 1 : 0.58
                            border.width: 1
                            border.color: cardHover.hovered ? "#555555" : "#393939"

                            HoverHandler {
                                id: cardHover
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 7
                                        color: Theme.alpha(Theme.accent, 0.05)
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
                                            text: shortcutCard.modelData.enabled ? shortcutCard.modelData.category : shortcutCard.modelData.category + " · Disabled"
                                            color: Theme.textFaint
                                            font.family: Theme.monoFont
                                            font.pixelSize: 10
                                        }

                                    }

                                    Switch {
                                        id: bindingSwitch

                                        Layout.alignment: Qt.AlignVCenter
                                        checked: shortcutCard.modelData.enabled
                                        onToggled: page.toggleBinding(shortcutCard.modelData)

                                        indicator: Rectangle {
                                            implicitWidth: 38
                                            implicitHeight: 20
                                            radius: 7
                                            color: bindingSwitch.checked ? Theme.accent : Theme.bgPanel
                                            border.width: 1
                                            border.color: bindingSwitch.checked ? Qt.lighter(Theme.accent, 1.15) : "#393939"

                                            Rectangle {
                                                x: bindingSwitch.checked ? parent.width - width - 2 : 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 16
                                                height: 16
                                                radius: 8
                                                color: bindingSwitch.checked ? "#101116" : Theme.textFaint

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
                                        id: removeButton

                                        implicitWidth: 28
                                        implicitHeight: 28
                                        hoverEnabled: true
                                        onClicked: page.removeBinding(shortcutCard.modelData)
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Remove shortcut"
                                        ToolTip.delay: 500

                                        background: Rectangle {
                                            radius: 7
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

                                    Button {
                                        id: editButton

                                        implicitWidth: 28
                                        implicitHeight: 28
                                        hoverEnabled: true
                                        onClicked: page.openEditor(shortcutCard.modelData)
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Edit shortcut"
                                        ToolTip.delay: 500

                                        background: Rectangle {
                                            radius: 7
                                            color: editButton.hovered ? Theme.alpha(Theme.accent, 0.05) : "transparent"
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
                                            implicitHeight: 24
                                            radius: 7
                                            color: Theme.alpha(Theme.text, 0.03)
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

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 130
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
            color: "#111216"
            radius: 18
            border.width: 1
            border.color: Theme.border
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
                    radius: 10
                    color: "#2b2e37"
                    border.width: 1
                    border.color: Theme.border

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
                        text: page.dialogIsAdd ? "Add shortcut" : (page.selectedBinding ? page.selectedBinding.title : "Edit shortcut")
                        color: Theme.text
                        font.family: Theme.displayFont
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.dialogIsAdd ? "Create a new keybinding" : "Customize this keybinding"
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
                    visible: page.dialogIsAdd || (page.selectedBinding ? page.selectedBinding.keyEditable : false)

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
                        radius: 7
                        color: "#17191f"
                        border.width: keyField.activeFocus ? 1.5 : 1
                        border.color: keyField.activeFocus ? Theme.accent : Theme.border

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
                                placeholderText: "SUPER + T or ALT + TAB"
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
                        text: page.dialogIsAdd ? "Use SUPER, SHIFT, CTRL, ALT and the key name." : "Use SUPER, SHIFT, CTRL, ALT and the key name."
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
                    visible: page.dialogIsAdd || (page.selectedBinding ? page.selectedBinding.commandEditable : false)

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
                        radius: 7
                        color: "#17191f"
                        border.width: commandField.activeFocus ? 1.5 : 1
                        border.color: commandField.activeFocus ? Theme.accent : Theme.border

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
                                placeholderText: "e.g. waybar or wofi --show drun"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: page.editCommand = text
                                Keys.onReturnPressed: {
                                    if (page.applyEdit())
                                        page.closeEditorAfterSave = true;

                                }

                                background: Item {
                                }

                            }

                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        visible: page.dialogIsAdd
                        text: "The command runs when this key combination is pressed."
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
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
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                layoutDirection: Qt.RightToLeft
                Layout.margins: 16

                Button {
                    text: page.dialogIsAdd ? "Add shortcut" : "Save changes"
                    implicitHeight: 38
                    implicitWidth: 116
                    onClicked: {
                        if (page.applyEdit())
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
                    onClicked: editDialog.close()

                    background: Rectangle {
                        radius: 10
                        color: parent.hovered ? "#2b2e36" : "#24262d"
                        border.width: 1
                        border.color: parent.hovered ? Theme.accent : Theme.border
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
