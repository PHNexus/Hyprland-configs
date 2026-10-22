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
    readonly property string filePath: Quickshell.env("HOME") + "/.config/hypr/input.lua"
    property string sourceText: ""
    property bool fileReady: false
    property string statusMessage: "Loading input.lua..."
    property bool saveInProgress: false
    property bool queuedSave: false
    property string queuedSaveText: ""
    property bool dirty: false
    property bool applyAfterSave: false
    property string pendingLiveExpression: ""
    property string pendingLivePath: ""
    property string activeLivePath: ""
    property real sensitivity: 0
    property real scrollFactor: 1
    property bool naturalScroll: false
    property bool followMouse: true
    property int floatSwitchOverrideFocus: 0
    property string accelProfile: "flat"
    property string kbLayout: "us"
    property string kbVariant: ""
    property string kbOptions: ""
    property int repeatRate: 25
    property int repeatDelay: 600
    property bool numlockByDefault: false
    property var deviceOverrides: []
    readonly property var accelProfiles: ["flat", "adaptive"]

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

    function hasTopLevelField(blockText, key) {
        const code = luaMask(blockText, true);
        const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const assignmentRe = new RegExp("^" + escapedKey + "\\s*=");
        let braces = 0;
        let brackets = 0;
        let parentheses = 0;
        for (let i = 0; i < code.length; i++) {
            if (braces === 0 && brackets === 0 && parentheses === 0 && (i === 0 || !/[A-Za-z0-9_]/.test(code.charAt(i - 1))) && /[A-Za-z_]/.test(code.charAt(i)) && assignmentRe.test(code.slice(i)))
                return true;

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
        return false;
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
        const block = findBlockIn(text, "input");
        const scope = block ? luaMask(block.body, false) : cleanText;
        if ((m = scope.match(numRe("sensitivity"))))
            sensitivity = parseFloat(m[1]);

        if ((m = scope.match(numRe("scroll_factor"))))
            scrollFactor = parseFloat(m[1]);

        const touchpadBlock = block ? findBlockIn(block.body, "touchpad") : null;
        const touchpadScope = touchpadBlock ? luaMask(touchpadBlock.body, false) : scope;
        if ((m = touchpadScope.match(boolRe("natural_scroll"))))
            naturalScroll = m[1] === "true";
        else if ((m = scope.match(boolRe("natural_scroll"))))
            naturalScroll = m[1] === "true";
        if ((m = scope.match(intRe("follow_mouse"))))
            followMouse = parseInt(m[1]) !== 0;
        else if ((m = scope.match(boolRe("follow_mouse"))))
            followMouse = m[1] === "true";
        if ((m = scope.match(intRe("float_switch_override_focus"))))
            floatSwitchOverrideFocus = parseInt(m[1]);

        if ((m = scope.match(strRe("accel_profile"))))
            accelProfile = m[2];

        if ((m = scope.match(strRe("kb_layout"))))
            kbLayout = m[2];

        if ((m = scope.match(strRe("kb_variant"))))
            kbVariant = m[2];

        if ((m = scope.match(strRe("kb_options"))))
            kbOptions = m[2];

        if ((m = scope.match(intRe("repeat_rate"))))
            repeatRate = parseInt(m[1]);

        if ((m = scope.match(intRe("repeat_delay"))))
            repeatDelay = parseInt(m[1]);

        if ((m = scope.match(boolRe("numlock_by_default"))))
            numlockByDefault = m[1] === "true";

        const devices = [];
        const deviceText = luaMask(text, false);
        const devRe = /hl\.device\s*\(\s*\{([\s\S]*?)\}\s*\)/g;
        let dm;
        while ((dm = devRe.exec(deviceText)) !== null) {
            const body = dm[1];
            const dev = {
                "raw": text.slice(dm.index, dm.index + dm[0].length),
                "start": dm.index,
                "end": dm.index + dm[0].length
            };
            const nm = body.match(strRe("name"));
            dev.name = nm ? nm[2] : "";
            const sens = body.match(numRe("sensitivity"));
            dev.sensitivity = sens ? parseFloat(sens[1]) : null;
            const sf = body.match(numRe("scroll_factor"));
            dev.scrollFactor = sf ? parseFloat(sf[1]) : null;
            const ns = body.match(boolRe("natural_scroll"));
            dev.naturalScroll = ns ? ns[1] === "true" : null;
            const ap = body.match(strRe("accel_profile"));
            dev.accelProfile = ap ? ap[2] : null;
            devices.push(dev);
        }
        deviceOverrides = devices;
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

    function setInputField(key, value, isBool, isStr, isInt) {
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
        const block = findBlockIn(sourceText, "input");
        if (!block) {
            const inputEntry = key === "natural_scroll" ? "input = {\n        touchpad = { natural_scroll = " + rendered + " },\n    }," : "input = {\n        " + key + " = " + rendered + ",\n    },";
            sourceText += (sourceText.endsWith("\n") ? "\n" : "\n\n") + "hl.config({\n    " + inputEntry + "\n})\n";
        } else if (key === "natural_scroll") {
            let inputBody = block.body;
            if (hasTopLevelField(inputBody, "natural_scroll"))
                inputBody = replaceInBlock(inputBody, "natural_scroll", "nil", false, false, false);

            const touchpadBlock = findBlockIn(inputBody, "touchpad");
            let updatedInputBody;
            if (touchpadBlock) {
                const newTouchpadBody = replaceInBlock(touchpadBlock.body, "natural_scroll", rendered, isBool, isStr, isInt);
                updatedInputBody = inputBody.slice(0, touchpadBlock.bodyStart) + newTouchpadBody + inputBody.slice(touchpadBlock.closeIdx);
            } else {
                updatedInputBody = "\n        touchpad = { natural_scroll = " + rendered + " }," + inputBody;
            }
            sourceText = sourceText.slice(0, block.bodyStart) + updatedInputBody + sourceText.slice(block.closeIdx);
        } else {
            const newBody = replaceInBlock(block.body, key, rendered, isBool, isStr, isInt);
            sourceText = sourceText.slice(0, block.bodyStart) + newBody + sourceText.slice(block.closeIdx);
        }
        readValues(sourceText);
        dirty = true;
        applyAfterSave = true;
        scheduleSave();
    }

    function setDeviceField(dev, key, value, isBool, isStr) {
        if (!fileReady || !dev)
            return ;

        let rendered;
        if (isBool)
            rendered = String(value);
        else if (isStr)
            rendered = '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + '"';
        else
            rendered = Number(value).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
        const body = dev.raw.slice(dev.raw.indexOf("{") + 1, dev.raw.lastIndexOf("}"));
        const newBody = replaceInBlock(body, key, rendered, isBool, isStr, false);
        const newRaw = "hl.device({" + newBody + "})";
        const updated = sourceText.slice(0, dev.start) + newRaw + sourceText.slice(dev.end);
        sourceText = updated;
        readValues(updated);
        dirty = true;
        applyAfterSave = true;
        scheduleSave();
    }

    function scheduleSave() {
        statusMessage = "Saving input.lua...";
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
        inputFile.reload();
        statusMessage = "Reloading input.lua...";
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
            inputFile.setText(sourceText);
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
        id: inputFile

        path: page.filePath
        preload: true
        watchChanges: false
        atomicWrites: true
        onLoaded: {
            try {
                page.sourceText = inputFile.text();
                page.readValues(page.sourceText);
                page.fileReady = true;
                page.statusMessage = "input.lua loaded";
            } catch (e) {
                page.fileReady = false;
                page.statusMessage = "Error: " + e.message;
            }
        }
        onLoadFailed: (error) => {
            page.fileReady = false;
            page.statusMessage = "Unable to load input.lua: " + error;
            console.warn("Input: could not load " + page.filePath + ": " + error);
        }
        onSaved: {
            page.saveInProgress = false;
            if (page.queuedSave) {
                const next = page.queuedSaveText;
                page.queuedSave = false;
                page.queuedSaveText = "";
                page.saveInProgress = true;
                inputFile.setText(next);
                return ;
            }
            page.dirty = false;
            page.sourceText = inputFile.text();
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
            page.statusMessage = "Could not save input.lua: " + error;
            console.warn("Input: could not save " + page.filePath + ": " + error);
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
                    width: reloadBtn.width + 12
                    height: 22
                    radius: Theme.radiusXs
                    color: reloadBtn.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                    border.width: 1
                    border.color: reloadBtn.containsMouse ? Theme.accent : Theme.border
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: reloadBtn

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
                        onEntered: reloadBtn.containsMouse = true
                        onExited: reloadBtn.containsMouse = false
                        onClicked: page.forceReloadFile()
                    }

                }

                Rectangle {
                    width: applyBtn.width + 12
                    height: 22
                    radius: Theme.radiusXs
                    color: applyBtn.containsMouse ? Theme.alpha(Theme.accent, 0.12) : Theme.alpha(Theme.accent, 0.06)
                    border.width: 1
                    border.color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: applyBtn

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
                        onEntered: applyBtn.containsMouse = true
                        onExited: applyBtn.containsMouse = false
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
                text: "POINTER"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                topPadding: 4
            }

            SliderRow {
                icon: "\uf245"
                label: "SENSITIVITY"
                value: (page.sensitivity + 1) / 2
                displayText: page.sensitivity.toFixed(2)
                resettable: true
                resetValue: 0.5
                onMoved: (v) => {
                    page.sensitivity = v * 2 - 1;
                    page.applyLive("input:sensitivity", page.sensitivity);
                    page.setInputField("sensitivity", page.sensitivity);
                }
                onCommitted: (v) => {
                    page.sensitivity = v * 2 - 1;
                    page.setInputField("sensitivity", page.sensitivity);
                }
            }

            SliderRow {
                icon: "\uf0d7"
                label: "SCROLL FACTOR"
                value: Math.min(1, page.scrollFactor / 3)
                displayText: page.scrollFactor.toFixed(2) + "x"
                resettable: true
                resetValue: 1 / 3
                onMoved: (v) => {
                    page.scrollFactor = v * 3;
                    page.applyLive("input:scroll_factor", page.scrollFactor);
                    page.setInputField("scroll_factor", page.scrollFactor);
                }
                onCommitted: (v) => {
                    page.scrollFactor = v * 3;
                    page.setInputField("scroll_factor", page.scrollFactor);
                }
            }

            ToggleRow {
                label: "NATURAL SCROLL"
                checked: page.naturalScroll
                onToggled: (c) => {
                    page.applyLive("input:touchpad:natural_scroll", c);
                    page.setInputField("natural_scroll", c, true);
                }
            }

            ToggleRow {
                label: "FOLLOW MOUSE"
                checked: page.followMouse
                onToggled: (c) => {
                    page.applyLive("input:follow_mouse", c ? 1 : 0);
                    page.setInputField("follow_mouse", c ? 1 : 0, false, false, true);
                }
            }

            Text {
                text: "ACCEL PROFILE"
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
                    model: page.accelProfiles

                    delegate: Segment {
                        required property string modelData

                        label: modelData.toUpperCase()
                        selected: page.accelProfile === modelData
                        onClicked: {
                            page.accelProfile = modelData;
                            page.applyLive("input:accel_profile", modelData);
                            page.setInputField("accel_profile", modelData, false, true);
                        }
                    }

                }

            }

            Text {
                text: "FLOAT SWITCH OVERRIDE FOCUS"
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
                    model: [0, 1, 2]

                    delegate: Segment {
                        required property int modelData

                        label: String(modelData)
                        selected: page.floatSwitchOverrideFocus === modelData
                        onClicked: {
                            page.floatSwitchOverrideFocus = modelData;
                            page.applyLive("input:float_switch_override_focus", modelData);
                            page.setInputField("float_switch_override_focus", modelData, false, false, true);
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
                text: "KEYBOARD"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                topPadding: 4
            }

            FieldRow {
                label: "LAYOUT"
                value: page.kbLayout
                onEdited: (v) => {
                    page.kbLayout = v;
                    page.applyLive("input:kb_layout", v);
                    page.setInputField("kb_layout", v, false, true);
                }
            }

            FieldRow {
                label: "VARIANT"
                value: page.kbVariant
                onEdited: (v) => {
                    page.kbVariant = v;
                    page.applyLive("input:kb_variant", v);
                    page.setInputField("kb_variant", v, false, true);
                }
            }

            FieldRow {
                label: "OPTIONS"
                value: page.kbOptions
                onEdited: (v) => {
                    page.kbOptions = v;
                    page.applyLive("input:kb_options", v);
                    page.setInputField("kb_options", v, false, true);
                }
            }

            SliderRow {
                icon: "\uf11c"
                label: "REPEAT RATE"
                value: Math.min(1, page.repeatRate / 100)
                displayText: page.repeatRate + "/s"
                resettable: true
                resetValue: 25 / 100
                onMoved: (v) => {
                    page.repeatRate = Math.round(v * 100);
                    page.applyLive("input:repeat_rate", page.repeatRate);
                    page.setInputField("repeat_rate", page.repeatRate, false, false, true);
                }
                onCommitted: (v) => {
                    page.repeatRate = Math.round(v * 100);
                    page.setInputField("repeat_rate", page.repeatRate, false, false, true);
                }
            }

            SliderRow {
                icon: "\uf11c"
                label: "REPEAT DELAY"
                value: Math.min(1, page.repeatDelay / 2000)
                displayText: page.repeatDelay + "ms"
                resettable: true
                resetValue: 600 / 2000
                onMoved: (v) => {
                    page.repeatDelay = Math.round(v * 2000);
                    page.applyLive("input:repeat_delay", page.repeatDelay);
                    page.setInputField("repeat_delay", page.repeatDelay, false, false, true);
                }
                onCommitted: (v) => {
                    page.repeatDelay = Math.round(v * 2000);
                    page.setInputField("repeat_delay", page.repeatDelay, false, false, true);
                }
            }

            ToggleRow {
                label: "NUMLOCK BY DEFAULT"
                checked: page.numlockByDefault
                onToggled: (c) => {
                    page.applyLive("input:numlock_by_default", c);
                    page.setInputField("numlock_by_default", c, true);
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                visible: page.deviceOverrides.length >= 2
                anchors.topMargin: 4
            }

            Text {
                visible: page.deviceOverrides.length >= 2
                text: "PER-DEVICE OVERRIDES"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                topPadding: 4
            }

            Column {
                width: parent.width
                spacing: 10
                visible: page.deviceOverrides.length >= 2

                Repeater {
                    model: page.deviceOverrides

                    delegate: Rectangle {
                        id: deviceCard

                        required property var modelData

                        width: parent.width
                        height: deviceColumn.implicitHeight + 24
                        radius: Theme.radius
                        color: Theme.alpha(Theme.accent, 0.03)
                        border.width: 1
                        border.color: Theme.border

                        Column {
                            id: deviceColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 8

                            Row {
                                width: parent.width
                                spacing: 8

                                Text {
                                    text: "\uf245"
                                    color: Theme.accent
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: deviceCard.modelData.name || "(unnamed device)"
                                    color: Theme.text
                                    font.family: Theme.monoFont
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.letterSpacing: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                            }

                            SliderRow {
                                width: deviceColumn.width
                                icon: "\uf245"
                                label: "SENSITIVITY"
                                value: deviceCard.modelData.sensitivity !== null ? (deviceCard.modelData.sensitivity + 1) / 2 : 0.5
                                displayText: deviceCard.modelData.sensitivity !== null ? deviceCard.modelData.sensitivity.toFixed(2) : "—"
                                resettable: true
                                resetValue: 0.5
                                onMoved: (v) => {
                                    return page.applyLive("device[" + deviceCard.modelData.name + "]:sensitivity", v * 2 - 1);
                                }
                                onCommitted: (v) => {
                                    return page.setDeviceField(deviceCard.modelData, "sensitivity", v * 2 - 1);
                                }
                            }

                            SliderRow {
                                width: deviceColumn.width
                                icon: "\uf0d7"
                                label: "SCROLL FACTOR"
                                value: Math.min(1, (deviceCard.modelData.scrollFactor !== null ? deviceCard.modelData.scrollFactor : 1) / 3)
                                displayText: deviceCard.modelData.scrollFactor !== null ? deviceCard.modelData.scrollFactor.toFixed(2) + "x" : "—"
                                resettable: true
                                resetValue: 1 / 3
                                onMoved: (v) => {
                                    return page.applyLive("device[" + deviceCard.modelData.name + "]:scroll_factor", v * 3);
                                }
                                onCommitted: (v) => {
                                    return page.setDeviceField(deviceCard.modelData, "scroll_factor", v * 3);
                                }
                            }

                            ToggleRow {
                                width: deviceColumn.width
                                label: "NATURAL SCROLL"
                                checked: deviceCard.modelData.naturalScroll === true
                                onToggled: (c) => {
                                    page.applyLive("device[" + deviceCard.modelData.name + "]:natural_scroll", c);
                                    page.setDeviceField(deviceCard.modelData, "natural_scroll", c, true);
                                }
                            }

                            Text {
                                text: "ACCEL PROFILE"
                                color: Theme.textDim
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                                font.letterSpacing: 1.2
                            }

                            Flow {
                                width: deviceColumn.width
                                spacing: 6

                                Repeater {
                                    model: page.accelProfiles

                                    delegate: Segment {
                                        required property string modelData

                                        label: modelData.toUpperCase()
                                        selected: deviceCard.modelData.accelProfile === modelData
                                        onClicked: {
                                            page.applyLive("device[" + deviceCard.modelData.name + "]:accel_profile", modelData);
                                            page.setDeviceField(deviceCard.modelData, "accel_profile", modelData, false, true);
                                        }
                                    }

                                }

                            }

                        }

                    }

                }

            }

            Text {
                visible: page.deviceOverrides.length === 0
                text: "No hl.device overrides in input.lua"
                color: Theme.textGhost
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.italic: true
                topPadding: 4
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

    component FieldRow: Item {
        id: fieldRoot

        property string label: ""
        property string value: ""

        signal edited(string value)

        width: parent.width
        height: 34

        Text {
            id: fieldLabel

            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            text: fieldRoot.label
            color: Theme.textDim
            font.family: Theme.monoFont
            font.pixelSize: 10
            font.letterSpacing: 1
            elide: Text.ElideRight
        }

        Rectangle {
            anchors.left: fieldLabel.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: Theme.radiusSm
            color: Theme.bgCard
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.border

            TextField {
                id: field

                anchors.fill: parent
                anchors.margins: 4
                text: fieldRoot.value
                color: Theme.text
                font.family: Theme.monoFont
                font.pixelSize: 12
                selectByMouse: true
                onEditingFinished: fieldRoot.edited(text)

                background: Item {
                }

            }

        }

    }

}
