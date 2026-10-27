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
    property var pendingLiveQueue: []
    property string activeLivePath: ""
    property bool pendingReload: false
    property real sensitivity: 0
    property real scrollFactor: 1
    property bool naturalScroll: false
    property bool mouseNaturalScroll: false
    property bool leftHanded: false
    property string selectedMouseZone: "left"
    property string scrollDevice: "mouse"
    readonly property bool selectedScrollNatural: scrollDevice === "mouse" ? mouseNaturalScroll : naturalScroll
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
    property var detectedPointerDevices: []
    property string selectedDeviceName: ""
    property var keyboardLayouts: []
    property var keyboardVariants: []
    property var isoCountries: ({})
    property string keyboardSearch: ""
    property string variantSearch: ""
    readonly property string xkbRulesPath: "/usr/share/X11/xkb/rules/base.xml"
    readonly property var accelProfiles: ["flat", "adaptive"]
    readonly property var keyboardOptions: [
        { "value": "grp:alt_shift_toggle", "label": "Alt + Shift", "group": "Layout switch" },
        { "value": "grp:win_space_toggle", "label": "Super + Space", "group": "Layout switch" },
        { "value": "grp:ctrl_shift_toggle", "label": "Ctrl + Shift", "group": "Layout switch" },
        { "value": "caps:escape", "label": "Caps → Escape", "group": "Caps Lock" },
        { "value": "caps:ctrl_modifier", "label": "Caps → Ctrl", "group": "Caps Lock" },
        { "value": "ctrl:nocaps", "label": "Disable Caps Lock", "group": "Caps Lock" },
        { "value": "compose:ralt", "label": "Right Alt", "group": "Compose key" },
        { "value": "compose:menu", "label": "Menu key", "group": "Compose key" },
        { "value": "lv3:ralt_switch", "label": "Right Alt (AltGr)", "group": "AltGr" }
    ]

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

    function xmlValue(block, tag) {
        const re = new RegExp("<" + tag + "[^>]*>([\\s\\S]*?)</" + tag + ">", "i");
        const match = re.exec(block);
        if (!match) return "";
        return match[1].replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").trim();
    }

    function parseIsoCountries(jsonText) {
        try {
            const data = JSON.parse(jsonText)["3166-1"] || [];
            const result = {};
            data.forEach(function(country) {
                result[country.alpha_2] = { name: country.name, flag: country.flag || "" };
            });
            isoCountries = result;
            if (keyboardLayouts.length > 0)
                parseKeyboardLayouts(xkbRulesFile.text());
        } catch (error) {
            isoCountries = ({});
        }
    }

    function parseKeyboardLayouts(xmlText) {
        const found = [];
        const layoutRe = /<layout>\s*([\s\S]*?)<\/layout>/g;
        let match;
        while ((match = layoutRe.exec(xmlText)) !== null) {
            const block = match[1];
            const configMatch = /<configItem>([\s\S]*?)<\/configItem>/.exec(block);
            if (!configMatch) continue;
            const code = xmlValue(configMatch[1], "name");
            const description = xmlValue(configMatch[1], "description");
            const short = xmlValue(configMatch[1], "shortDescription");
            const countryMatch = /<countryList>([\s\S]*?)<\/countryList>/.exec(configMatch[1]);
            const countryCode = countryMatch ? xmlValue(countryMatch[1], "iso3166Id") : "";
            const country = isoCountries[countryCode] || ({ "name": countryCode || "Other / regional", "flag": "" });
            if (!code || !description) continue;
            found.push({
                "code": code,
                "description": description,
                "short": short,
                "countryCode": countryCode,
                "country": country.name,
                "flag": country.flag,
                "searchText": (country.name + " " + description + " " + code + " " + short + " " + countryCode).toLowerCase(),
                "block": block
            });
        }
        found.sort(function(a, b) {
            const countryCompare = a.country.localeCompare(b.country);
            return countryCompare !== 0 ? countryCompare : a.description.localeCompare(b.description);
        });
        if (found.length > 0) {
            keyboardLayouts = found;
            updateKeyboardVariants();
        }
    }

    function filteredKeyboardLayouts() {
        const query = keyboardSearch.trim().toLowerCase();
        if (!query) return keyboardLayouts;
        return keyboardLayouts.filter(function(entry) { return entry.searchText.indexOf(query) >= 0; });
    }

    function updateKeyboardVariants() {
        const selected = keyboardLayouts.find(function(entry) { return entry.code === kbLayout; });
        const result = [{ "name": "", "description": "Default variant", "label": "Default variant", "searchText": "default variant" }];
        if (selected) {
            const variantList = /<variantList>([\s\S]*?)<\/variantList>/.exec(selected.block);
            if (variantList) {
                const variantRe = /<variant>([\s\S]*?)<\/variant>/g;
                let match;
                while ((match = variantRe.exec(variantList[1])) !== null) {
                    const item = /<configItem>([\s\S]*?)<\/configItem>/.exec(match[1]);
                    if (!item) continue;
                    const name = xmlValue(item[1], "name");
                    const description = xmlValue(item[1], "description");
                    if (name && description) result.push({
                        "name": name,
                        "description": description,
                        "label": description + " (" + name + ")",
                        "searchText": (description + " " + name).toLowerCase()
                    });
                }
            }
        }
        keyboardVariants = result;
    }

    function filteredKeyboardVariants() {
        const query = variantSearch.trim().toLowerCase();
        if (!query) return keyboardVariants;
        return keyboardVariants.filter(function(entry) { return entry.searchText.indexOf(query) >= 0; });
    }

    function chooseKeyboardLayout(entry) {
        if (!entry) return;
        const changed = entry.code !== kbLayout;
        kbLayout = entry.code;
        keyboardLayoutPopup.close();
        updateKeyboardVariants();
        if (changed) {
            kbVariant = "";
            applyLive("input:kb_layout", kbLayout);
            setInputField("kb_layout", kbLayout, false, true);
            applyLive("input:kb_variant", kbVariant);
            setInputField("kb_variant", kbVariant, false, true);
        }
    }

    function chooseKeyboardVariant(entry) {
        if (!entry) return;
        kbVariant = entry.name;
        keyboardVariantPopup.close();
        applyLive("input:kb_variant", kbVariant);
        setInputField("kb_variant", kbVariant, false, true);
    }

    function keyboardOptionEnabled(option) {
        const values = kbOptions.split(",").map(function(v) { return v.trim(); }).filter(function(v) { return v !== ""; });
        return values.indexOf(option) >= 0;
    }

    function toggleKeyboardOption(option) {
        let values = kbOptions.split(",").map(function(v) { return v.trim(); }).filter(function(v) { return v !== ""; });
        const found = values.indexOf(option);
        if (found >= 0) values.splice(found, 1);
        else {
            if (option.indexOf("grp:") === 0)
                values = values.filter(function(v) { return v.indexOf("grp:") !== 0; });
            if (option.indexOf("caps:") === 0 || option.indexOf("ctrl:") === 0)
                values = values.filter(function(v) { return v.indexOf("caps:") !== 0 && v.indexOf("ctrl:") !== 0; });
            values.push(option);
        }
        kbOptions = values.join(",");
        applyLive("input:kb_options", kbOptions);
        setInputField("kb_options", kbOptions, false, true);
    }

    function applyPointerPreset(nextSensitivity, nextScrollFactor) {
        if (!fileReady)
            return;

        const nextSens = Number(nextSensitivity);
        const nextScroll = Number(nextScrollFactor);
        if (!isFinite(nextSens) || !isFinite(nextScroll))
            return;

        const renderedSensitivity = nextSens.toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
        const renderedScroll = nextScroll.toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
        const block = findBlockIn(sourceText, "input");
        let updatedText = sourceText;

        if (block) {
            let body = block.body;
            body = replaceInBlock(body, "sensitivity", renderedSensitivity, false, false, false);
            body = replaceInBlock(body, "scroll_factor", renderedScroll, false, false, false);
            updatedText = sourceText.slice(0, block.bodyStart) + body + sourceText.slice(block.closeIdx);
        } else {
            const configEntry = "input = {\n        sensitivity = " + renderedSensitivity
                + ",\n        scroll_factor = " + renderedScroll + ",\n    },";
            updatedText += (updatedText.endsWith("\n") ? "\n" : "\n\n")
                + "hl.config({\n    " + configEntry + "\n})\n";
        }

        // Apply both values together so neither field's parse/save cycle can
        // overwrite the other value while the preset is being selected.
        sensitivity = nextSens;
        scrollFactor = nextScroll;
        applyLive("input:sensitivity", nextSens);
        applyLive("input:scroll_factor", nextScroll);

        if (updatedText === sourceText)
            return;

        sourceText = updatedText;
        readValues(updatedText);
        sensitivity = nextSens;
        scrollFactor = nextScroll;
        dirty = true;
        scheduleSave();
    }

    function setNaturalScroll(value) {
        scrollDevice = "touchpad";
        naturalScroll = value;
        applyLive("input:touchpad:natural_scroll", value);
        setInputField("natural_scroll", value, true);
    }

    function setMouseNaturalScroll(value) {
        scrollDevice = "mouse";
        mouseNaturalScroll = value;
        selectedMouseZone = "wheel";
        applyLive("input:natural_scroll", value);
        setInputField("mouse_natural_scroll", value, true);
    }

    function setScrollDevice(device) {
        scrollDevice = device === "mouse" ? "mouse" : "touchpad";
        if (scrollDevice === "mouse")
            selectedMouseZone = "wheel";
        else if (selectedMouseZone === "wheel")
            selectedMouseZone = "left";
    }

    function setSelectedScrollNatural(value) {
        if (scrollDevice === "mouse")
            setMouseNaturalScroll(value);
        else
            setNaturalScroll(value);
    }

    function setPrimaryMouseButton(button) {
        if (button !== "left" && button !== "right")
            return;
        selectedMouseZone = button;
        const nextLeftHanded = button === "right";
        if (leftHanded === nextLeftHanded)
            return;
        leftHanded = nextLeftHanded;
        applyLive("input:left_handed", leftHanded);
        setInputField("left_handed", leftHanded, true);
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
            if (ch === "{")
                depth++;
            else if (ch === "}") {
                depth--;
                if (depth === 0) {
                    closeIdx = i;
                    break;
                }
            }
        }
        if (closeIdx < 0)
            return null;
        return { "start": start, "bodyStart": openIdx + 1, "closeIdx": closeIdx, "body": text.slice(openIdx + 1, closeIdx), "full": text.slice(start, closeIdx + 1) };
    }

    function hasTopLevelField(blockText, key) {
        const code = luaMask(blockText, true);
        const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const assignmentRe = new RegExp("^" + escapedKey + "\\s*=");
        let braces = 0;
        let brackets = 0;
        let parentheses = 0;
        for (let i = 0; i < code.length; i++) {
            if (braces === 0 && brackets === 0 && parentheses === 0 &&
                    (i === 0 || !/[A-Za-z0-9_]/.test(code.charAt(i - 1))) &&
                    /[A-Za-z_]/.test(code.charAt(i)) && assignmentRe.test(code.slice(i)))
                return true;
            const ch = code.charAt(i);
            if (ch === "{") braces++;
            else if (ch === "}") braces = Math.max(0, braces - 1);
            else if (ch === "[") brackets++;
            else if (ch === "]") brackets = Math.max(0, brackets - 1);
            else if (ch === "(") parentheses++;
            else if (ch === ")") parentheses = Math.max(0, parentheses - 1);
        }
        return false;
    }

    function luaQuote(value) {
        return '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r/g, "\\r").replace(/\n/g, "\\n") + '"';
    }

    function luaLiteral(value) {
        if (typeof value === "boolean") return value ? "true" : "false";
        if (typeof value === "number") return isFinite(value) ? String(value) : "0";
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
            if (fieldParts.length !== 1) throw new Error("Unsupported device field: " + deviceMatch[2]);
            return "hl.device({ name = " + luaQuote(deviceMatch[1]) + ", " + luaField(fieldParts[0]) + " = " + renderedValue + " })";
        }
        const parts = [];
        const sections = path.split(":");
        for (let i = 0; i < sections.length; i++) {
            const sectionParts = sections[i].split(".");
            for (let j = 0; j < sectionParts.length; j++) parts.push(sectionParts[j]);
        }
        if (parts.length < 2) throw new Error("Invalid config path: " + path);
        const category = parts.shift();
        let body = luaField(parts.pop()) + " = " + renderedValue;
        for (let i = parts.length - 1; i >= 0; i--) body = luaField(parts[i]) + " = { " + body + " }";
        return "hl.config({ " + luaField(category) + " = { " + body + " } })";
    }

    function startLiveApply() {
        if (liveApplyProcess.running || pendingLiveQueue.length === 0) return;
        const queue = pendingLiveQueue.slice();
        const next = queue.shift();
        pendingLiveQueue = queue;
        activeLivePath = next.path;
        liveApplyProcess.command = ["hyprctl", "eval", next.expression];
        liveApplyProcess.running = true;
    }

    function applyLive(path, value) {
        try {
            const expression = buildConfigExpression(path, value);
            const queue = pendingLiveQueue.slice();
            const existing = queue.findIndex(function(item) { return item.path === path; });
            const entry = { path: path, expression: expression };
            if (existing >= 0) queue[existing] = entry;
            else queue.push(entry);
            pendingLiveQueue = queue;
            liveApplyTimer.restart();
        } catch (e) {
            statusMessage = "Could not prepare setting: " + path;
            console.warn("Settings: could not prepare live apply for " + path + ": " + e);
        }
    }

    function refreshPointerDevices() {
        if (!deviceScanProcess.running) deviceScanProcess.running = true;
    }

    function parsePointerDevices(output) {
        try {
            const data = JSON.parse(output || "{}");
            const raw = Array.isArray(data.mice) ? data.mice : [];
            const seen = ({});
            const found = [];
            raw.forEach(function(device) {
                const name = String(device.name || "").trim();
                const normalized = name.toLocaleLowerCase();
                if (!name || seen[normalized] || /(^|[\s_-])(keyboard|keypad|kbd|keybo|keypad)([\s_-]|$)/i.test(name) || /translated set 2 keyboard|consumer control|system control/i.test(name)) return;
                seen[normalized] = true;
                found.push({ name: name, default: !!device.default, address: String(device.address || "") });
            });
            found.sort(function(a, b) {
                if (a.default !== b.default) return a.default ? -1 : 1;
                return a.name.localeCompare(b.name);
            });
            detectedPointerDevices = found;
            const available = availablePointerDevices();
            if (!selectedDeviceName || !available.some(function(d) { return d.name === selectedDeviceName; })) selectedDeviceName = available.length ? available[0].name : "";
            readValues(sourceText);
        } catch (error) {
            detectedPointerDevices = [];
            selectedDeviceName = "";
            console.warn("Input: unable to parse hyprctl devices output: " + error);
        }
    }

    function availablePointerDevices() {
        const configured = ({});
        deviceOverrides.forEach(function(device) { if (device.name) configured[device.name.toLocaleLowerCase()] = true; });
        return detectedPointerDevices.filter(function(device) { return !device.default && !configured[device.name.toLocaleLowerCase()]; });
    }

    function removeDeviceOverride(device) {
        if (!fileReady || !device || !device.name) return;
        const targetName = device.name.toLocaleLowerCase();
        const current = deviceOverrides.find(function(item) { return item.name && item.name.toLocaleLowerCase() === targetName; });
        if (!current || current.start < 0 || current.end <= current.start) return;
        let start = current.start;
        let end = current.end;
        while (start > 0 && (sourceText.charAt(start - 1) === " " || sourceText.charAt(start - 1) === "\t")) start--;
        if (sourceText.charAt(start - 1) !== "\n" && sourceText.charAt(start - 1) !== "\r") {
            while (end < sourceText.length && (sourceText.charAt(end) === " " || sourceText.charAt(end) === "\t")) end++;
        }
        if (sourceText.charAt(end) === "\r") end++;
        if (sourceText.charAt(end) === "\n") end++;
        sourceText = sourceText.slice(0, start) + sourceText.slice(end);
        readValues(sourceText);
        dirty = true;
        applyAfterSave = true;
        statusMessage = "Removing device override: " + device.name;
        scheduleSave();
    }

    function addDeviceOverride() {
        const name = selectedDeviceName;
        const normalized = name.toLocaleLowerCase();
        if (!name || !fileReady || deviceOverrides.some(function(device) { return device.name.toLocaleLowerCase() === normalized; })) return;
        const block = "hl.device({\n    name = " + luaQuote(name) + ",\n})\n";
        let next = sourceText;
        const terminalReturn = /\n[ \t]*return(?:[ \t].*)?[ \t]*(?:\r?\n)?[ \t]*$/.exec(next);
        if (terminalReturn) next = next.slice(0, terminalReturn.index) + "\n\n" + block + next.slice(terminalReturn.index);
        else next = next.replace(/[ \t\r\n]*$/, "\n\n") + block;
        sourceText = next;
        readValues(sourceText);
        dirty = true;
        applyAfterSave = true;
        statusMessage = "Adding device override: " + name;
        scheduleSave();
    }

    function topLevelFieldValue(blockText, key) {
        const code = luaMask(blockText, true);
        const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const assignmentRe = new RegExp("^" + escapedKey + "\\s*=");
        let braces = 0;
        let brackets = 0;
        let parentheses = 0;

        for (let i = 0; i < code.length; i++) {
            if (braces === 0 && brackets === 0 && parentheses === 0 &&
                    (i === 0 || !/[A-Za-z0-9_]/.test(code.charAt(i - 1))) &&
                    /[A-Za-z_]/.test(code.charAt(i))) {
                const match = assignmentRe.exec(code.slice(i));
                if (match) {
                    let valueStart = i + match[0].length;
                    while (valueStart < code.length && /[ \t]/.test(code.charAt(valueStart)))
                        valueStart++;
                    let valueEnd = code.length;
                    let innerBraces = 0;
                    let innerBrackets = 0;
                    let innerParentheses = 0;
                    for (let j = valueStart; j < code.length; j++) {
                        const ch = code.charAt(j);
                        if (innerBraces === 0 && innerBrackets === 0 && innerParentheses === 0 &&
                                (ch === "," || ch === ";" || ch === "\n" || ch === "\r")) {
                            valueEnd = j;
                            break;
                        }
                        if (ch === "{") innerBraces++;
                        else if (ch === "}") innerBraces = Math.max(0, innerBraces - 1);
                        else if (ch === "[") innerBrackets++;
                        else if (ch === "]") innerBrackets = Math.max(0, innerBrackets - 1);
                        else if (ch === "(") innerParentheses++;
                        else if (ch === ")") innerParentheses = Math.max(0, innerParentheses - 1);
                    }
                    return blockText.slice(valueStart, valueEnd).trim();
                }
            }
            const ch = code.charAt(i);
            if (ch === "{") braces++;
            else if (ch === "}") braces = Math.max(0, braces - 1);
            else if (ch === "[") brackets++;
            else if (ch === "]") brackets = Math.max(0, brackets - 1);
            else if (ch === "(") parentheses++;
            else if (ch === ")") parentheses = Math.max(0, parentheses - 1);
        }
        return "";
    }

    function readValues(text) {
        let m;
        const cleanText = luaMask(text, false);
        const block = findBlockIn(text, "input");
        const scope = block ? luaMask(block.body, false) : cleanText;
        if ((m = scope.match(numRe("sensitivity")))) sensitivity = parseFloat(m[1]);
        if ((m = scope.match(numRe("scroll_factor")))) scrollFactor = parseFloat(m[1]);
        const globalNaturalScroll = topLevelFieldValue(block ? block.body : cleanText, "natural_scroll");
        mouseNaturalScroll = /^true\b/.test(globalNaturalScroll);
        const leftHandedValue = topLevelFieldValue(block ? block.body : cleanText, "left_handed");
        leftHanded = /^true\b/.test(leftHandedValue);
        const touchpadBlock = block ? findBlockIn(block.body, "touchpad") : null;
        const touchpadNaturalScroll = touchpadBlock ? topLevelFieldValue(touchpadBlock.body, "natural_scroll") : "";
        naturalScroll = /^true\b/.test(touchpadNaturalScroll);
        if ((m = scope.match(intRe("follow_mouse")))) followMouse = parseInt(m[1]) !== 0;
        else if ((m = scope.match(boolRe("follow_mouse")))) followMouse = m[1] === "true";
        if ((m = scope.match(intRe("float_switch_override_focus")))) floatSwitchOverrideFocus = parseInt(m[1]);
        if ((m = scope.match(strRe("accel_profile")))) accelProfile = m[2];
        if ((m = scope.match(strRe("kb_layout")))) kbLayout = m[2];
        if ((m = scope.match(strRe("kb_variant")))) kbVariant = m[2];
        if ((m = scope.match(strRe("kb_options")))) kbOptions = m[2];
        if ((m = scope.match(intRe("repeat_rate")))) repeatRate = parseInt(m[1]);
        if ((m = scope.match(intRe("repeat_delay")))) repeatDelay = parseInt(m[1]);
        if ((m = scope.match(boolRe("numlock_by_default")))) numlockByDefault = m[1] === "true";
        const devices = [];
        const primaryNames = ({});
        detectedPointerDevices.forEach(function(device) { if (device.default) primaryNames[device.name.trim().toLocaleLowerCase()] = true; });
        const deviceText = luaMask(text, false);
        const devRe = /hl\.device\s*\(\s*\{([\s\S]*?)\}\s*\)/g;
        let dm;
        while ((dm = devRe.exec(deviceText)) !== null) {
            const body = dm[1];
            const dev = { "raw": text.slice(dm.index, dm.index + dm[0].length), "start": dm.index, "end": dm.index + dm[0].length };
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
            const normalizedName = dev.name.trim().toLocaleLowerCase();
            if (dev.name && !primaryNames[normalizedName] && !devices.some(function(existing) { return existing.name.trim().toLocaleLowerCase() === normalizedName; })) {
                dev.name = dev.name.trim();
                devices.push(dev);
            }
        }
        deviceOverrides = devices;
    }

    function replaceInBlock(blockText, key, rendered, isBool, isStr, isInt) {
        const code = luaMask(blockText, true);
        const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const assignmentRe = new RegExp("^" + escapedKey + "\\s*=");
        const ranges = [];
        let i = 0;
        let braces = 0;
        let brackets = 0;
        let parentheses = 0;

        while (i < code.length) {
            const atTopLevel = braces === 0 && brackets === 0 && parentheses === 0;
            if (atTopLevel && (i === 0 || !/[A-Za-z0-9_]/.test(code.charAt(i - 1))) && /[A-Za-z_]/.test(code.charAt(i))) {
                const match = assignmentRe.exec(code.slice(i));
                if (match) {
                    const equalsAt = i + match[0].length - 1;
                    let valueStart = equalsAt + 1;
                    while (valueStart < blockText.length && /\s/.test(blockText.charAt(valueStart)))
                        valueStart++;

                    let scanEnd = code.length;
                    let valueBraces = 0;
                    let valueBrackets = 0;
                    let valueParentheses = 0;
                    for (let j = valueStart; j < code.length; j++) {
                        const ch = code.charAt(j);
                        if ((ch === "," || ch === ";") && valueBraces === 0 && valueBrackets === 0 && valueParentheses === 0) {
                            scanEnd = j;
                            break;
                        }
                        if (ch === "{") valueBraces++;
                        else if (ch === "}") valueBraces = Math.max(0, valueBraces - 1);
                        else if (ch === "[") valueBrackets++;
                        else if (ch === "]") valueBrackets = Math.max(0, valueBrackets - 1);
                        else if (ch === "(") valueParentheses++;
                        else if (ch === ")") valueParentheses = Math.max(0, valueParentheses - 1);
                    }

                    let valueEnd = scanEnd;
                    while (valueEnd > valueStart && /\s/.test(blockText.charAt(valueEnd - 1)))
                        valueEnd--;
                    ranges.push({ start: valueStart, end: valueEnd });
                    i = scanEnd < code.length ? scanEnd + 1 : code.length;
                    continue;
                }
            }

            const ch = code.charAt(i);
            if (ch === "{") braces++;
            else if (ch === "}") braces = Math.max(0, braces - 1);
            else if (ch === "[") brackets++;
            else if (ch === "]") brackets = Math.max(0, brackets - 1);
            else if (ch === "(") parentheses++;
            else if (ch === ")") parentheses = Math.max(0, parentheses - 1);
            i++;
        }

        if (ranges.length === 0)
            return "\n        " + key + " = " + rendered + "," + blockText;

        let updated = blockText;
        for (let r = ranges.length - 1; r >= 0; r--)
            updated = updated.slice(0, ranges[r].start) + rendered + updated.slice(ranges[r].end);
        return updated;
    }
    function setInputField(key, value, isBool, isStr, isInt) {
        if (!fileReady) return;
        let rendered;
        if (isBool) rendered = String(value);
        else if (isStr) rendered = '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
        else if (isInt) rendered = String(Math.round(Number(value)));
        else rendered = Number(value).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
        const block = findBlockIn(sourceText, "input");
        const storageKey = key === "mouse_natural_scroll" ? "natural_scroll" : key;
        if (!block) {
            const inputEntry = key === "natural_scroll"
                ? "input = {\n        touchpad = { natural_scroll = " + rendered + " },\n    },"
                : "input = {\n        " + storageKey + " = " + rendered + ",\n    },";
            sourceText += (sourceText.endsWith("\n") ? "\n" : "\n\n") + "hl.config({\n    " + inputEntry + "\n})\n";
        } else if (key === "natural_scroll") {
            const inputBody = block.body;
            const touchpadBlock = findBlockIn(inputBody, "touchpad");
            let updatedInputBody;
            if (touchpadBlock) {
                const newTouchpadBody = replaceInBlock(touchpadBlock.body, "natural_scroll", rendered, isBool, isStr, isInt);
                updatedInputBody = inputBody.slice(0, touchpadBlock.bodyStart) + newTouchpadBody + inputBody.slice(touchpadBlock.closeIdx);
            } else updatedInputBody = "\n        touchpad = { natural_scroll = " + rendered + " }," + inputBody;
            sourceText = sourceText.slice(0, block.bodyStart) + updatedInputBody + sourceText.slice(block.closeIdx);
        } else {
            const newBody = replaceInBlock(block.body, storageKey, rendered, isBool, isStr, isInt);
            sourceText = sourceText.slice(0, block.bodyStart) + newBody + sourceText.slice(block.closeIdx);
        }
        readValues(sourceText);
        dirty = true;
        scheduleSave();
    }

    function setDeviceField(dev, key, value, isBool, isStr) {
        if (!fileReady || !dev) return;
        let rendered;
        if (isBool) rendered = String(value);
        else if (isStr) rendered = '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + '"';
        else rendered = Number(value).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
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

    function maybeStartReload() {
        if (!pendingReload || liveApplyProcess.running || pendingLiveQueue.length > 0 || reloadProcess.running)
            return;

        pendingReload = false;
        reloadProcess.command = ["hyprctl", "reload"];
        reloadProcess.running = true;
        statusMessage = "Reloading Hyprland...";
    }

    function runApply() {
        pendingReload = true;
        maybeStartReload();
    }

    function forceApply() {
        if (dirty || saveInProgress || saveTimer.running) {
            applyAfterSave = true;
            statusMessage = "Saving changes before applying...";
            if (dirty && !saveInProgress && !saveTimer.running) saveTimer.restart();
            return;
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
            if (!dirty || saveInProgress)
                return;

            const pendingText = sourceText;
            if (inputFile.text() === pendingText) {
                dirty = false;
                queuedSave = false;
                queuedSaveText = "";
                if (applyAfterSave) {
                    applyAfterSave = false;
                    runApply();
                }
                return;
            }

            saveInProgress = true;
            inputFile.setText(pendingText);
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
        onExited: (code) => {
            if (code !== 0) {
                page.statusMessage = "Live apply failed: " + page.activeLivePath;
                console.warn("Settings: hyprctl eval exited with " + code + " for " + page.activeLivePath);
            }
            if (page.pendingLiveQueue.length > 0)
                liveApplyTimer.restart();
            else
                page.maybeStartReload();
        }
    }

    Process {
        id: deviceScanProcess
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector { onStreamFinished: page.parsePointerDevices(text) }
        onExited: (code) => { if (code !== 0) console.warn("Input: hyprctl devices -j exited with " + code); }
    }

    FileView {
        id: xkbRulesFile
        path: page.xkbRulesPath
        preload: true
        watchChanges: false
        onLoaded: page.parseKeyboardLayouts(xkbRulesFile.text())
        onLoadFailed: {
            page.keyboardLayouts = [
                { "code": "us", "description": "English (US)", "short": "en", "countryCode": "US", "country": "United States", "flag": "🇺🇸", "searchText": "united states english us us en", "block": "" },
                { "code": "br", "description": "Portuguese (Brazil)", "short": "br", "countryCode": "BR", "country": "Brazil", "flag": "🇧🇷", "searchText": "brazil portuguese br br", "block": "" },
                { "code": "gb", "description": "English (UK)", "short": "gb", "countryCode": "GB", "country": "United Kingdom", "flag": "🇬🇧", "searchText": "united kingdom english gb gb", "block": "" }
            ];
            page.updateKeyboardVariants();
        }
    }

    FileView {
        id: isoCountriesFile
        path: "/usr/share/iso-codes/json/iso_3166-1.json"
        preload: true
        watchChanges: false
        onLoaded: page.parseIsoCountries(isoCountriesFile.text())
        onLoadFailed: page.isoCountries = ({})
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
                page.updateKeyboardVariants();
                page.fileReady = true;
                page.statusMessage = "input.lua loaded";
                page.refreshPointerDevices();
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
            page.queuedSave = false;
            page.queuedSaveText = "";

            const savedText = inputFile.text();
            if (page.sourceText !== savedText) {
                page.dirty = true;
                page.scheduleSave();
                return;
            }

            page.dirty = false;
            try {
                page.readValues(page.sourceText);
            } catch (e) {
                console.warn("Input: could not refresh saved values: " + e);
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
            page.maybeStartReload();
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
            spacing: 11

            Column {
                width: parent.width
                spacing: 4
                Text { text: "INPUT"; color: Theme.text; font.family: "Noto Sans"; font.pixelSize: 19; font.weight: Font.Normal }
                Text { text: "Pointer, keyboard and per-device behavior"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10 }
            }

            Row {
                width: parent.width
                height: 26
                spacing: 8
                Rectangle { width: 7; height: 7; radius: 4; color: page.fileReady ? (page.dirty ? "#e5b567" : Theme.ok) : Theme.danger; anchors.verticalCenter: parent.verticalCenter }
                Text { width: Math.max(20, parent.width - 160); text: page.statusMessage; color: Theme.textFaint; font.family: Theme.monoFont; font.pixelSize: 10; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: reloadBtn.width + 12; height: 28; radius: 7; color: reloadBtn.containsMouse ? Theme.bgPanel : Theme.bgCard; border.width: 1; border.color: "#393939"; anchors.verticalCenter: parent.verticalCenter
                    Text { id: reloadBtn; property bool containsMouse: false; anchors.centerIn: parent; text: "Reload"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: reloadBtn.containsMouse = true; onExited: reloadBtn.containsMouse = false; onClicked: page.forceReloadFile() }
                }
                Rectangle {
                    width: applyBtn.width + 18; height: 28; radius: 9; color: applyBtn.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent; border.width: 1; border.color: applyBtn.containsMouse ? "#555555" : "#393939"; anchors.verticalCenter: parent.verticalCenter
                    Text { id: applyBtn; property bool containsMouse: false; anchors.centerIn: parent; text: "Apply"; color: "#101116"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: applyBtn.containsMouse = true; onExited: applyBtn.containsMouse = false; onClicked: page.forceApply() }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#383838" }
            Text { text: "POINTER"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; topPadding: 4 }

            SliderRow {
                icon: "\uf245"; label: "SENSITIVITY"; value: (page.sensitivity + 1) / 2; displayText: page.sensitivity.toFixed(2); resettable: true; resetValue: 0.5
                onMoved: (v) => { page.sensitivity = v * 2 - 1; page.applyLive("input:sensitivity", page.sensitivity); }
                onCommitted: (v) => { page.sensitivity = v * 2 - 1; page.setInputField("sensitivity", page.sensitivity); }
            }
            SliderRow {
                icon: "\uf0d7"; label: "SCROLL FACTOR"; value: Math.min(1, page.scrollFactor / 3); displayText: page.scrollFactor.toFixed(2) + "x"; resettable: true; resetValue: 1 / 3
                onMoved: (v) => { page.scrollFactor = v * 3; page.applyLive("input:scroll_factor", page.scrollFactor); }
                onCommitted: (v) => { page.scrollFactor = v * 3; page.setInputField("scroll_factor", page.scrollFactor); }
            }

            Text { text: "POINTER PRESETS"; color: Theme.textDim; font.family: Theme.monoFont; font.pixelSize: 10; font.letterSpacing: 1.1; topPadding: 2 }
            Flow {
                width: parent.width; spacing: 7
                Repeater {
                    model: [
                        { "label": "PRECISE", "sensitivity": -0.5, "scroll": 0.75, "icon": "\uf245" },
                        { "label": "BALANCED", "sensitivity": 0, "scroll": 1, "icon": "\uf0c8" },
                        { "label": "FAST", "sensitivity": 0.5, "scroll": 1.5, "icon": "\uf0e4" }
                    ]
                    delegate: Segment {
                        required property var modelData
                        icon: modelData.icon; label: modelData.label
                        selected: Math.abs(page.sensitivity - modelData.sensitivity) < 0.001 && Math.abs(page.scrollFactor - modelData.scroll) < 0.001
                        onClicked: page.applyPointerPreset(modelData.sensitivity, modelData.scroll)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "INTERACTIVE MOUSE"
                    color: Theme.textDim
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    font.letterSpacing: 1.1
                }

                Rectangle {
                    width: parent.width
                    height: 356
                    radius: 12
                    color: Theme.alpha(Theme.text, 0.018)
                    border.width: 1
                    border.color: "#393939"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 228

                            Item {
                                id: mouseDiagram
                                width: 174
                                height: 228
                                anchors.centerIn: parent

                                Rectangle {
                                    id: mouseShell
                                    width: 132
                                    height: 220
                                    x: (mouseDiagram.width - width) / 2
                                    y: 4
                                    radius: 64
                                    color: Theme.bgPanel
                                    border.width: 1
                                    border.color: "#393939"
                                }

                                Rectangle {
                                    x: mouseShell.x + 6
                                    y: mouseShell.y + 11
                                    width: 53
                                    height: 76
                                    radius: 26
                                    color: !page.leftHanded ? Theme.alpha(Theme.accent, 0.24) : Theme.alpha(Theme.text, 0.035)
                                    border.width: 1
                                    border.color: "#393939"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "L"
                                            color: !page.leftHanded ? Theme.accent : Theme.textDim
                                            font.family: Theme.monoFont
                                            font.pixelSize: 16
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: !page.leftHanded ? "PRIMARY" : "SECONDARY"
                                            color: !page.leftHanded ? Theme.accent : Theme.textFaint
                                            font.family: Theme.monoFont
                                            font.pixelSize: 8
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setPrimaryMouseButton("left")
                                    }
                                }

                                Rectangle {
                                    x: mouseShell.x + 73
                                    y: mouseShell.y + 11
                                    width: 53
                                    height: 76
                                    radius: 26
                                    color: page.leftHanded ? Theme.alpha(Theme.accent, 0.24) : Theme.alpha(Theme.text, 0.035)
                                    border.width: 1
                                    border.color: "#393939"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "R"
                                            color: page.leftHanded ? Theme.accent : Theme.textDim
                                            font.family: Theme.monoFont
                                            font.pixelSize: 16
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: page.leftHanded ? "PRIMARY" : "SECONDARY"
                                            color: page.leftHanded ? Theme.accent : Theme.textFaint
                                            font.family: Theme.monoFont
                                            font.pixelSize: 8
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setPrimaryMouseButton("right")
                                    }
                                }

                                Rectangle {
                                    x: mouseShell.x + 60
                                    y: mouseShell.y + 13
                                    width: 12
                                    height: 52
                                    radius: 6
                                    color: page.selectedMouseZone === "wheel" ? Theme.accent : Theme.bgCard
                                    border.width: 1
                                    border.color: "#393939"

                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { page.selectedMouseZone = "wheel"; page.setScrollDevice("mouse"); }
                                    }
                                }

                                Rectangle {
                                    x: mouseShell.x + 61
                                    y: mouseShell.y + 103
                                    width: 11
                                    height: 36
                                    radius: 5
                                    color: Theme.alpha(Theme.text, 0.07)
                                    border.width: 1
                                    border.color: "#393939"
                                }

                                Rectangle {
                                    x: mouseShell.x + 61
                                    y: mouseShell.y + 161
                                    width: 11
                                    height: 35
                                    radius: 5
                                    color: Theme.alpha(Theme.text, 0.04)
                                    border.width: 1
                                    border.color: "#393939"
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: "BUTTON MAPPING"
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.textFaint
                            font.family: Theme.monoFont
                            font.pixelSize: 9
                            font.letterSpacing: 1.1
                        }

                        Text {
                            width: parent.width
                            text: page.selectedMouseZone === "wheel" ? "Scroll wheel" : (page.selectedMouseZone === "right" ? "Right button · " + (page.leftHanded ? "Primary" : "Secondary") : "Left button · " + (page.leftHanded ? "Secondary" : "Primary"))
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: page.selectedMouseZone === "wheel" ? "Wheel selected. Choose Natural or Reversed below to change mouse-wheel direction." : (page.selectedMouseZone === "right" ? "Click the right button to make it primary. Left and right click actions will be swapped." : "Click the left button to make it primary. Left and right click actions will be swapped.")
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "PRIMARY BUTTON: " + (page.leftHanded ? "RIGHT" : "LEFT") + "  ·  CLICK L OR R TO CHANGE"
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.accent
                            font.family: Theme.monoFont
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "SCROLL DIRECTION"
                    color: Theme.textDim
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    font.letterSpacing: 1.1
                }

                Row {
                    width: parent.width
                    spacing: 7
                    Segment {
                        label: "MOUSE WHEEL"
                        selected: page.scrollDevice === "mouse"
                        onClicked: page.setScrollDevice("mouse")
                    }
                    Segment {
                        label: "TOUCHPAD"
                        selected: page.scrollDevice === "touchpad"
                        onClicked: page.setScrollDevice("touchpad")
                    }
                }

                Text {
                    text: page.scrollDevice === "mouse" ? "MOUSE WHEEL DIRECTION" : "TOUCHPAD GESTURE DIRECTION"
                    color: Theme.textDim
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 0.8
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 78
                        radius: 11
                        color: page.selectedScrollNatural ? Theme.alpha(Theme.accent, 0.11) : Theme.alpha(Theme.text, 0.025)
                        border.width: 1
                        border.color: "#393939"

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "↑"
                                color: page.selectedScrollNatural ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "NATURAL"
                                color: page.selectedScrollNatural ? Theme.accent : Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: page.scrollDevice === "mouse" ? "WHEEL UP → CONTENT UP" : "SWIPE UP → CONTENT UP"
                                color: Theme.textFaint
                                font.family: Theme.monoFont
                                font.pixelSize: 9
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: false
                            onClicked: page.setSelectedScrollNatural(true)
                        }
                    }

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 78
                        radius: 11
                        color: !page.selectedScrollNatural ? Theme.alpha(Theme.accent, 0.11) : Theme.alpha(Theme.text, 0.025)
                        border.width: 1
                        border.color: "#393939"

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "↓"
                                color: !page.selectedScrollNatural ? Theme.accent : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "REVERSED"
                                color: !page.selectedScrollNatural ? Theme.accent : Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: page.scrollDevice === "mouse" ? "WHEEL UP → CONTENT DOWN" : "SWIPE UP → CONTENT DOWN"
                                color: Theme.textFaint
                                font.family: Theme.monoFont
                                font.pixelSize: 9
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: false
                            onClicked: page.setSelectedScrollNatural(false)
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: page.scrollDevice === "mouse" ? "Saved to input.natural_scroll. Select TOUCHPAD to configure finger gestures separately." : "Saved to input.touchpad.natural_scroll. Mouse-wheel direction is configured separately."
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
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

            Text { text: "ACCEL PROFILE"; color: Theme.textDim; font.family: Theme.monoFont; font.pixelSize: 10; topPadding: 4 }
            Flow {
                id: inputSelector1; width: parent.width; spacing: 7
                Repeater {
                    model: page.accelProfiles
                    delegate: Segment {
                        required property string modelData
                        label: modelData.toUpperCase(); selected: page.accelProfile === modelData
                        onClicked: { page.accelProfile = modelData; page.applyLive("input:accel_profile", modelData); page.setInputField("accel_profile", modelData, false, true); }
                    }
                }
            }

            AccelProfileGraph {
                width: parent.width
                profile: page.accelProfile
                label: "POINTER RESPONSE"
            }

            Text { text: "FLOAT SWITCH OVERRIDE FOCUS"; color: Theme.textDim; font.family: Theme.monoFont; font.pixelSize: 10; topPadding: 4 }
            Flow {
                id: inputSelector2; width: parent.width; spacing: 7
                Repeater {
                    model: [0, 1, 2]
                    delegate: Segment {
                        required property int modelData
                        label: String(modelData); selected: page.floatSwitchOverrideFocus === modelData
                        onClicked: { page.floatSwitchOverrideFocus = modelData; page.applyLive("input:float_switch_override_focus", modelData); page.setInputField("float_switch_override_focus", modelData, false, false, true); }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#383838" }
            Text { text: "KEYBOARD"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; topPadding: 4 }

            Row {
                width: parent.width; spacing: 12; height: 54
                Rectangle {
                    width: 42; height: 42; radius: 12; color: Theme.alpha(Theme.accent, 0.10); anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "\uf11c"; color: Theme.accent; font.family: Theme.iconFont; font.pixelSize: 17 }
                }
                Column {
                    width: Math.max(80, parent.width - 190); anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: "KEYBOARD LAYOUT"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Text {
                        width: parent.width
                        text: { const item = page.keyboardLayouts.find(function(entry) { return entry.code === page.kbLayout; }); return item ? ((item.flag || "") + "  " + item.country + " · " + item.description) : (page.kbLayout.toUpperCase() + " · Custom layout"); }
                        color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10; elide: Text.ElideRight
                    }
                }
                Rectangle {
                    width: 112; height: 36; radius: 10; color: layoutButtonMouse.containsMouse ? Theme.alpha(Theme.accent, 0.15) : Theme.alpha(Theme.text, 0.05); border.width: 1; border.color: "#393939"; anchors.verticalCenter: parent.verticalCenter
                    Row {
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            text: "CHANGE"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "\uf078"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 9
                        }
                    }
                    MouseArea { id: layoutButtonMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { page.keyboardSearch = ""; keyboardLayoutPopup.open(); layoutSearchField.forceActiveFocus(); } }
                }
            }

            FieldRow {
                visible: page.keyboardLayouts.length > 0 && !page.keyboardLayouts.some(function(entry) { return entry.code === page.kbLayout; })
                label: "CUSTOM"; value: page.kbLayout
                onEdited: (v) => { page.kbLayout = v.trim(); page.updateKeyboardVariants(); page.applyLive("input:kb_layout", page.kbLayout); page.setInputField("kb_layout", page.kbLayout, false, true); }
            }

            Row {
                width: parent.width; spacing: 10; height: 40
                Text { text: "VARIANT"; width: 76; color: Theme.textDim; font.family: Theme.monoFont; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: parent.width - 86; height: 36; radius: 9; color: variantButtonMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : Theme.alpha(Theme.text, 0.04); anchors.verticalCenter: parent.verticalCenter
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8
                        Text {
                            width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter
                            text: { const item = page.keyboardVariants.find(function(entry) { return entry.name === page.kbVariant; }); return item ? item.label : (page.kbVariant || "Default variant"); }
                            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight
                        }
                        Text { text: "\uf078"; color: Theme.textDim; font.family: Theme.iconFont; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: variantButtonMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { page.variantSearch = ""; keyboardVariantPopup.open(); variantSearchField.forceActiveFocus(); } }
                }
            }

            FieldRow {
                label: "OPTIONS"; value: page.kbOptions
                onEdited: (v) => { page.kbOptions = v; page.applyLive("input:kb_options", v); page.setInputField("kb_options", v, false, true); }
            }

            Text { text: "QUICK OPTIONS"; color: Theme.textDim; font.family: Theme.monoFont; font.pixelSize: 10; font.letterSpacing: 1.1; topPadding: 2 }
            Flow {
                width: parent.width; spacing: 7
                Repeater {
                    model: page.keyboardOptions
                    delegate: Segment {
                        required property var modelData
                        label: modelData.label; selected: page.keyboardOptionEnabled(modelData.value)
                        onClicked: page.toggleKeyboardOption(modelData.value)
                    }
                }
            }
            Text { text: "Switch layouts, remap Caps Lock, configure Compose and AltGr. Quick options update the OPTIONS field above."; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap; width: parent.width }

            SliderRow {
                icon: "\uf11c"; label: "REPEAT RATE"; value: Math.min(1, page.repeatRate / 100); displayText: page.repeatRate + "/s"; resettable: true; resetValue: 25 / 100
                onMoved: (v) => { page.repeatRate = Math.round(v * 100); page.applyLive("input:repeat_rate", page.repeatRate); }
                onCommitted: (v) => { page.repeatRate = Math.round(v * 100); page.setInputField("repeat_rate", page.repeatRate, false, false, true); }
            }
            SliderRow {
                icon: "\uf11c"; label: "REPEAT DELAY"; value: Math.min(1, page.repeatDelay / 2000); displayText: page.repeatDelay + "ms"; resettable: true; resetValue: 600 / 2000
                onMoved: (v) => { page.repeatDelay = Math.round(v * 2000); page.applyLive("input:repeat_delay", page.repeatDelay); }
                onCommitted: (v) => { page.repeatDelay = Math.round(v * 2000); page.setInputField("repeat_delay", page.repeatDelay, false, false, true); }
            }

            KeyboardRepeatGraph {
                width: parent.width
                repeatDelay: page.repeatDelay
                repeatRate: page.repeatRate
            }

            ToggleRow {
                label: "NUMLOCK BY DEFAULT"; checked: page.numlockByDefault
                onToggled: (c) => { page.applyLive("input:numlock_by_default", c); page.setInputField("numlock_by_default", c, true); }
            }

            Column {
                width: parent.width; spacing: 8
                visible: page.detectedPointerDevices.length > 0 || page.deviceOverrides.length > 0
                Rectangle { width: parent.width; height: 1; color: "#383838" }
                Column {
                    width: parent.width; spacing: 3
                    Text { text: "PER-DEVICE OVERRIDES"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true }
                    Text { text: page.deviceOverrides.length + " configured · " + page.availablePointerDevices().length + " available"; color: Theme.textFaint; font.family: Theme.monoFont; font.pixelSize: 8 }
                }
                Row {
                    width: parent.width; spacing: 8
                    ComboBox {
                        id: devicePicker
                        width: Math.max(120, parent.width - 82); height: 30
                        model: page.availablePointerDevices(); textRole: "name"; valueRole: "name"
                        delegate: ItemDelegate {
                            required property var modelData
                            width: devicePicker.width; text: modelData.name; highlighted: devicePicker.highlightedIndex === index
                            contentItem: Text { text: parent.text; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            background: Rectangle { radius: 6; color: parent.highlighted ? Qt.rgba(Theme.accent.r * 0.28, Theme.accent.g * 0.28, Theme.accent.b * 0.28, 1.0) : (parent.hovered ? Qt.rgba(Theme.text.r * 0.08, Theme.text.g * 0.08, Theme.text.b * 0.08, 1.0) : "transparent") }
                        }
                        popup: Popup {
                            y: devicePicker.height + 4; width: devicePicker.width; implicitHeight: Math.min(contentItem.implicitHeight + 8, 240); padding: 4
                            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: devicePicker.delegateModel; currentIndex: devicePicker.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator {} }
                            background: Rectangle { radius: 9; color: "#111216"; border.width: 1; border.color: "#393939" }
                        }
                        currentIndex: { const list = page.availablePointerDevices(); return list.findIndex(function(device) { return device.name === page.selectedDeviceName; }); }
                        onActivated: (index) => { const list = page.availablePointerDevices(); if (index >= 0 && index < list.length) page.selectedDeviceName = list[index].name; }
                        background: Rectangle { radius: 7; color: Theme.bgCard; border.width: 1; border.color: "#393939" }
                        contentItem: Text { leftPadding: 9; rightPadding: 22; text: devicePicker.currentIndex >= 0 && devicePicker.currentIndex < devicePicker.count ? devicePicker.textAt(devicePicker.currentIndex) : "No new devices available"; color: devicePicker.count > 0 ? Theme.text : Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    }
                    Button {
                        text: "+ Add"; width: 74; height: 30; enabled: page.fileReady && page.selectedDeviceName !== ""; onClicked: page.addDeviceOverride()
                        background: Rectangle { radius: 7; color: parent.enabled ? (parent.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent) : Theme.bgPanel; border.width: 1; border.color: parent.enabled && parent.hovered ? "#555555" : "#393939" }
                        contentItem: Text { text: parent.text; color: parent.enabled ? "#101116" : Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            Column {
                width: parent.width; spacing: 10
                visible: page.deviceOverrides.length >= 1
                Repeater {
                    model: page.deviceOverrides
                    delegate: Rectangle {
                        id: deviceCard
                        required property var modelData
                        width: parent.width; height: deviceColumn.implicitHeight + 24; radius: Theme.radius; color: Theme.alpha(Theme.text, 0.025); border.width: 0
                        Column {
                            id: deviceColumn
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 8
                            Row {
                                width: parent.width; spacing: 8
                                Text { text: "\uf245"; color: Theme.accent; font.family: Theme.iconFont; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: deviceCard.modelData.name || "(unnamed device)"; color: Theme.text; font.family: Theme.monoFont; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: Math.max(80, parent.width - removeDeviceButton.width - 48) }
                                Button {
                                    id: removeDeviceButton; text: "Remove"; width: 64; height: 26; anchors.verticalCenter: parent.verticalCenter; onClicked: page.removeDeviceOverride(deviceCard.modelData)
                                    background: Rectangle { radius: 6; color: parent.hovered ? Theme.alpha(Theme.danger, 0.16) : Theme.bgPanel; border.width: 1; border.color: parent.hovered ? "#555555" : "#393939" }
                                    contentItem: Text { text: parent.text; color: Theme.danger; font.family: Theme.fontFamily; font.pixelSize: 9; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            SliderRow {
                                width: deviceColumn.width; icon: "\uf245"; label: "SENSITIVITY"; value: deviceCard.modelData.sensitivity !== null ? (deviceCard.modelData.sensitivity + 1) / 2 : 0.5; displayText: deviceCard.modelData.sensitivity !== null ? deviceCard.modelData.sensitivity.toFixed(2) : "—"; resettable: true; resetValue: 0.5
                                onMoved: (v) => page.applyLive("device[" + deviceCard.modelData.name + "]:sensitivity", v * 2 - 1)
                                onCommitted: (v) => page.setDeviceField(deviceCard.modelData, "sensitivity", v * 2 - 1)
                            }
                            SliderRow {
                                width: deviceColumn.width; icon: "\uf0d7"; label: "SCROLL FACTOR"; value: Math.min(1, (deviceCard.modelData.scrollFactor !== null ? deviceCard.modelData.scrollFactor : 1) / 3); displayText: deviceCard.modelData.scrollFactor !== null ? deviceCard.modelData.scrollFactor.toFixed(2) + "x" : "—"; resettable: true; resetValue: 1 / 3
                                onMoved: (v) => page.applyLive("device[" + deviceCard.modelData.name + "]:scroll_factor", v * 3)
                                onCommitted: (v) => page.setDeviceField(deviceCard.modelData, "scroll_factor", v * 3)
                            }
                            ToggleRow { width: deviceColumn.width; label: "NATURAL SCROLL"; checked: deviceCard.modelData.naturalScroll === true; onToggled: (c) => { page.applyLive("device[" + deviceCard.modelData.name + "]:natural_scroll", c); page.setDeviceField(deviceCard.modelData, "natural_scroll", c, true); } }
                            Text { text: "ACCEL PROFILE"; color: Theme.textDim; font.family: Theme.monoFont; font.pixelSize: 10 }
                            Flow {
                                width: deviceColumn.width; spacing: 6
                                Repeater { model: page.accelProfiles; delegate: Segment { required property string modelData; label: modelData.toUpperCase(); selected: deviceCard.modelData.accelProfile === modelData; onClicked: { page.applyLive("device[" + deviceCard.modelData.name + "]:accel_profile", modelData); page.setDeviceField(deviceCard.modelData, "accel_profile", modelData, false, true); } } }
                            }
                            AccelProfileGraph {
                                width: deviceColumn.width
                                profile: deviceCard.modelData.accelProfile || "flat"
                                label: "DEVICE RESPONSE"
                            }
                        }
                    }
                }
            }
            Text { visible: page.deviceOverrides.length === 0; text: page.detectedPointerDevices.length === 0 ? "No pointer devices detected by Hyprland" : "No device overrides yet — select a device above and choose + Add"; color: Theme.textGhost; font.family: Theme.fontFamily; font.pixelSize: 10; font.italic: true; topPadding: 4 }
        }
    }

    Popup {
        id: keyboardLayoutPopup; modal: true; anchors.centerIn: Overlay.overlay; width: Math.min(460, page.width - 32); height: Math.min(560, page.height - 40); padding: 18; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#111216"; radius: 18; border.width: 1; border.color: "#393939" }
        contentItem: Column {
            spacing: 12
            Text { text: "Choose keyboard layout"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text { text: page.keyboardLayouts.length + " layouts available · Search by country, language or code"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10 }
            TextField { id: layoutSearchField; width: parent.width; placeholderText: "Search all countries and layouts…"; text: page.keyboardSearch; onTextChanged: page.keyboardSearch = text; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; selectByMouse: true; background: Rectangle { radius: 9; color: Theme.alpha(Theme.text, 0.05); border.width: 0 } }
            ListView {
                id: layoutList; width: parent.width; height: parent.height - 98; clip: true; model: page.filteredKeyboardLayouts(); spacing: 3; boundsBehavior: Flickable.StopAtBounds; ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: layoutItem; required property var modelData; width: layoutList.width; height: 54; radius: 9; color: layoutMouse.containsMouse ? Theme.alpha(Theme.accent, 0.10) : (page.kbLayout === modelData.code ? Theme.alpha(Theme.accent, 0.08) : "transparent")
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                        Text { width: 28; text: layoutItem.modelData.flag || "⌨"; color: Theme.text; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - 74; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { width: parent.width; text: layoutItem.modelData.country; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { width: parent.width; text: layoutItem.modelData.description + " · " + layoutItem.modelData.code; color: Theme.textFaint; font.family: Theme.monoFont; font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        Text { text: page.kbLayout === layoutItem.modelData.code ? "\uf00c" : ""; color: Theme.accent; font.family: Theme.iconFont; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: layoutMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.chooseKeyboardLayout(layoutItem.modelData) }
                }
                Text { anchors.centerIn: parent; visible: layoutList.count === 0; text: "No matching keyboard layouts"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 11 }
            }
        }
    }

    Popup {
        id: keyboardVariantPopup; modal: true; anchors.centerIn: Overlay.overlay; width: Math.min(440, page.width - 32); height: Math.min(520, page.height - 40); padding: 18; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#111216"; radius: 18; border.width: 1; border.color: "#393939" }
        contentItem: Column {
            spacing: 12
            Text { text: "Keyboard variant"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text { text: "Variants for " + page.kbLayout.toUpperCase(); color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10 }
            TextField { id: variantSearchField; width: parent.width; placeholderText: "Search variants…"; text: page.variantSearch; onTextChanged: page.variantSearch = text; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; selectByMouse: true; background: Rectangle { radius: 9; color: Theme.alpha(Theme.text, 0.05); border.width: 0 } }
            ListView {
                id: variantList; width: parent.width; height: parent.height - 88; clip: true; model: page.filteredKeyboardVariants(); spacing: 3; ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: variantItem; required property var modelData; width: variantList.width; height: 42; radius: 8; color: variantMouse.containsMouse ? Theme.alpha(Theme.accent, 0.10) : (page.kbVariant === modelData.name ? Theme.alpha(Theme.accent, 0.08) : "transparent")
                    Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 36; anchors.verticalCenter: parent.verticalCenter; text: variantItem.modelData.label; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
                    Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: page.kbVariant === variantItem.modelData.name ? "\uf00c" : ""; color: Theme.accent; font.family: Theme.iconFont; font.pixelSize: 12 }
                    MouseArea { id: variantMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.chooseKeyboardVariant(variantItem.modelData) }
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
        property bool hovered: false
        signal moved(real v)
        signal committed(real v)
        width: parent.width; height: 42
        Rectangle { anchors.fill: parent; radius: 8; color: sliderRoot.hovered ? Theme.alpha(Theme.accent, 0.035) : "transparent"; Behavior on color { ColorAnimation { duration: 140 } } }
        HoverHandler { onHoveredChanged: sliderRoot.hovered = hovered }
        Rectangle {
            id: iconBox; width: 26; height: 26; radius: 7; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: Theme.alpha(Theme.accent, 0.05); border.width: 1; border.color: "#393939"
            Text { anchors.centerIn: parent; text: sliderRoot.icon; color: Theme.accent; font.family: Theme.iconFont; font.pixelSize: 11 }
        }
        Text { id: labelText; anchors.left: iconBox.right; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: Math.max(78, Math.min(110, sliderRoot.width * 0.25)); text: sliderRoot.label; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
        Slider {
            id: sliderControl
            anchors.left: labelText.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            label: ""
            icon: ""
            value: sliderRoot.value
            displayText: sliderRoot.displayText
            resettable: sliderRoot.resettable
            resetValue: sliderRoot.resetValue
            onMoved: (v) => sliderRoot.moved(v)
            onCommitted: (v) => sliderRoot.committed(v)
        }

        Connections {
            target: sliderRoot
            function onValueChanged() {
                if (Math.abs(sliderControl.value - sliderRoot.value) > 0.000001)
                    sliderControl.value = sliderRoot.value;
            }
        }
    }

    component AccelProfileGraph: Item {
        id: accelGraphRoot

        property string profile: "flat"
        property string label: "POINTER RESPONSE"
        property real testSpeed: 0.68
        readonly property real plotLeft: 30
        readonly property real plotRight: 8

        width: parent ? parent.width : 300
        height: 172

        function responseAt(input, selectedProfile) {
            const v = Math.max(0, Math.min(1, input));
            return selectedProfile === "adaptive" ? Math.max(0, Math.min(1, v - 0.10 * Math.sin(2 * Math.PI * v))) : v;
        }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.alpha(Theme.text, 0.018)
            border.width: 1
            border.color: "#393939"
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            Row {
                width: parent.width
                height: 16
                spacing: 8

                Text {
                    width: parent.width - profileBadge.width - 8
                    text: accelGraphRoot.label
                    color: Theme.textDim
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 0.7
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    id: profileBadge
                    width: profileBadgeText.implicitWidth + 14
                    height: 18
                    radius: 5
                    color: Theme.alpha(Theme.accent, 0.09)
                    border.width: 1
                    border.color: Theme.alpha(Theme.accent, 0.24)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: profileBadgeText
                        anchors.centerIn: parent
                        text: accelGraphRoot.profile.toUpperCase()
                        color: Theme.accent
                        font.family: Theme.monoFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            Canvas {
                id: responseGraph
                width: parent.width
                height: 104
                antialiasing: true

                Component.onCompleted: requestPaint()
                onAvailableChanged: if (available) requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    const left = accelGraphRoot.plotLeft;
                    const right = Math.max(left + 1, width - accelGraphRoot.plotRight);
                    const top = 7;
                    const bottom = height - 19;
                    const plotW = Math.max(1, right - left);
                    const plotH = Math.max(1, bottom - top);
                    const px = function(value) { return left + Math.max(0, Math.min(1, value)) * plotW; };
                    const py = function(value) { return bottom - Math.max(0, Math.min(1, value)) * plotH; };

                    ctx.font = "9px monospace";
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = Theme.alpha(Theme.text, 0.10);
                    ctx.fillStyle = Theme.textFaint;

                    for (let n = 0; n <= 4; n++) {
                        const fraction = n / 4;
                        const gx = px(fraction);
                        const gy = py(fraction);
                        ctx.beginPath();
                        ctx.moveTo(gx, top);
                        ctx.lineTo(gx, bottom);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.moveTo(left, gy);
                        ctx.lineTo(right, gy);
                        ctx.stroke();

                        ctx.textAlign = "right";
                        ctx.fillText(String(n * 25), left - 7, gy + 3);
                        ctx.textAlign = n === 0 ? "left" : (n === 4 ? "right" : "center");
                        ctx.fillText(String(n * 25), gx, height - 4);
                    }

                    const comparisonProfile = accelGraphRoot.profile === "adaptive" ? "flat" : "adaptive";
                    ctx.beginPath();
                    for (let n = 0; n <= 80; n++) {
                        const input = n / 80;
                        const x = px(input);
                        const y = py(accelGraphRoot.responseAt(input, comparisonProfile));
                        if (n === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                    ctx.strokeStyle = Theme.alpha(Theme.text, 0.34);
                    ctx.lineWidth = 1.5;
                    ctx.stroke();

                    ctx.beginPath();
                    for (let n = 0; n <= 80; n++) {
                        const input = n / 80;
                        const x = px(input);
                        const y = py(accelGraphRoot.responseAt(input, accelGraphRoot.profile));
                        if (n === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                    ctx.lineTo(right, bottom);
                    ctx.lineTo(left, bottom);
                    ctx.closePath();
                    ctx.fillStyle = Theme.alpha(Theme.accent, 0.075);
                    ctx.fill();

                    ctx.beginPath();
                    for (let n = 0; n <= 80; n++) {
                        const input = n / 80;
                        const x = px(input);
                        const y = py(accelGraphRoot.responseAt(input, accelGraphRoot.profile));
                        if (n === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                    ctx.strokeStyle = Theme.accent;
                    ctx.lineWidth = 2.4;
                    ctx.stroke();

                    const input = Math.max(0, Math.min(1, accelGraphRoot.testSpeed));
                    const output = accelGraphRoot.responseAt(input, accelGraphRoot.profile);
                    const markerX = px(input);
                    const markerY = py(output);

                    ctx.beginPath();
                    ctx.moveTo(markerX, top);
                    ctx.lineTo(markerX, bottom);
                    ctx.strokeStyle = Theme.alpha(Theme.accent, 0.38);
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.arc(markerX, markerY, 6, 0, Math.PI * 2);
                    ctx.fillStyle = Theme.alpha(Theme.accent, 0.18);
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(markerX, markerY, 3, 0, Math.PI * 2);
                    ctx.fillStyle = Theme.accent;
                    ctx.fill();
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.CrossCursor

                    function setSample(mouseX) {
                        const plotWidth = Math.max(1, responseGraph.width - accelGraphRoot.plotLeft - accelGraphRoot.plotRight);
                        accelGraphRoot.testSpeed = Math.max(0, Math.min(1, (mouseX - accelGraphRoot.plotLeft) / plotWidth));
                    }

                    onClicked: (mouse) => setSample(mouse.x)
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            setSample(mouse.x);
                    }
                }

                Connections {
                    target: accelGraphRoot
                    function onProfileChanged() { responseGraph.requestPaint(); }
                    function onTestSpeedChanged() { responseGraph.requestPaint(); }
                }
            }

            Row {
                width: parent.width
                height: 12
                spacing: 6

                Text {
                    width: parent.width - sampleValue.width - 6
                    text: "ILLUSTRATIVE · DRAG TO SAMPLE"
                    color: Theme.textFaint
                    font.family: Theme.monoFont
                    font.pixelSize: 8
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: sampleValue
                    text: Math.round(accelGraphRoot.testSpeed * 100) + "% IN  →  " + Math.round(accelGraphRoot.responseAt(accelGraphRoot.testSpeed, accelGraphRoot.profile) * 100) + "% OUT"
                    color: Theme.accent
                    font.family: Theme.monoFont
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    component KeyboardRepeatGraph: Item {
        id: repeatGraphRoot

        property int repeatDelay: 600
        property int repeatRate: 25

        width: parent ? parent.width : 300
        height: 94

        readonly property real repeatInterval: repeatRate > 0 ? 1000 / repeatRate : 0
        readonly property real duration: repeatRate > 0 ? Math.max(1000, repeatDelay + repeatInterval * 6) : Math.max(1000, repeatDelay + 100)

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.alpha(Theme.text, 0.018)
            border.width: 1
            border.color: "#393939"
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Row {
                width: parent.width
                height: 13
                spacing: 8

                Text {
                    width: parent.width - repeatRateBadge.width - 8
                    text: "KEY REPEAT TIMELINE"
                    color: Theme.textDim
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: repeatRateBadge
                    text: repeatGraphRoot.repeatRate > 0 ? repeatGraphRoot.repeatRate + "/s  ·  " + repeatGraphRoot.repeatInterval.toFixed(1) + " ms" : "REPEAT OFF"
                    color: repeatGraphRoot.repeatRate > 0 ? Theme.accent : Theme.textFaint
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Canvas {
                id: repeatTimeline
                width: parent.width
                height: 40
                antialiasing: true

                Component.onCompleted: requestPaint()
                onAvailableChanged: if (available) requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    const left = 8;
                    const right = width - 8;
                    const lineY = 20;
                    const plotW = Math.max(1, right - left);
                    const duration = repeatGraphRoot.duration;
                    const delayX = left + plotW * Math.max(0, Math.min(1, repeatGraphRoot.repeatDelay / duration));

                    ctx.font = "8px monospace";
                    ctx.textBaseline = "middle";
                    ctx.fillStyle = Theme.textFaint;
                    ctx.textAlign = "left";
                    ctx.fillText("0 ms", left, 6);
                    ctx.textAlign = "right";
                    ctx.fillText(Math.round(duration) + " ms", right, 6);

                    ctx.fillStyle = Theme.alpha(Theme.text, 0.045);
                    ctx.fillRect(left, lineY - 4, Math.max(0, delayX - left), 8);
                    ctx.fillStyle = Theme.alpha(Theme.accent, 0.10);
                    ctx.fillRect(delayX, lineY - 4, Math.max(0, right - delayX), 8);

                    ctx.beginPath();
                    ctx.moveTo(left, lineY);
                    ctx.lineTo(right, lineY);
                    ctx.strokeStyle = Theme.alpha(Theme.text, 0.27);
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.moveTo(left, 12);
                    ctx.lineTo(left, 29);
                    ctx.strokeStyle = Theme.text;
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.arc(left, lineY, 3, 0, Math.PI * 2);
                    ctx.fillStyle = Theme.text;
                    ctx.fill();

                    ctx.beginPath();
                    ctx.moveTo(delayX, 11);
                    ctx.lineTo(delayX, 30);
                    ctx.strokeStyle = Theme.accent;
                    ctx.lineWidth = 1.7;
                    ctx.stroke();

                    if (repeatGraphRoot.repeatRate > 0) {
                        const interval = repeatGraphRoot.repeatInterval;
                        for (let i = 0; i < 7; i++) {
                            const time = repeatGraphRoot.repeatDelay + interval * i;
                            if (time > duration)
                                break;
                            const x = left + plotW * time / duration;
                            ctx.beginPath();
                            ctx.moveTo(x, i === 0 ? 11 : 14);
                            ctx.lineTo(x, i === 0 ? 30 : 27);
                            ctx.strokeStyle = Theme.accent;
                            ctx.lineWidth = i === 0 ? 1.7 : 1;
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.arc(x, lineY, i === 0 ? 3.3 : 2.1, 0, Math.PI * 2);
                            ctx.fillStyle = Theme.accent;
                            ctx.fill();
                        }
                    }
                }

                Connections {
                    target: repeatGraphRoot
                    function onRepeatDelayChanged() { repeatTimeline.requestPaint(); }
                    function onRepeatRateChanged() { repeatTimeline.requestPaint(); }
                }
            }

            Text {
                width: parent.width
                text: repeatGraphRoot.repeatRate > 0
                    ? "FIRST REPEAT AFTER " + repeatGraphRoot.repeatDelay + " ms  ·  THEN EVERY " + repeatGraphRoot.repeatInterval.toFixed(1) + " ms"
                    : "KEY REPEAT DISABLED  ·  RATE IS ZERO"
                color: Theme.textFaint
                font.family: Theme.monoFont
                font.pixelSize: 8
                elide: Text.ElideRight
            }
        }
    }

    component ToggleRow: Item {
        id: toggleRoot
        property string label: ""
        property bool checked: false
        property bool hovered: false
        signal toggled(bool value)
        width: parent.width; height: 38
        Rectangle { anchors.fill: parent; radius: 8; color: toggleRoot.hovered ? Theme.alpha(Theme.accent, 0.035) : "transparent"; Behavior on color { ColorAnimation { duration: 140 } } }
        HoverHandler { onHoveredChanged: toggleRoot.hovered = hovered }
        Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: Math.max(30, parent.width - 12 - 38 - 28); text: toggleRoot.label; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
        Rectangle {
            width: 38; height: 20; radius: 10; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; color: toggleRoot.checked ? Theme.accent : Theme.bgPanel; border.width: 0
            Rectangle { x: toggleRoot.checked ? parent.width - width - 2 : 2; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 7; color: toggleRoot.checked ? "#101116" : Theme.textFaint; Behavior on x { NumberAnimation { duration: 150 } } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: toggleRoot.toggled(!toggleRoot.checked) }
        }
    }

    component Segment: Rectangle {
        property string label: ""
        property string icon: ""
        property bool selected: false
        signal clicked()
        width: segText.implicitWidth + (icon !== "" ? 34 : 24); height: 30; radius: Theme.radiusXs
        color: selected ? Theme.alpha(Theme.accent, 0.045) : (segMouse.containsMouse ? Theme.alpha(Theme.accent, 0.03) : "transparent")
        border.width: 1; border.color: segMouse.containsMouse ? "#555555" : "#393939"
        Behavior on color {
            ColorAnimation { duration: 120 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }
        Text { id: segText; anchors.centerIn: parent; text: parent.icon !== "" ? parent.icon + "  " + parent.label : parent.label; color: parent.selected ? Theme.accent : Theme.textDim; font.family: Theme.monoFont; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
        MouseArea { id: segMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component FieldRow: Item {
        id: fieldRoot
        property string label: ""
        property string value: ""
        signal edited(string value)
        property bool hovered: false
        width: parent.width; height: 38
        Rectangle { anchors.fill: parent; radius: 8; color: fieldRoot.hovered ? Theme.alpha(Theme.accent, 0.035) : "transparent"; Behavior on color { ColorAnimation { duration: 140 } } }
        HoverHandler { onHoveredChanged: fieldRoot.hovered = hovered }
        Text { id: fieldLabel; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: Math.max(68, Math.min(100, fieldRoot.width * 0.23)); text: fieldRoot.label; color: Theme.textDim; font.family: Theme.monoFont; font.pixelSize: 10; elide: Text.ElideRight }
        Rectangle {
            anchors.left: fieldLabel.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; height: 32; radius: Theme.radiusSm; color: field.activeFocus ? Theme.alpha(Theme.accent, 0.08) : Theme.alpha(Theme.text, 0.035); border.width: 0
            TextField { id: field; anchors.fill: parent; anchors.margins: 4; text: fieldRoot.value; color: Theme.text; font.family: Theme.monoFont; font.pixelSize: 12; selectByMouse: true; onEditingFinished: fieldRoot.edited(text); background: Item {} }
        }
    }
}