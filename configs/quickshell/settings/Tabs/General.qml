import "../"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    readonly property string filePath: Quickshell.env("HOME") + "/.config/hypr/general.lua"
    property string sourceText: ""
    property bool fileReady: false
    property string statusMessage: "Loading general.lua..."
    property bool saveInProgress: false
    property bool queuedSave: false
    property string queuedSaveText: ""
    property bool dirty: false
    property bool applyAfterSave: false
    property string pendingLiveExpression: ""
    property string pendingLivePath: ""
    property string activeLivePath: ""
    property int gapsIn: 5
    property int gapsOut: 10
    property int borderSize: 0
    property bool resizeOnBorder: true
    property bool allowTearing: true
    property string layout: "scrolling"
    property string colActive: "rgb(bbbbbb)"
    property string colInactive: "rgb(666666)"
    property string scrollDirection: "right"
    property real columnWidth: 0.5
    property bool followFocus: true
    property bool fullscreenOnOneColumn: true
    property string explicitColumnWidths: ""
    property bool preserveSplit: true
    property string masterStatus: "master"
    property int rounding: 16
    property real activeOpacity: 0.9
    property real inactiveOpacity: 0.9
    property bool blurEnabled: true
    property int blurSize: 6
    property int blurPasses: 4
    property bool shadowEnabled: true
    property int shadowRange: 16
    property int shadowRenderPower: 6
    property bool disableLogo: true
    property bool forceZeroScaling: true

    function numRe(key) {
        return new RegExp("\\b" + key + "\\s*=\\s*(-?[\\d.]+)");
    }

    function intRe(key) {
        return new RegExp("\\b" + key + "\\s*=\\s*(-?\\d+)");
    }

    function boolRe(key) {
        return new RegExp("\\b" + key + "\\s*=\\s*(true|false)");
    }

    function strRe(key) {
        return new RegExp("\\b" + key + "\\s*=\\s*([\"'])([^\"']*)\\1");
    }

    function maskBlankRange(chars, start, end) {
        for (let k = start; k < end; k++) {
            if (chars[k] !== "\n" && chars[k] !== "\r")
                chars[k] = " ";

        }
    }

    function luaMask(text, hideStrings) {
        const chars = text.split("");
        let i = 0;
        while (i < text.length) {
            const ch = text.charAt(i);
            if (ch === "\"" || ch === "'") {
                const start = i;
                const quote = ch;
                i++;
                while (i < text.length) {
                    if (text.charAt(i) === "\\") {
                        i += 2;
                        continue;
                    }
                    if (text.charAt(i) === quote) {
                        i++;
                        break;
                    }
                    i++;
                }
                if (hideStrings)
                    page.maskBlankRange(chars, start, i);

                continue;
            }
            if (text.startsWith("--", i)) {
                const start = i;
                const longOpen = /^\[(=*)\[/.exec(text.slice(i + 2));
                if (longOpen) {
                    const closing = "]" + longOpen[1] + "]";
                    const contentStart = i + 2 + longOpen[0].length;
                    const closingIndex = text.indexOf(closing, contentStart);
                    i = closingIndex < 0 ? text.length : closingIndex + closing.length;
                } else {
                    const lineEnd = text.indexOf("\n", i);
                    i = lineEnd < 0 ? text.length : lineEnd;
                }
                page.maskBlankRange(chars, start, i);
                continue;
            }
            if (ch === "[") {
                const longOpen = /^\[(=*)\[/.exec(text.slice(i));
                if (longOpen) {
                    const start = i;
                    const closing = "]" + longOpen[1] + "]";
                    const contentStart = i + longOpen[0].length;
                    const closingIndex = text.indexOf(closing, contentStart);
                    i = closingIndex < 0 ? text.length : closingIndex + closing.length;
                    if (hideStrings)
                        page.maskBlankRange(chars, start, i);

                    continue;
                }
            }
            i++;
        }
        return chars.join("");
    }

    function findBlockIn(text, name) {
        const code = luaMask(text, true);
        const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const openRe = new RegExp("\\b" + escapedName + "\\s*=\\s*\\{");
        const match = openRe.exec(code);
        if (!match)
            return null;

        const start = match.index;
        const openIdx = match.index + match[0].length - 1;
        let depth = 0;
        let closeIdx = -1;
        for (let i = openIdx; i < code.length; i++) {
            const ch = code.charAt(i);
            if (ch === "{") {
                depth++;
            } else if (ch === "}") {
                depth--;
                if (depth === 0) {
                    closeIdx = i;
                    break;
                }
            }
        }
        if (closeIdx < 0)
            return null;

        return {
            "start": start,
            "bodyStart": openIdx + 1,
            "closeIdx": closeIdx,
            "body": text.slice(openIdx + 1, closeIdx),
            "full": text.slice(start, closeIdx + 1)
        };
    }

    function luaQuote(value) {
        return '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r/g, "\\r").replace(/\n/g, "\\n") + '"';
    }

    function luaLiteral(value) {
        if (typeof value === "boolean")
            return value ? "true" : "false";

        if (typeof value === "number")
            return isFinite(value) ? String(value) : "0";

        return luaQuote(value);
    }

    function luaField(key) {
        return /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? key : "[" + luaQuote(key) + "]";
    }

    function buildConfigExpression(path, value) {
        const deviceMatch = /^device\[(.*)\]:(.+)$/.exec(path);
        const renderedValue = luaLiteral(value);
        if (deviceMatch) {
            const fieldParts = deviceMatch[2].split(":").join(".").split(".");
            if (fieldParts.length !== 1)
                throw new Error("Unsupported device field: " + deviceMatch[2]);

            return "hl.device({ name = " + luaQuote(deviceMatch[1]) + ", " + luaField(fieldParts[0]) + " = " + renderedValue + " })";
        }
        const parts = [];
        const sections = path.split(":");
        for (let i = 0; i < sections.length; i++) {
            const sectionParts = sections[i].split(".");
            for (let j = 0; j < sectionParts.length; j++) parts.push(sectionParts[j])
        }
        if (parts.length < 2)
            throw new Error("Invalid config path: " + path);

        const category = parts.shift();
        let body = luaField(parts.pop()) + " = " + renderedValue;
        for (let i = parts.length - 1; i >= 0; i--) body = luaField(parts[i]) + " = { " + body + " }"
        return "hl.config({ " + luaField(category) + " = { " + body + " } })";
    }

    function startLiveApply() {
        if (liveApplyProcess.running || pendingLiveExpression === "")
            return ;

        const expression = pendingLiveExpression;
        activeLivePath = pendingLivePath;
        pendingLiveExpression = "";
        pendingLivePath = "";
        liveApplyProcess.command = ["hyprctl", "eval", expression];
        liveApplyProcess.running = true;
    }

    function applyLive(path, value) {
        try {
            pendingLiveExpression = buildConfigExpression(path, value);
            pendingLivePath = path;
            liveApplyTimer.restart();
        } catch (e) {
            statusMessage = "Could not prepare setting: " + path;
            console.warn("Settings: could not prepare live apply for " + path + ": " + e);
        }
    }

    function readValues(text) {
        let m;
        const cleanText = luaMask(text, false);
        const generalBlock = findBlockIn(text, "general");
        const generalScope = generalBlock ? luaMask(generalBlock.body, false) : cleanText;
        if ((m = generalScope.match(numRe("gaps_in"))))
            gapsIn = parseFloat(m[1]);

        if ((m = generalScope.match(numRe("gaps_out"))))
            gapsOut = parseFloat(m[1]);

        if ((m = generalScope.match(numRe("border_size"))))
            borderSize = parseFloat(m[1]);

        if ((m = generalScope.match(boolRe("resize_on_border"))))
            resizeOnBorder = m[1] === "true";

        if ((m = generalScope.match(boolRe("allow_tearing"))))
            allowTearing = m[1] === "true";

        if ((m = generalScope.match(strRe("layout"))))
            layout = m[2];

        const colBlock = findBlockIn(text, "col");
        if (colBlock) {
            const colScope = luaMask(colBlock.body, false);
            let cm;
            if ((cm = colScope.match(strRe("active_border")))) {
                colActive = cm[2];
            } else {
                const activeBlock = findBlockIn(colBlock.body, "active_border");
                if (activeBlock) {
                    const colorMatch = luaMask(activeBlock.body, false).match(/(["'])(rgba?\([^"']+\))\1/i);
                    if (colorMatch)
                        colActive = colorMatch[2];

                }
            }
            if ((cm = colScope.match(strRe("inactive_border")))) {
                colInactive = cm[2];
            } else {
                const inactiveBlock = findBlockIn(colBlock.body, "inactive_border");
                if (inactiveBlock) {
                    const colorMatch = luaMask(inactiveBlock.body, false).match(/(["'])(rgba?\([^"']+\))\1/i);
                    if (colorMatch)
                        colInactive = colorMatch[2];

                }
            }
        }
        const scrollingBlock = findBlockIn(text, "scrolling");
        if (scrollingBlock) {
            const scrollingScope = luaMask(scrollingBlock.body, false);
            let scm;
            if ((scm = scrollingScope.match(strRe("direction"))))
                scrollDirection = scm[2];

            if ((scm = scrollingScope.match(numRe("column_width"))))
                columnWidth = parseFloat(scm[1]);

            if ((scm = scrollingScope.match(boolRe("follow_focus"))))
                followFocus = scm[1] === "true";

            if ((scm = scrollingScope.match(boolRe("fullscreen_on_one_column"))))
                fullscreenOnOneColumn = scm[1] === "true";

            if ((scm = scrollingScope.match(strRe("explicit_column_widths"))))
                explicitColumnWidths = scm[2];

        }
        const dwindleBlock = findBlockIn(text, "dwindle");
        if (dwindleBlock) {
            const dwindleScope = luaMask(dwindleBlock.body, false);
            let dm;
            if ((dm = dwindleScope.match(boolRe("preserve_split"))))
                preserveSplit = dm[1] === "true";

        }
        const masterBlock = findBlockIn(text, "master");
        if (masterBlock) {
            const masterScope = luaMask(masterBlock.body, false);
            let mm;
            if ((mm = masterScope.match(strRe("new_status"))))
                masterStatus = mm[2];

        }
        const decorationBlock = findBlockIn(text, "decoration");
        if (decorationBlock) {
            const decorationScope = luaMask(decorationBlock.body, false);
            let decm;
            if ((decm = decorationScope.match(numRe("rounding"))))
                rounding = parseFloat(decm[1]);

            if ((decm = decorationScope.match(numRe("active_opacity"))))
                activeOpacity = parseFloat(decm[1]);

            if ((decm = decorationScope.match(numRe("inactive_opacity"))))
                inactiveOpacity = parseFloat(decm[1]);

        }
        const blurBlock = findBlockIn(text, "blur");
        if (blurBlock) {
            const blurScope = luaMask(blurBlock.body, false);
            let bm;
            if ((bm = blurScope.match(boolRe("enabled"))))
                blurEnabled = bm[1] === "true";

            if ((bm = blurScope.match(intRe("size"))))
                blurSize = parseInt(bm[1]);

            if ((bm = blurScope.match(intRe("passes"))))
                blurPasses = parseInt(bm[1]);

        }
        const shadowBlock = findBlockIn(text, "shadow");
        if (shadowBlock) {
            const shadowScope = luaMask(shadowBlock.body, false);
            let sm;
            if ((sm = shadowScope.match(boolRe("enabled"))))
                shadowEnabled = sm[1] === "true";

            if ((sm = shadowScope.match(intRe("range"))))
                shadowRange = parseInt(sm[1]);

            if ((sm = shadowScope.match(intRe("render_power"))))
                shadowRenderPower = parseInt(sm[1]);

        }
        if ((m = cleanText.match(boolRe("disable_hyprland_logo"))))
            disableLogo = m[1] === "true";

        if ((m = cleanText.match(boolRe("force_zero_scaling"))))
            forceZeroScaling = m[1] === "true";

    }

    function replaceInBlock(blockText, key, rendered, isBool, isStr, isInt) {
        const code = luaMask(blockText, true);
        const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const assignmentRe = new RegExp("^" + escapedKey + "\\s*=");
        let equalsAt = -1;
        let braces = 0;
        let brackets = 0;
        let parentheses = 0;
        for (let i = 0; i < code.length; i++) {
            if (braces === 0 && brackets === 0 && parentheses === 0 && (i === 0 || !/[A-Za-z0-9_]/.test(code.charAt(i - 1))) && /[A-Za-z_]/.test(code.charAt(i))) {
                const match = assignmentRe.exec(code.slice(i));
                if (match) {
                    equalsAt = i + match[0].lastIndexOf("=");
                    break;
                }
            }
            const ch = code.charAt(i);
            if (ch === "{")
                braces++;
            else if (ch === "}")
                braces = Math.max(0, braces - 1);
            else if (ch === "[")
                brackets++;
            else if (ch === "]")
                brackets = Math.max(0, brackets - 1);
            else if (ch === "(")
                parentheses++;
            else if (ch === ")")
                parentheses = Math.max(0, parentheses - 1);
        }
        if (equalsAt >= 0) {
            let valueStart = equalsAt + 1;
            while (valueStart < blockText.length && /\s/.test(blockText.charAt(valueStart)))valueStart++
            let valueEnd = blockText.length;
            braces = 0;
            brackets = 0;
            parentheses = 0;
            for (let i = valueStart; i < code.length; i++) {
                const ch = code.charAt(i);
                if ((ch === "," || ch === ";") && braces === 0 && brackets === 0 && parentheses === 0) {
                    valueEnd = i;
                    break;
                }
                if (ch === "{")
                    braces++;
                else if (ch === "}")
                    braces = Math.max(0, braces - 1);
                else if (ch === "[")
                    brackets++;
                else if (ch === "]")
                    brackets = Math.max(0, brackets - 1);
                else if (ch === "(")
                    parentheses++;
                else if (ch === ")")
                    parentheses = Math.max(0, parentheses - 1);
            }
            while (valueEnd > valueStart && /\s/.test(blockText.charAt(valueEnd - 1)))valueEnd--
            return blockText.slice(0, valueStart) + rendered + blockText.slice(valueEnd);
        }
        return "\n        " + key + " = " + rendered + "," + blockText;
    }

    function setBlockField(blockName, key, value, isBool, isStr, isInt) {
        if (!fileReady)
            return ;

        let rendered;
        if (isBool)
            rendered = String(value);
        else if (isStr)
            rendered = '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
        else if (isInt)
            rendered = String(Math.round(Number(value)));
        else
            rendered = Number(value).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
        const block = findBlockIn(sourceText, blockName);
        if (!block) {
            let configEntry;
            if (blockName === "col")
                configEntry = "general = {\n        col = {\n            " + key + " = " + rendered + ",\n        },\n    },";
            else if (blockName === "blur" || blockName === "shadow")
                configEntry = "decoration = {\n        " + blockName + " = {\n            " + key + " = " + rendered + ",\n        },\n    },";
            else
                configEntry = blockName + " = {\n        " + key + " = " + rendered + ",\n    },";
            sourceText += (sourceText.endsWith("\n") ? "\n" : "\n\n") + "hl.config({\n    " + configEntry + "\n})\n";
        } else {
            const newBody = replaceInBlock(block.body, key, rendered, isBool, isStr, isInt);
            sourceText = sourceText.slice(0, block.bodyStart) + newBody + sourceText.slice(block.closeIdx);
        }
        readValues(sourceText);
        dirty = true;
        applyAfterSave = true;
        scheduleSave();
    }

    function scheduleSave() {
        statusMessage = "Saving general.lua...";
        saveTimer.restart();
    }

    function runApply() {
        reloadProcess.command = ["hyprctl", "reload"];
        reloadProcess.running = true;
        statusMessage = "Reloading Hyprland...";
    }

    function forceApply() {
        if (dirty || saveInProgress || saveTimer.running) {
            applyAfterSave = true;
            statusMessage = "Saving changes before applying...";
            if (dirty && !saveInProgress && !saveTimer.running)
                saveTimer.restart();

            return ;
        }
        runApply();
    }

    function forceReloadFile() {
        generalFile.reload();
        statusMessage = "Reloading general.lua...";
    }

    Timer {
        id: saveTimer

        interval: 250
        repeat: false
        onTriggered: {
            if (!dirty)
                return ;

            if (saveInProgress) {
                queuedSave = true;
                queuedSaveText = sourceText;
                return ;
            }
            saveInProgress = true;
            generalFile.setText(sourceText);
        }
    }

    Timer {
        id: liveApplyTimer

        interval: 35
        repeat: false
        onTriggered: page.startLiveApply()
    }

    Process {
        id: liveApplyProcess

        onExited: (code) => {
            if (code !== 0) {
                page.statusMessage = "Live apply failed: " + page.activeLivePath;
                console.warn("Settings: hyprctl eval exited with " + code + " for " + page.activeLivePath);
            }
            if (page.pendingLiveExpression !== "")
                page.startLiveApply();

        }

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output && /(error|failed|invalid|unknown)/i.test(output)) {
                    page.statusMessage = "Live apply reported an error: " + page.activeLivePath;
                    console.warn("Settings: live apply output for " + page.activeLivePath + ": " + output);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output) {
                    page.statusMessage = "Live apply reported an error: " + page.activeLivePath;
                    console.warn("Settings: live apply error for " + page.activeLivePath + ": " + output);
                }
            }
        }

    }

    FileView {
        id: generalFile

        path: page.filePath
        preload: true
        watchChanges: false
        atomicWrites: true
        onLoaded: {
            try {
                page.sourceText = generalFile.text();
                page.readValues(page.sourceText);
                page.fileReady = true;
                page.statusMessage = "general.lua loaded";
            } catch (e) {
                page.fileReady = false;
                page.statusMessage = "Error: " + e.message;
            }
        }
        onLoadFailed: (error) => {
            page.fileReady = false;
            page.statusMessage = "Unable to load general.lua: " + error;
            console.warn("General: could not load " + page.filePath + ": " + error);
        }
        onSaved: {
            page.saveInProgress = false;
            if (page.queuedSave) {
                const next = page.queuedSaveText;
                page.queuedSave = false;
                page.queuedSaveText = "";
                page.saveInProgress = true;
                generalFile.setText(next);
                return ;
            }
            page.dirty = false;
            page.sourceText = generalFile.text();
            try {
                page.readValues(page.sourceText);
            } catch (e) {
            }
            if (page.applyAfterSave) {
                page.applyAfterSave = false;
                page.runApply();
            } else {
                page.statusMessage = "Saved";
            }
        }
        onSaveFailed: (error) => {
            page.saveInProgress = false;
            page.applyAfterSave = false;
            page.statusMessage = "Could not save general.lua: " + error;
            console.warn("General: could not save " + page.filePath + ": " + error);
        }
    }

    Process {
        id: reloadProcess

        onExited: (code) => {
            page.statusMessage = code === 0 ? "Applied" : "hyprctl reload failed";
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content

            width: parent.width
            spacing: 10

            Row {
                width: parent.width
                height: 26
                spacing: 8

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    color: page.fileReady ? (page.dirty ? "#e5b567" : Theme.ok) : Theme.danger
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: parent.width - 160
                    text: page.statusMessage
                    color: Theme.textFaint
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: reloadBtnG.width + 12
                    height: 22
                    radius: Theme.radiusXs
                    color: reloadBtnG.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                    border.width: 1
                    border.color: reloadBtnG.containsMouse ? Theme.accent : Theme.border
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: reloadBtnG

                        property bool containsMouse: false

                        anchors.centerIn: parent
                        text: "RELOAD"
                        color: Theme.textDim
                        font.family: Theme.monoFont
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: reloadBtnG.containsMouse = true
                        onExited: reloadBtnG.containsMouse = false
                        onClicked: page.forceReloadFile()
                    }

                }

                Rectangle {
                    width: applyBtnG.width + 12
                    height: 22
                    radius: Theme.radiusXs
                    color: applyBtnG.containsMouse ? Theme.alpha(Theme.accent, 0.12) : Theme.alpha(Theme.accent, 0.06)
                    border.width: 1
                    border.color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: applyBtnG

                        property bool containsMouse: false

                        anchors.centerIn: parent
                        text: "APPLY"
                        color: Theme.accent
                        font.family: Theme.monoFont
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: applyBtnG.containsMouse = true
                        onExited: applyBtnG.containsMouse = false
                        onClicked: page.forceApply()
                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Text {
                text: "GAPS"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                topPadding: 4
            }

            SliderRow {
                icon: "\uf0c8"
                label: "GAPS IN"
                value: Math.min(1, page.gapsIn / 40)
                displayText: page.gapsIn + "px"
                resettable: true
                resetValue: 5 / 40
                onMoved: (v) => {
                    page.gapsIn = Math.round(v * 40);
                    page.applyLive("general:gaps_in", page.gapsIn);
                    page.setBlockField("general", "gaps_in", page.gapsIn, false, false, true);
                }
                onCommitted: (v) => {
                    page.gapsIn = Math.round(v * 40);
                    page.setBlockField("general", "gaps_in", page.gapsIn, false, false, true);
                }
            }

            SliderRow {
                icon: "\uf0c8"
                label: "GAPS OUT"
                value: Math.min(1, page.gapsOut / 80)
                displayText: page.gapsOut + "px"
                resettable: true
                resetValue: 10 / 80
                onMoved: (v) => {
                    page.gapsOut = Math.round(v * 80);
                    page.applyLive("general:gaps_out", page.gapsOut);
                    page.setBlockField("general", "gaps_out", page.gapsOut, false, false, true);
                }
                onCommitted: (v) => {
                    page.gapsOut = Math.round(v * 80);
                    page.setBlockField("general", "gaps_out", page.gapsOut, false, false, true);
                }
            }

            SliderRow {
                icon: "\uf0c8"
                label: "BORDER SIZE"
                value: Math.min(1, page.borderSize / 10)
                displayText: page.borderSize + "px"
                resettable: true
                resetValue: 0
                onMoved: (v) => {
                    page.borderSize = Math.round(v * 10);
                    page.applyLive("general:border_size", page.borderSize);
                    page.setBlockField("general", "border_size", page.borderSize, false, false, true);
                }
                onCommitted: (v) => {
                    page.borderSize = Math.round(v * 10);
                    page.setBlockField("general", "border_size", page.borderSize, false, false, true);
                }
            }

            ToggleRow {
                label: "RESIZE ON BORDER"
                checked: page.resizeOnBorder
                onToggled: (c) => {
                    page.applyLive("general:resize_on_border", c);
                    page.setBlockField("general", "resize_on_border", c, true);
                }
            }

            ToggleRow {
                label: "ALLOW TEARING"
                checked: page.allowTearing
                onToggled: (c) => {
                    page.applyLive("general:allow_tearing", c);
                    page.setBlockField("general", "allow_tearing", c, true);
                }
            }

            ColorRow {
                label: "ACTIVE BORDER"
                colorValue: page.colActive
                onClicked: colorPopup.openFor("active")
            }

            ColorRow {
                label: "INACTIVE BORDER"
                colorValue: page.colInactive
                onClicked: colorPopup.openFor("inactive")
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                anchors.topMargin: 4
            }

            Text {
                text: "LAYOUT"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                topPadding: 4
            }

            Text {
                text: "GENERAL LAYOUT"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.2
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: ["scrolling", "dwindle", "master"]

                    delegate: Segment {
                        required property string modelData

                        label: modelData.toUpperCase()
                        selected: page.layout === modelData
                        onClicked: {
                            page.layout = modelData;
                            page.applyLive("general:layout", modelData);
                            page.setBlockField("general", "layout", modelData, false, true);
                        }
                    }

                }

            }

            Text {
                text: "SCROLL DIRECTION"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.2
                topPadding: 4
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: ["left", "right", "up", "down"]

                    delegate: Segment {
                        required property string modelData

                        label: modelData.toUpperCase()
                        selected: page.scrollDirection === modelData
                        onClicked: {
                            page.scrollDirection = modelData;
                            page.applyLive("scrolling:direction", modelData);
                            page.setBlockField("scrolling", "direction", modelData, false, true);
                        }
                    }

                }

            }

            SliderRow {
                icon: "\uf0c8"
                label: "COLUMN WIDTH"
                value: page.columnWidth
                displayText: page.columnWidth.toFixed(2)
                resettable: true
                resetValue: 0.5
                onMoved: (v) => {
                    page.columnWidth = v;
                    page.applyLive("scrolling:column_width", v);
                    page.setBlockField("scrolling", "column_width", v);
                }
                onCommitted: (v) => {
                    page.columnWidth = v;
                    page.setBlockField("scrolling", "column_width", v);
                }
            }

            ToggleRow {
                label: "FOLLOW FOCUS"
                checked: page.followFocus
                onToggled: (c) => {
                    page.applyLive("scrolling:follow_focus", c);
                    page.setBlockField("scrolling", "follow_focus", c, true);
                }
            }

            ToggleRow {
                label: "FULLSCREEN ON ONE COLUMN"
                checked: page.fullscreenOnOneColumn
                onToggled: (c) => {
                    page.applyLive("scrolling:fullscreen_on_one_column", c);
                    page.setBlockField("scrolling", "fullscreen_on_one_column", c, true);
                }
            }

            Text {
                text: "EXPLICIT COLUMN WIDTHS"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.2
                topPadding: 4
            }

            WidthChips {
                value: page.explicitColumnWidths
                onChanged: (v) => {
                    page.explicitColumnWidths = v;
                    page.applyLive("scrolling:explicit_column_widths", v);
                    page.setBlockField("scrolling", "explicit_column_widths", v, false, true);
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                anchors.topMargin: 4
            }

            Text {
                text: "DWINDLE / MASTER"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                topPadding: 4
            }

            ToggleRow {
                label: "DWINDLE PRESERVE SPLIT"
                checked: page.preserveSplit
                onToggled: (c) => {
                    page.applyLive("dwindle:preserve_split", c);
                    page.setBlockField("dwindle", "preserve_split", c, true);
                }
            }

            Text {
                text: "MASTER NEW STATUS"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.2
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: ["master", "slave", "inherit"]

                    delegate: Segment {
                        required property string modelData

                        label: modelData.toUpperCase()
                        selected: page.masterStatus === modelData
                        onClicked: {
                            page.masterStatus = modelData;
                            page.applyLive("master:new_status", modelData);
                            page.setBlockField("master", "new_status", modelData, false, true);
                        }
                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                anchors.topMargin: 4
            }

            Text {
                text: "DECORATION"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                topPadding: 4
            }

            SliderRow {
                icon: "\uf0c8"
                label: "ROUNDING"
                value: Math.min(1, page.rounding / 30)
                displayText: page.rounding + "px"
                resettable: true
                resetValue: 16 / 30
                onMoved: (v) => {
                    page.rounding = Math.round(v * 30);
                    page.applyLive("decoration:rounding", page.rounding);
                    page.setBlockField("decoration", "rounding", page.rounding, false, false, true);
                }
                onCommitted: (v) => {
                    page.rounding = Math.round(v * 30);
                    page.setBlockField("decoration", "rounding", page.rounding, false, false, true);
                }
            }

            SliderRow {
                icon: "\uf06e"
                label: "ACTIVE OPACITY"
                value: page.activeOpacity
                displayText: (page.activeOpacity * 100).toFixed(0) + "%"
                resettable: true
                resetValue: 1
                onMoved: (v) => {
                    page.activeOpacity = v;
                    page.applyLive("decoration:active_opacity", v);
                    page.setBlockField("decoration", "active_opacity", v);
                }
                onCommitted: (v) => {
                    page.activeOpacity = v;
                    page.setBlockField("decoration", "active_opacity", v);
                }
            }

            SliderRow {
                icon: "\uf070"
                label: "INACTIVE OPACITY"
                value: page.inactiveOpacity
                displayText: (page.inactiveOpacity * 100).toFixed(0) + "%"
                resettable: true
                resetValue: 1
                onMoved: (v) => {
                    page.inactiveOpacity = v;
                    page.applyLive("decoration:inactive_opacity", v);
                    page.setBlockField("decoration", "inactive_opacity", v);
                }
                onCommitted: (v) => {
                    page.inactiveOpacity = v;
                    page.setBlockField("decoration", "inactive_opacity", v);
                }
            }

            Text {
                text: "BLUR"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.2
                topPadding: 4
            }

            ToggleRow {
                label: "BLUR ENABLED"
                checked: page.blurEnabled
                onToggled: (c) => {
                    page.applyLive("decoration:blur:enabled", c);
                    page.setBlockField("blur", "enabled", c, true);
                }
            }

            SliderRow {
                icon: "\uf0c8"
                label: "BLUR SIZE"
                value: Math.min(1, page.blurSize / 20)
                displayText: page.blurSize + "px"
                resettable: true
                resetValue: 6 / 20
                onMoved: (v) => {
                    page.blurSize = Math.round(v * 20);
                    page.applyLive("decoration:blur:size", page.blurSize);
                    page.setBlockField("blur", "size", page.blurSize, false, false, true);
                }
                onCommitted: (v) => {
                    page.blurSize = Math.round(v * 20);
                    page.setBlockField("blur", "size", page.blurSize, false, false, true);
                }
            }

            SliderRow {
                icon: "\uf0c8"
                label: "BLUR PASSES"
                value: Math.min(1, page.blurPasses / 10)
                displayText: String(page.blurPasses)
                resettable: true
                resetValue: 4 / 10
                onMoved: (v) => {
                    page.blurPasses = Math.round(v * 10);
                    page.applyLive("decoration:blur:passes", page.blurPasses);
                    page.setBlockField("blur", "passes", page.blurPasses, false, false, true);
                }
                onCommitted: (v) => {
                    page.blurPasses = Math.round(v * 10);
                    page.setBlockField("blur", "passes", page.blurPasses, false, false, true);
                }
            }

            Text {
                text: "SHADOW"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.2
                topPadding: 4
            }

            ToggleRow {
                label: "SHADOW ENABLED"
                checked: page.shadowEnabled
                onToggled: (c) => {
                    page.applyLive("decoration:shadow:enabled", c);
                    page.setBlockField("shadow", "enabled", c, true);
                }
            }

            SliderRow {
                icon: "\uf0c8"
                label: "SHADOW RANGE"
                value: Math.min(1, page.shadowRange / 40)
                displayText: page.shadowRange + "px"
                resettable: true
                resetValue: 16 / 40
                onMoved: (v) => {
                    page.shadowRange = Math.round(v * 40);
                    page.applyLive("decoration:shadow:range", page.shadowRange);
                    page.setBlockField("shadow", "range", page.shadowRange, false, false, true);
                }
                onCommitted: (v) => {
                    page.shadowRange = Math.round(v * 40);
                    page.setBlockField("shadow", "range", page.shadowRange, false, false, true);
                }
            }

            SliderRow {
                icon: "\uf0c8"
                label: "SHADOW RENDER POWER"
                value: Math.min(1, page.shadowRenderPower / 10)
                displayText: String(page.shadowRenderPower)
                resettable: true
                resetValue: 6 / 10
                onMoved: (v) => {
                    page.shadowRenderPower = Math.round(v * 10);
                    page.applyLive("decoration:shadow:render_power", page.shadowRenderPower);
                    page.setBlockField("shadow", "render_power", page.shadowRenderPower, false, false, true);
                }
                onCommitted: (v) => {
                    page.shadowRenderPower = Math.round(v * 10);
                    page.setBlockField("shadow", "render_power", page.shadowRenderPower, false, false, true);
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                anchors.topMargin: 4
            }

            Text {
                text: "MISC / XWAYLAND"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                topPadding: 4
            }

            ToggleRow {
                label: "DISABLE HYPRLAND LOGO"
                checked: page.disableLogo
                onToggled: (c) => {
                    page.applyLive("misc:disable_hyprland_logo", c);
                    page.setBlockField("misc", "disable_hyprland_logo", c, true);
                }
            }

            ToggleRow {
                label: "XWAYLAND FORCE ZERO SCALING"
                checked: page.forceZeroScaling
                onToggled: (c) => {
                    page.applyLive("xwayland:force_zero_scaling", c);
                    page.setBlockField("xwayland", "force_zero_scaling", c, true);
                }
            }

        }

    }

    Popup {
        id: colorPopup

        property string target: "active"
        property real hue: 0
        property real sat: 1
        property real light: 0.5
        readonly property color previewColor: Qt.hsla(hue, sat, light, 1)

        function parseColor(str) {
            var m = str.match(/rgb\(([0-9a-fA-F]{6})\)/i) || str.match(/#([0-9a-fA-F]{6})/);
            if (m) {
                var c = Qt.color("#" + m[1]);
                hue = c.hslHue;
                sat = c.hslSaturation;
                light = c.hslLightness;
            }
        }

        function colorString() {
            function hex2(n) {
                var s = Math.round(n).toString(16);
                return s.length === 1 ? "0" + s : s;
            }

            var c = previewColor;
            return "rgb(" + hex2(c.r * 255) + hex2(c.g * 255) + hex2(c.b * 255) + ")";
        }

        function previewLive() {
            var str = colorString();
            if (target === "active") {
                page.colActive = str;
                page.applyLive("general:col.active_border", str);
            } else {
                page.colInactive = str;
                page.applyLive("general:col.inactive_border", str);
            }
        }

        function openFor(t) {
            target = t;
            if (t === "active")
                parseColor(page.colActive || "rgb(ffffff)");
            else
                parseColor(page.colInactive || "rgb(666666)");
            visible = true;
        }

        modal: true
        anchors.centerIn: Overlay.overlay
        width: 340
        height: 340
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#202228"
            radius: 18
            border.width: 1
            border.color: "#3a3d46"
        }

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Row {
                width: parent.width
                spacing: 14

                Rectangle {
                    width: 56
                    height: 56
                    radius: 10
                    color: colorPopup.previewColor
                    border.width: 1
                    border.color: "#444853"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: colorPopup.target === "active" ? "ACTIVE BORDER" : "INACTIVE BORDER"
                        color: "#888"
                        font.family: Theme.monoFont
                        font.pixelSize: 9
                        font.letterSpacing: 2
                    }

                    Text {
                        text: colorPopup.colorString()
                        color: "#fff"
                        font.family: Theme.monoFont
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        text: "drag to preview live"
                        color: "#666"
                        font.family: Theme.monoFont
                        font.pixelSize: 9
                        font.italic: true
                    }

                }

            }

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "HUE"
                    color: "#888"
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    width: parent.width
                    height: 22
                    radius: 5

                    Rectangle {
                        x: parent.width * colorPopup.hue - width / 2
                        y: -2
                        width: 4
                        height: parent.height + 4
                        radius: 2
                        color: "white"
                        border.color: "black"
                        border.width: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: (m) => {
                            colorPopup.hue = Math.max(0, Math.min(1, m.x / width));
                            colorPopup.previewLive();
                        }
                        onPositionChanged: (m) => {
                            if (pressed) {
                                colorPopup.hue = Math.max(0, Math.min(1, m.x / width));
                                colorPopup.previewLive();
                            }
                        }
                    }

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: "#ff0000"
                        }

                        GradientStop {
                            position: 0.166
                            color: "#ffff00"
                        }

                        GradientStop {
                            position: 0.333
                            color: "#00ff00"
                        }

                        GradientStop {
                            position: 0.5
                            color: "#00ffff"
                        }

                        GradientStop {
                            position: 0.666
                            color: "#0000ff"
                        }

                        GradientStop {
                            position: 0.833
                            color: "#ff00ff"
                        }

                        GradientStop {
                            position: 1
                            color: "#ff0000"
                        }

                    }

                }

            }

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "SATURATION"
                    color: "#888"
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    width: parent.width
                    height: 22
                    radius: 5

                    Rectangle {
                        x: parent.width * colorPopup.sat - width / 2
                        y: -2
                        width: 4
                        height: parent.height + 4
                        radius: 2
                        color: "white"
                        border.color: "black"
                        border.width: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: (m) => {
                            colorPopup.sat = Math.max(0, Math.min(1, m.x / width));
                            colorPopup.previewLive();
                        }
                        onPositionChanged: (m) => {
                            if (pressed) {
                                colorPopup.sat = Math.max(0, Math.min(1, m.x / width));
                                colorPopup.previewLive();
                            }
                        }
                    }

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: Qt.hsla(colorPopup.hue, 0, colorPopup.light, 1)
                        }

                        GradientStop {
                            position: 1
                            color: Qt.hsla(colorPopup.hue, 1, colorPopup.light, 1)
                        }

                    }

                }

            }

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "LIGHTNESS"
                    color: "#888"
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    width: parent.width
                    height: 22
                    radius: 5

                    Rectangle {
                        x: parent.width * colorPopup.light - width / 2
                        y: -2
                        width: 4
                        height: parent.height + 4
                        radius: 2
                        color: "white"
                        border.color: "black"
                        border.width: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: (m) => {
                            colorPopup.light = Math.max(0, Math.min(1, m.x / width));
                            colorPopup.previewLive();
                        }
                        onPositionChanged: (m) => {
                            if (pressed) {
                                colorPopup.light = Math.max(0, Math.min(1, m.x / width));
                                colorPopup.previewLive();
                            }
                        }
                    }

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: "#000000"
                        }

                        GradientStop {
                            position: 0.5
                            color: Qt.hsla(colorPopup.hue, colorPopup.sat, 0.5, 1)
                        }

                        GradientStop {
                            position: 1
                            color: "#ffffff"
                        }

                    }

                }

            }

            Item {
                width: parent.width
                height: 1
            }

            Row {
                width: parent.width
                spacing: 10
                layoutDirection: Qt.RightToLeft

                Rectangle {
                    width: 100
                    height: 34
                    radius: 9
                    color: applyClick.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                    border.width: 1
                    border.color: Qt.lighter(Theme.accent, 1.12)

                    Text {
                        anchors.centerIn: parent
                        text: "APPLY"
                        color: "#101116"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: applyClick

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var str = colorPopup.colorString();
                            if (colorPopup.target === "active") {
                                page.colActive = str;
                                page.applyLive("general:col.active_border", str);
                                page.setBlockField("col", "active_border", str, false, true);
                            } else {
                                page.colInactive = str;
                                page.applyLive("general:col.inactive_border", str);
                                page.setBlockField("col", "inactive_border", str, false, true);
                            }
                            colorPopup.visible = false;
                        }
                    }

                }

                Rectangle {
                    width: 90
                    height: 34
                    radius: 9
                    color: cancelClick.containsMouse ? "#2b2e36" : "#24262d"
                    border.width: 1
                    border.color: "#41444e"

                    Text {
                        anchors.centerIn: parent
                        text: "CANCEL"
                        color: Theme.textSoft
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: cancelClick

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (colorPopup.target === "active")
                                page.applyLive("general:col.active_border", page.colActive);
                            else
                                page.applyLive("general:col.inactive_border", page.colInactive);
                            colorPopup.visible = false;
                        }
                    }

                }

            }

        }

    }

    component ColorRow: Item {
        id: colorRowRoot

        property string label: ""
        property string colorValue: ""

        signal clicked()

        width: parent.width
        height: 38

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            width: 130
            text: colorRowRoot.label
            color: Theme.textDim
            font.family: Theme.monoFont
            font.pixelSize: 10
            font.letterSpacing: 1
            elide: Text.ElideRight
        }

        Rectangle {
            id: swatch

            anchors.left: parent.left
            anchors.leftMargin: 172
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 6
            color: {
                var rgba = colorRowRoot.colorValue.match(/rgba\(([0-9a-fA-F]{8})\)/i);
                if (rgba) {
                    var hex = rgba[1];
                    return Qt.rgba(parseInt(hex.slice(0, 2), 16) / 255, parseInt(hex.slice(2, 4), 16) / 255, parseInt(hex.slice(4, 6), 16) / 255, parseInt(hex.slice(6, 8), 16) / 255);
                }
                var rgb = colorRowRoot.colorValue.match(/rgb\(([0-9a-fA-F]{6})\)/i) || colorRowRoot.colorValue.match(/#([0-9a-fA-F]{6})/);
                return rgb ? Qt.color("#" + rgb[1]) : "#ffffff";
            }
            border.width: 1
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: colorRowRoot.clicked()
            }

        }

        Rectangle {
            anchors.left: swatch.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusSm
            color: rowHover.containsMouse ? Theme.bgElev : Theme.bgCard
            border.width: 1
            border.color: rowHover.containsMouse ? Theme.accent : Theme.border

            HoverHandler {
                id: rowHover
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: colorRowRoot.colorValue
                color: Theme.text
                font.family: Theme.monoFont
                font.pixelSize: 12
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf0d7"
                color: rowHover.containsMouse ? Theme.accent : Theme.textGhost
                font.family: Theme.iconFont
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: colorRowRoot.clicked()
            }

        }

    }

    component WidthChips: Item {
        id: chipsRoot

        property string value: ""
        property var widths: []

        signal changed(string newValue)

        function parseWidths() {
            if (value === "") {
                widths = [];
                return ;
            }
            var parts = value.split(",").map(function(s) {
                return s.trim();
            }).filter(function(s) {
                return s !== "";
            });
            widths = parts.map(function(s) {
                return parseFloat(s);
            }).filter(function(n) {
                return !isNaN(n);
            });
        }

        function buildString() {
            return widths.map(function(n) {
                var s = Number(n).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
                return s === "" ? "0" : s;
            }).join(",");
        }

        function updateAt(idx, newVal) {
            if (idx < 0 || idx >= widths.length)
                return ;

            var arr = widths.slice();
            arr[idx] = newVal;
            widths = arr;
            changed(buildString());
        }

        function removeAt(idx) {
            if (idx < 0 || idx >= widths.length)
                return ;

            var arr = widths.slice();
            arr.splice(idx, 1);
            widths = arr;
            changed(buildString());
        }

        function add() {
            var arr = widths.slice();
            arr.push(0.5);
            widths = arr;
            changed(buildString());
        }

        width: parent.width
        height: 40
        onValueChanged: parseWidths()
        Component.onCompleted: parseWidths()

        Flow {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: chipsRoot.widths

                delegate: Item {
                    id: chip

                    required property real modelData
                    required property int index
                    property bool editing: false

                    width: editing ? 90 : (chipLabel.implicitWidth + 38)
                    height: 32

                    Rectangle {
                        visible: !chip.editing
                        anchors.fill: parent
                        radius: 8
                        color: chipMouse.containsMouse ? Theme.bgElev : Theme.bgCard
                        border.width: 1
                        border.color: chipMouse.containsMouse ? Theme.accent : Theme.border

                        Text {
                            id: chipLabel

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var s = Number(chip.modelData).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
                                return s === "" ? "0" : s;
                            }
                            color: Theme.text
                            font.family: Theme.monoFont
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Rectangle {
                            visible: chipMouse.containsMouse
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 4
                            color: removeHover.containsMouse ? Theme.alpha("#ff5555", 0.2) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: removeHover.containsMouse ? "#ff5555" : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                            }

                            HoverHandler {
                                id: removeHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: chipsRoot.removeAt(chip.index)
                            }

                        }

                        MouseArea {
                            id: chipMouse

                            anchors.fill: parent
                            anchors.rightMargin: 24
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: chip.editing = true
                        }

                    }

                    Rectangle {
                        visible: chip.editing
                        anchors.fill: parent
                        radius: 8
                        color: Theme.bgCard
                        border.width: 1
                        border.color: Theme.accent

                        TextField {
                            id: editField

                            anchors.fill: parent
                            anchors.margins: 4
                            text: chip.modelData
                            color: Theme.text
                            font.family: Theme.monoFont
                            font.pixelSize: 12
                            selectByMouse: true
                            focus: chip.editing
                            onEditingFinished: {
                                var v = parseFloat(text);
                                if (!isNaN(v))
                                    chipsRoot.updateAt(chip.index, v);

                                chip.editing = false;
                            }
                            Keys.onEscapePressed: (event) => {
                                chip.editing = false;
                                event.accepted = true;
                            }

                            background: Item {
                            }

                        }

                    }

                }

            }

            Rectangle {
                width: 32
                height: 32
                radius: 8
                color: addHover.containsMouse ? Theme.alpha(Theme.accent, 0.12) : Theme.bgCard
                border.width: 1
                border.color: addHover.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: addHover.containsMouse ? Theme.accent : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }

                HoverHandler {
                    id: addHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chipsRoot.add()
                }

            }

        }

    }

    component SliderRow: Item {
        id: sliderRoot

        property string icon: ""
        property string label: ""
        property real value: 0
        property string displayText: ""
        property bool resettable: false
        property real resetValue: 0

        signal moved(real v)
        signal committed(real v)

        width: parent.width
        height: 38

        Rectangle {
            id: iconBox

            width: 26
            height: 26
            radius: 8
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.alpha(Theme.accent, 0.1)
            border.width: 1
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                text: sliderRoot.icon
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 11
            }

        }

        Text {
            id: labelText

            anchors.left: iconBox.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 110
            text: sliderRoot.label
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1.5
            elide: Text.ElideRight
        }

        Slider {
            anchors.left: labelText.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: ""
            icon: ""
            value: sliderRoot.value
            displayText: sliderRoot.displayText
            resettable: sliderRoot.resettable
            resetValue: sliderRoot.resetValue
            onMoved: (v) => {
                return sliderRoot.moved(v);
            }
            onCommitted: (v) => {
                return sliderRoot.committed(v);
            }
        }

    }

    component ToggleRow: Item {
        id: toggleRoot

        property string label: ""
        property bool checked: false

        signal toggled(bool value)

        width: parent.width
        height: 34

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34 - 48
            text: toggleRoot.label
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1
            elide: Text.ElideRight
        }

        Rectangle {
            width: 38
            height: 20
            radius: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: toggleRoot.checked ? Theme.accent : Theme.bgPanel
            border.width: 1
            border.color: toggleRoot.checked ? Qt.lighter(Theme.accent, 1.15) : Theme.border

            Rectangle {
                x: toggleRoot.checked ? parent.width - width - 2 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: toggleRoot.checked ? "#101116" : Theme.textFaint

                Behavior on x {
                    NumberAnimation {
                        duration: 150
                    }

                }

            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleRoot.toggled(!toggleRoot.checked)
            }

        }

    }

    component Segment: Rectangle {
        property string label: ""
        property bool selected: false

        signal clicked()

        width: segText.implicitWidth + 24
        height: 28
        radius: Theme.radiusXs
        color: selected ? Theme.alpha(Theme.accent, 0.12) : (segMouse.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent")
        border.width: 1
        border.color: selected || segMouse.containsMouse ? Theme.accent : Theme.border

        Text {
            id: segText

            anchors.centerIn: parent
            text: parent.label
            color: parent.selected ? Theme.accent : Theme.textDim
            font.family: Theme.monoFont
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1
        }

        MouseArea {
            id: segMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }

    }

}
