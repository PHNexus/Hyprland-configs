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
    readonly property string animationFilePath: Quickshell.env("HOME") + "/.config/hypr/animations.lua"
    property string animationSourceText: ""
    property bool animationFileReady: false
    property string animationStatusMessage: "Loading animations.lua..."
    property bool animationSaveInProgress: false
    property bool animationQueuedSave: false
    property string animationQueuedSaveText: ""
    property bool animationDirty: false
    property bool animationApplyAfterSave: false
    property bool animationEnabled: true
    property string animationPreset: "custom"
    property string selectedCurveName: ""
    property real curvePreviewProgress: 0
    readonly property real curvePreviewSpeed: {
        const entry = animationEntries.find(function(item) {
            return item.leaf === "windowsMove";
        });
        return entry ? Math.max(1, Number(entry.speed) || 7) : 7;
    }
    readonly property int curvePreviewDuration: Math.max(100, Math.min(2000, Math.round(curvePreviewSpeed * 100)))
    property var animationEntries: []
    property var curveEntries: []
    property string sourceText: ""
    property bool fileReady: false
    property string statusMessage: "Loading general.lua..."
    property bool saveInProgress: false
    property bool queuedSave: false
    property string queuedSaveText: ""
    property bool dirty: false
    property bool applyAfterSave: false
    property var pendingLiveQueue: []
    property string activeLivePath: ""
    property bool pendingReload: false
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
    property string explicitColumnWidths: "0.333,0.5,0.667,1"
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

    function queueLiveExpression(path, expression) {
        if (!expression)
            return ;

        const queue = pendingLiveQueue.slice();
        const existing = queue.findIndex(function(item) {
            return item.path === path;
        });
        const entry = {
            "path": path,
            "expression": expression
        };
        if (existing >= 0)
            queue[existing] = entry;
        else
            queue.push(entry);
        pendingLiveQueue = queue;
        liveApplyTimer.restart();
    }

    function startLiveApply() {
        if (liveApplyProcess.running || pendingLiveQueue.length === 0)
            return ;

        const queue = pendingLiveQueue.slice();
        const next = queue.shift();
        pendingLiveQueue = queue;
        activeLivePath = next.path;
        liveApplyProcess.command = ["hyprctl", "eval", next.expression];
        liveApplyProcess.running = true;
    }

    function applyLive(path, value) {
        try {
            queueLiveExpression(path, buildConfigExpression(path, value));
        } catch (e) {
            statusMessage = "Could not prepare setting: " + path;
            console.warn("Settings: could not prepare live apply for " + path + ": " + e);
        }
    }

    function findLuaCalls(text, functionName) {
        const code = luaMask(text, true);
        const escapedName = functionName.replace(/\./g, "\\.");
        const expression = new RegExp("\\b" + escapedName + "\\s*\\(", "g");
        const calls = [];
        let match;
        while ((match = expression.exec(code)) !== null) {
            const open = match.index + match[0].lastIndexOf("(");
            let depth = 0;
            let end = -1;
            for (let i = open; i < code.length; i++) {
                if (code.charAt(i) === "(") {
                    depth++;
                } else if (code.charAt(i) === ")") {
                    depth--;
                    if (depth === 0) {
                        end = i + 1;
                        break;
                    }
                }
            }
            if (end < 0)
                break;

            calls.push({
                "start": match.index,
                "end": end,
                "text": text.slice(match.index, end)
            });
            expression.lastIndex = end;
        }
        return calls;
    }

    function luaTableRange(text, startAt, endAt) {
        const code = luaMask(text, true);
        const start = code.indexOf("{", startAt);
        if (start < 0 || start >= endAt)
            return null;

        let depth = 0;
        for (let i = start; i < endAt; i++) {
            if (code.charAt(i) === "{") {
                depth++;
            } else if (code.charAt(i) === "}") {
                depth--;
                if (depth === 0)
                    return {
                    "start": start,
                    "close": i
                };

            }
        }
        return null;
    }

    function luaNumberField(text, key, fallback) {
        const pattern = new RegExp("\\b" + key + "\\s*=\\s*(-?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][+-]?\\d+)?)");
        const match = luaMask(text, false).match(pattern);
        return match ? Number(match[1]) : fallback;
    }

    function luaStringField(text, key, fallback) {
        const pattern = new RegExp("\\b" + key + "\\s*=\\s*([\\\"'])([^\\\"']*)\\1");
        const match = luaMask(text, false).match(pattern);
        return match ? match[2] : fallback;
    }

    function luaBoolField(text, key, fallback) {
        const pattern = new RegExp("\\b" + key + "\\s*=\\s*(true|false)");
        const match = luaMask(text, false).match(pattern);
        return match ? match[1] === "true" : fallback;
    }

    function curveGraphPoint(entry, progress) {
        const t = Math.max(0, Math.min(1, Number(progress) || 0));
        if (!entry)
            return {
            "x": t,
            "y": t
        };

        if (entry.type === "spring") {
            const mass = Math.max(0.1, Number(entry.mass) || 1);
            const stiffness = Math.max(1, Number(entry.stiffness) || 120);
            const dampening = Math.max(0, Number(entry.dampening) || 0);
            const decay = dampening / (2 * mass);
            const frequency = Math.sqrt(Math.max(0.01, stiffness / mass - decay * decay));
            const y = 1 - Math.exp(-decay * t) * Math.cos(frequency * t);
            return {
                "x": t,
                "y": y
            };
        }
        const cubic = function cubic(a, b, p) {
            const u = 1 - p;
            return 3 * u * u * p * a + 3 * u * p * p * b + p * p * p;
        };
        return {
            "x": cubic(Number(entry.x1) || 0, Number(entry.x2) || 0, t),
            "y": cubic(Number(entry.y1) || 0, Number(entry.y2) || 0, t)
        };
    }

    function readAnimationValues(text) {
        const code = luaMask(text, true);
        const enabledMatch = code.match(/\banimations\s*=\s*\{\s*enabled\s*=\s*(true|false)/);
        if (enabledMatch)
            animationEnabled = enabledMatch[1] === "true";

        const parsedAnimations = [];
        const animationCalls = findLuaCalls(text, "hl.animation");
        for (let i = 0; i < animationCalls.length; i++) {
            const call = animationCalls[i];
            const leaf = luaStringField(call.text, "leaf", "");
            if (!leaf)
                continue;

            parsedAnimations.push({
                "leaf": leaf,
                "enabled": luaBoolField(call.text, "enabled", true),
                "speed": luaNumberField(call.text, "speed", 5),
                "bezier": luaStringField(call.text, "bezier", ""),
                "spring": luaStringField(call.text, "spring", ""),
                "style": luaStringField(call.text, "style", "")
            });
        }
        animationEntries = parsedAnimations;
        const parsedCurves = [];
        const curveCalls = findLuaCalls(text, "hl.curve");
        const number = "(-?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][+-]?\\d+)?)";
        for (let i = 0; i < curveCalls.length; i++) {
            const call = curveCalls[i];
            const nameMatch = call.text.match(/^hl\.curve\s*\(\s*([\"'])([^\"']+)\1/);
            if (!nameMatch)
                continue;

            const type = luaStringField(call.text, "type", "bezier");
            const entry = {
                "name": nameMatch[2],
                "type": type
            };
            if (type === "spring") {
                entry.mass = luaNumberField(call.text, "mass", 1);
                entry.stiffness = luaNumberField(call.text, "stiffness", 120);
                entry.dampening = luaNumberField(call.text, "dampening", 16);
            } else {
                const plain = luaMask(call.text, false);
                const pointsPattern = new RegExp("points\\s*=\\s*\\{\\s*\\{\\s*" + number + "\\s*,\\s*" + number + "\\s*\\}\\s*,?\\s*\\{\\s*" + number + "\\s*,\\s*" + number + "\\s*\\}");
                const points = plain.match(pointsPattern);
                entry.x1 = points ? Number(points[1]) : 0.2;
                entry.y1 = points ? Number(points[2]) : 0;
                entry.x2 = points ? Number(points[3]) : 0.8;
                entry.y2 = points ? Number(points[4]) : 1;
            }
            parsedCurves.push(entry);
        }
        curveEntries = parsedCurves;
        if (!selectedCurveName || !parsedCurves.some(function(entry) {
            return entry.name === selectedCurveName;
        }))
            selectedCurveName = parsedCurves.length > 0 ? parsedCurves[0].name : "";

        animationPreset = detectAnimationPreset();
        if (animationPreset !== "custom") {
            const movement = parsedAnimations.find(function(entry) {
                return entry.leaf === "windowsMove";
            });
            const activeCurveName = movement ? (movement.spring || movement.bezier) : "";
            if (activeCurveName && parsedCurves.some(function(entry) {
                return entry.name === activeCurveName;
            }))
                selectedCurveName = activeCurveName;

        }
    }

    function animationCurveNames() {
        const names = ["default"];
        curveEntries.forEach(function(entry) {
            if (names.indexOf(entry.name) < 0)
                names.push(entry.name);

        });
        return names;
    }

    function animationNumber(value) {
        return Number(value).toFixed(3).replace(/0+$/, "").replace(/\.$/, "") || "0";
    }

    function animationCallText(entry) {
        const fields = ["leaf = " + luaQuote(entry.leaf), "enabled = " + String(!!entry.enabled), "speed = " + animationNumber(entry.speed)];
        if (entry.spring)
            fields.push("spring = " + luaQuote(entry.spring));
        else if (entry.bezier)
            fields.push("bezier = " + luaQuote(entry.bezier));
        if (entry.style)
            fields.push("style = " + luaQuote(entry.style));

        return "hl.animation({ " + fields.join(", ") + " })";
    }

    function animationPresetOptions() {
        return [{
            "value": "smooth",
            "label": "SMOOTH",
            "description": "Slower, fluid motion with gentle easing",
            "icon": "\uf2d0"
        }, {
            "value": "balanced",
            "label": "BALANCED",
            "description": "Your original animations.lua timings and curves",
            "icon": "\uf0c8"
        }, {
            "value": "snappy",
            "label": "SNAPPY",
            "description": "Very fast, direct transitions",
            "icon": "\uf0e7"
        }, {
            "value": "bouncy",
            "label": "BOUNCY",
            "description": "Spring motion with visible bounce",
            "icon": "\uf1b2"
        }, {
            "value": "minimal",
            "label": "MINIMAL",
            "description": "Quick, restrained movement without fade effects",
            "icon": "\uf06e"
        }];
    }

    function animationPresetValues(name) {
        const values = {
            "global": {
                "enabled": true,
                "speed": 6.5,
                "bezier": "default",
                "spring": "",
                "style": ""
            },
            "windows": {
                "enabled": true,
                "speed": 6.8,
                "bezier": "easeoutquint",
                "spring": "",
                "style": ""
            },
            "windowsIn": {
                "enabled": true,
                "speed": 6.8,
                "bezier": "emphasizeddeccel",
                "spring": "",
                "style": ""
            },
            "windowsOut": {
                "enabled": true,
                "speed": 6.8,
                "bezier": "emphasizedaccel",
                "spring": "",
                "style": ""
            },
            "windowsMove": {
                "enabled": true,
                "speed": 7,
                "bezier": "standard",
                "spring": "",
                "style": "slide"
            },
            "fadeIn": {
                "enabled": true,
                "speed": 5.5,
                "bezier": "almostlinear",
                "spring": "",
                "style": ""
            },
            "fadeOut": {
                "enabled": true,
                "speed": 5.5,
                "bezier": "almostlinear",
                "spring": "",
                "style": ""
            },
            "fade": {
                "enabled": true,
                "speed": 5.5,
                "bezier": "standard",
                "spring": "",
                "style": ""
            },
            "fadeDim": {
                "enabled": true,
                "speed": 7.5,
                "bezier": "standard",
                "spring": "",
                "style": ""
            },
            "layers": {
                "enabled": true,
                "speed": 5.8,
                "bezier": "easeoutquint",
                "spring": "",
                "style": ""
            },
            "layersIn": {
                "enabled": true,
                "speed": 5.8,
                "bezier": "emphasizeddeccel",
                "spring": "",
                "style": ""
            },
            "layersOut": {
                "enabled": true,
                "speed": 5.8,
                "bezier": "emphasizedaccel",
                "spring": "",
                "style": ""
            },
            "fadeLayersIn": {
                "enabled": true,
                "speed": 2.5,
                "bezier": "almostlinear",
                "spring": "",
                "style": ""
            },
            "fadeLayersOut": {
                "enabled": true,
                "speed": 2.5,
                "bezier": "almostlinear",
                "spring": "",
                "style": ""
            },
            "workspaces": {
                "enabled": true,
                "speed": 4,
                "bezier": "almostlinear",
                "spring": "",
                "style": "slidefade 25%"
            },
            "specialWorkspace": {
                "enabled": true,
                "speed": 8,
                "bezier": "",
                "spring": "boing",
                "style": "slidefadevert 50%"
            },
            "border": {
                "enabled": true,
                "speed": 6.5,
                "bezier": "standard",
                "spring": "",
                "style": ""
            }
        };
        if (name === "balanced")
            return values;

        const set = function set(leaf, speed, curve, style) {
            if (!values[leaf])
                return ;

            values[leaf].speed = speed;
            values[leaf].spring = "";
            values[leaf].bezier = curve || "";
            if (style !== undefined)
                values[leaf].style = style;

        };
        const spring = function spring(leaf, speed, curve, style) {
            if (!values[leaf])
                return ;

            values[leaf].speed = speed;
            values[leaf].bezier = "";
            values[leaf].spring = curve;
            if (style !== undefined)
                values[leaf].style = style;

        };
        const disable = function disable(leaves) {
            leaves.forEach(function(leaf) {
                if (values[leaf])
                    values[leaf].enabled = false;

            });
        };
        if (name === "smooth") {
            set("global", 8, "default");
            set("windows", 7.5, "easeoutquint");
            set("windowsIn", 8, "emphasizeddeccel");
            set("windowsOut", 7, "emphasizedaccel");
            set("windowsMove", 8, "easeinout", "slide");
            set("fadeIn", 5.2, "easeinout");
            set("fadeOut", 4.8, "easeinout");
            set("fade", 5.2, "easeinout");
            set("fadeDim", 6, "easeinout");
            set("layers", 6.8, "easeoutquint");
            set("layersIn", 6.8, "emphasizeddeccel");
            set("layersOut", 6.2, "emphasizedaccel");
            set("fadeLayersIn", 4, "almostlinear");
            set("fadeLayersOut", 3.8, "almostlinear");
            set("workspaces", 6, "workspaceslide", "slidefade 35%");
            set("specialWorkspace", 7.8, "easeinout", "slidefadevert 50%");
            set("border", 5.8, "easeinout");
        } else if (name === "snappy") {
            set("global", 1.8, "default");
            set("windows", 1.8, "almostlinear");
            set("windowsIn", 1.5, "almostlinear");
            set("windowsOut", 1.3, "almostlinear");
            set("windowsMove", 1.7, "almostlinear", "slide");
            set("fadeIn", 1.2, "almostlinear");
            set("fadeOut", 1, "almostlinear");
            set("fade", 1.3, "almostlinear");
            set("fadeDim", 1.5, "almostlinear");
            set("layers", 1.8, "almostlinear");
            set("layersIn", 1.6, "almostlinear");
            set("layersOut", 1.4, "almostlinear");
            set("fadeLayersIn", 1, "almostlinear");
            set("fadeLayersOut", 1, "almostlinear");
            set("workspaces", 1.8, "almostlinear", "slidefade 8%");
            set("specialWorkspace", 2.2, "almostlinear", "slidefadevert 12%");
            set("border", 1.8, "almostlinear");
        } else if (name === "bouncy") {
            set("global", 4, "easeoutquint");
            set("windows", 4, "easeoutquint");
            spring("windowsIn", 3.3, "boing");
            spring("windowsOut", 3.1, "stiffboing");
            spring("windowsMove", 3.8, "boing", "slide");
            set("fadeIn", 2.7, "easeinout");
            set("fadeOut", 2.5, "emphasizedaccel");
            set("fade", 2.8, "easeinout");
            set("fadeDim", 3.2, "standard");
            set("layers", 3.8, "easeoutquint");
            spring("layersIn", 3.3, "stiffboing");
            spring("layersOut", 3.2, "boing");
            set("fadeLayersIn", 1.8, "almostlinear");
            set("fadeLayersOut", 1.7, "almostlinear");
            set("workspaces", 3.6, "workspaceslide", "slidefade 35%");
            spring("specialWorkspace", 4.5, "boing", "slidefadevert 65%");
            set("border", 3.4, "easeinout");
        } else if (name === "minimal") {
            // Short, restrained motion: quicker than Balanced, but not as abrupt as Snappy.
            // Keep movement visible while removing fade and spring effects.
            set("global", 2.8, "default");
            set("windows", 2.8, "standard");
            set("windowsIn", 2.5, "almostlinear");
            set("windowsOut", 2.3, "almostlinear");
            set("windowsMove", 2.8, "almostlinear", "slide");
            set("fadeIn", 2, "almostlinear");
            set("fadeOut", 1.8, "almostlinear");
            set("fade", 2, "standard");
            set("fadeDim", 2.2, "standard");
            set("layers", 2.8, "standard");
            set("layersIn", 2.5, "almostlinear");
            set("layersOut", 2.3, "almostlinear");
            set("fadeLayersIn", 1.8, "almostlinear");
            set("fadeLayersOut", 1.6, "almostlinear");
            set("workspaces", 2.8, "almostlinear", "slidefade 5%");
            set("specialWorkspace", 3.2, "almostlinear", "slidefadevert 8%");
            set("border", 2.6, "standard");
            disable(["fadeIn", "fadeOut", "fade", "fadeDim", "fadeLayersIn", "fadeLayersOut"]);
        } else {
            return null;
        }
        return values;
    }

    function animationPresetCurveValues(name) {
        if (name !== "balanced")
            return [];

        return [{
            "name": "specialworkswitch",
            "type": "bezier",
            "x1": 0.05,
            "y1": 0.7,
            "x2": 0.1,
            "y2": 1
        }, {
            "name": "emphasizedaccel",
            "type": "bezier",
            "x1": 0.3,
            "y1": 0,
            "x2": 0.8,
            "y2": 1
        }, {
            "name": "emphasizeddeccel",
            "type": "bezier",
            "x1": 0.05,
            "y1": 0.7,
            "x2": 0.1,
            "y2": 1
        }, {
            "name": "standard",
            "type": "bezier",
            "x1": 0.2,
            "y1": 0,
            "x2": 0,
            "y2": 1
        }, {
            "name": "easeoutquint",
            "type": "bezier",
            "x1": 0.23,
            "y1": 1,
            "x2": 0.32,
            "y2": 1
        }, {
            "name": "easeinout",
            "type": "bezier",
            "x1": 0.65,
            "y1": 0.05,
            "x2": 0.36,
            "y2": 1
        }, {
            "name": "almostlinear",
            "type": "bezier",
            "x1": 0.25,
            "y1": 0.25,
            "x2": 0.75,
            "y2": 0.75
        }, {
            "name": "workspaceslide",
            "type": "bezier",
            "x1": 0.25,
            "y1": 0.4,
            "x2": 0.95,
            "y2": 1
        }, {
            "name": "boing",
            "type": "spring",
            "mass": 1,
            "stiffness": 120,
            "dampening": 16
        }, {
            "name": "stiffboing",
            "type": "spring",
            "mass": 1,
            "stiffness": 125,
            "dampening": 15
        }];
    }

    function animationPresetCurvesMatch(name) {
        const expected = animationPresetCurveValues(name);
        if (expected.length === 0)
            return true;

        const currentByName = ({
        });
        curveEntries.forEach(function(entry) {
            currentByName[entry.name] = entry;
        });
        for (let i = 0; i < expected.length; i++) {
            const target = expected[i];
            const current = currentByName[target.name];
            if (!current || current.type !== target.type)
                return false;

            if (target.type === "spring") {
                if (Math.abs(Number(current.mass) - target.mass) > 0.001 || Math.abs(Number(current.stiffness) - target.stiffness) > 0.001 || Math.abs(Number(current.dampening) - target.dampening) > 0.001)
                    return false;

            } else if (Math.abs(Number(current.x1) - target.x1) > 0.001 || Math.abs(Number(current.y1) - target.y1) > 0.001 || Math.abs(Number(current.x2) - target.x2) > 0.001 || Math.abs(Number(current.y2) - target.y2) > 0.001) {
                return false;
            }
        }
        return true;
    }

    function animationPresetMatches(name) {
        if (!animationEnabled)
            return false;

        const expected = animationPresetValues(name);
        if (!expected)
            return false;

        const currentByLeaf = ({
        });
        animationEntries.forEach(function(entry) {
            currentByLeaf[entry.leaf] = entry;
        });
        const leaves = Object.keys(expected);
        for (let i = 0; i < leaves.length; i++) {
            const leaf = leaves[i];
            const current = currentByLeaf[leaf];
            const target = expected[leaf];
            if (!current || current.enabled !== target.enabled || Math.abs(Number(current.speed) - target.speed) > 0.011)
                return false;

            if ((current.bezier || "") !== (target.bezier || "") || (current.spring || "") !== (target.spring || "") || (current.style || "") !== (target.style || ""))
                return false;

        }
        return name === "balanced" ? animationPresetCurvesMatch(name) : true;
    }

    function detectAnimationPreset() {
        const names = ["smooth", "balanced", "snappy", "bouncy", "minimal"];
        for (let i = 0; i < names.length; i++) {
            if (animationPresetMatches(names[i]))
                return names[i];

        }
        return "custom";
    }

    function applyAnimationPreset(name) {
        if (!animationFileReady)
            return ;

        const values = animationPresetValues(name);
        if (!values)
            return ;

        let updatedText = animationSourceText;
        const calls = findLuaCalls(updatedText, "hl.animation");
        for (let i = calls.length - 1; i >= 0; i--) {
            const leaf = luaStringField(calls[i].text, "leaf", "");
            const target = values[leaf];
            if (!target)
                continue;

            const replacement = animationCallText(Object.assign({
                "leaf": leaf
            }, target));
            updatedText = updatedText.slice(0, calls[i].start) + replacement + updatedText.slice(calls[i].end);
        }
        const presetCurves = animationPresetCurveValues(name);
        if (presetCurves.length > 0) {
            const curveCalls = findLuaCalls(updatedText, "hl.curve");
            const existingCurves = ({
            });
            for (let i = curveCalls.length - 1; i >= 0; i--) {
                const nameMatch = curveCalls[i].text.match(/^hl\.curve\s*\(\s*([\"'])([^\"']+)\1/);
                if (!nameMatch)
                    continue;

                const target = presetCurves.find(function(entry) {
                    return entry.name === nameMatch[2];
                });
                if (!target)
                    continue;

                existingCurves[target.name] = true;
                const replacement = curveCallText(target);
                updatedText = updatedText.slice(0, curveCalls[i].start) + replacement + updatedText.slice(curveCalls[i].end);
            }
            const missingCurves = presetCurves.filter(function(entry) {
                return !existingCurves[entry.name];
            });
            if (missingCurves.length > 0) {
                const firstAnimation = findLuaCalls(updatedText, "hl.animation")[0];
                const insertion = missingCurves.map(function(entry) {
                    return curveCallText(entry);
                }).join("\n    ") + "\n    \n";
                const insertAt = firstAnimation ? firstAnimation.start : updatedText.lastIndexOf("return M");
                if (insertAt >= 0)
                    updatedText = updatedText.slice(0, insertAt) + insertion + updatedText.slice(insertAt);

            }
        }
        const code = luaMask(updatedText, true);
        const enabledPattern = /\banimations\s*=\s*\{\s*\benabled\s*=\s*(true|false)/;
        const enabledMatch = enabledPattern.exec(code);
        if (!enabledMatch) {
            animationStatusMessage = "Could not find animations.enabled in animations.lua";
            return ;
        }
        const enabledValue = enabledMatch[1];
        const enabledStart = enabledMatch.index + enabledMatch[0].lastIndexOf(enabledValue);
        updatedText = updatedText.slice(0, enabledStart) + "true" + updatedText.slice(enabledStart + enabledValue.length);
        const liveCalls = ["hl.config({ animations = { enabled = true } })"];
        presetCurves.forEach(function(entry) {
            liveCalls.push(curveCallText(entry));
        });
        animationEntries.forEach(function(entry) {
            const target = values[entry.leaf];
            if (target)
                liveCalls.push(animationCallText(Object.assign({
                "leaf": entry.leaf
            }, target)));

        });
        finishAnimationEdit(updatedText, liveCalls.join("; "), "preset " + name);
    }

    function curveCallText(entry) {
        if (entry.type === "spring")
            return "hl.curve(" + luaQuote(entry.name) + ", { type = \"spring\", mass = " + animationNumber(entry.mass) + ", stiffness = " + animationNumber(entry.stiffness) + ", dampening = " + animationNumber(entry.dampening) + " })";

        return "hl.curve(" + luaQuote(entry.name) + ", { type = \"bezier\", points = { { " + animationNumber(entry.x1) + ", " + animationNumber(entry.y1) + " }, { " + animationNumber(entry.x2) + ", " + animationNumber(entry.y2) + " } } })";
    }

    function scheduleAnimationSave() {
        animationStatusMessage = "Saving animations.lua...";
        animationSaveTimer.restart();
    }

    function finishAnimationEdit(updatedText, expression, label) {
        animationSourceText = updatedText;
        readAnimationValues(animationSourceText);
        animationDirty = true;
        scheduleAnimationSave();
        if (expression)
            queueLiveExpression("animation: " + label, expression);

    }

    function setAnimationMasterEnabled(enabled) {
        if (!animationFileReady)
            return ;

        const code = luaMask(animationSourceText, true);
        const pattern = /\banimations\s*=\s*\{\s*\benabled\s*=\s*(true|false)/;
        const match = pattern.exec(code);
        if (!match) {
            animationStatusMessage = "Could not find animations.enabled in animations.lua";
            return ;
        }
        const currentValue = match[1];
        const valueStart = match.index + match[0].lastIndexOf(currentValue);
        const updatedText = animationSourceText.slice(0, valueStart) + String(enabled) + animationSourceText.slice(valueStart + currentValue.length);
        finishAnimationEdit(updatedText, "hl.config({ animations = { enabled = " + String(enabled) + " } })", "global animations");
    }

    function setAnimationField(leaf, key, value, isBool, isStr, isInt) {
        if (!animationFileReady || animationPreset === "balanced")
            return ;

        const calls = findLuaCalls(animationSourceText, "hl.animation");
        for (let i = 0; i < calls.length; i++) {
            const call = calls[i];
            if (luaStringField(call.text, "leaf", "") !== leaf)
                continue;

            const table = luaTableRange(animationSourceText, call.start, call.end);
            if (!table)
                return ;

            let rendered;
            if (isBool)
                rendered = String(value);
            else if (isStr)
                rendered = luaQuote(value);
            else if (isInt)
                rendered = String(Math.round(Number(value)));
            else
                rendered = animationNumber(value);
            const body = animationSourceText.slice(table.start + 1, table.close);
            const updatedBody = replaceInBlock(body, key, rendered, isBool, isStr, isInt);
            const updatedText = animationSourceText.slice(0, table.start + 1) + updatedBody + animationSourceText.slice(table.close);
            finishAnimationEdit(updatedText, "", leaf);
            const updatedEntry = animationEntries.find(function(entry) {
                return entry.leaf === leaf;
            });
            if (updatedEntry)
                queueLiveExpression("animation: " + leaf, animationCallText(updatedEntry));

            return ;
        }
        animationStatusMessage = "Could not find animation: " + leaf;
    }

    function setAnimationCurve(leaf, curveName) {
        if (!animationFileReady || animationPreset === "balanced")
            return ;

        const entry = animationEntries.find(function(item) {
            return item.leaf === leaf;
        });
        if (!entry)
            return ;

        const curve = curveEntries.find(function(item) {
            return item.name === curveName;
        });
        const updatedEntry = Object.assign({
        }, entry);
        if (curve && curve.type === "spring") {
            updatedEntry.spring = curveName;
            updatedEntry.bezier = "";
        } else {
            updatedEntry.bezier = curveName;
            updatedEntry.spring = "";
        }
        const calls = findLuaCalls(animationSourceText, "hl.animation");
        for (let i = 0; i < calls.length; i++) {
            if (luaStringField(calls[i].text, "leaf", "") !== leaf)
                continue;

            const updatedText = animationSourceText.slice(0, calls[i].start) + animationCallText(updatedEntry) + animationSourceText.slice(calls[i].end);
            finishAnimationEdit(updatedText, animationCallText(updatedEntry), leaf);
            return ;
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
        let updatedText = sourceText;
        const block = findBlockIn(updatedText, blockName);
        if (!block) {
            let configEntry;
            if (blockName === "col")
                configEntry = "general = {\n        col = {\n            " + key + " = " + rendered + ",\n        },\n    },";
            else if (blockName === "blur" || blockName === "shadow")
                configEntry = "decoration = {\n        " + blockName + " = {\n            " + key + " = " + rendered + ",\n        },\n    },";
            else
                configEntry = blockName + " = {\n        " + key + " = " + rendered + ",\n    },";
            updatedText += (updatedText.endsWith("\n") ? "\n" : "\n\n") + "hl.config({\n    " + configEntry + "\n})\n";
        } else {
            const newBody = replaceInBlock(block.body, key, rendered, isBool, isStr, isInt);
            updatedText = updatedText.slice(0, block.bodyStart) + newBody + updatedText.slice(block.closeIdx);
        }
        readValues(updatedText);
        if (updatedText === sourceText)
            return ;

        sourceText = updatedText;
        dirty = true;
        scheduleSave();
    }

    function scheduleSave() {
        statusMessage = "Saving general.lua...";
        saveTimer.restart();
    }

    function applyGapPreset(gapIn, gapOut) {
        if (!fileReady)
            return ;

        const nextIn = Math.max(0, Math.round(Number(gapIn) || 0));
        const nextOut = Math.max(0, Math.round(Number(gapOut) || 0));
        const block = findBlockIn(sourceText, "general");
        let updatedText = sourceText;
        if (block) {
            let body = block.body;
            body = replaceInBlock(body, "gaps_in", String(nextIn), false, false, true);
            body = replaceInBlock(body, "gaps_out", String(nextOut), false, false, true);
            updatedText = sourceText.slice(0, block.bodyStart) + body + sourceText.slice(block.closeIdx);
        } else {
            const configEntry = "general = {\n        gaps_in = " + nextIn + ",\n        gaps_out = " + nextOut + ",\n    },";
            updatedText += (updatedText.endsWith("\n") ? "\n" : "\n\n") + "hl.config({\n    " + configEntry + "\n})\n";
        }
        gapsIn = nextIn;
        gapsOut = nextOut;
        applyLive("general:gaps_in", nextIn);
        applyLive("general:gaps_out", nextOut);
        if (updatedText === sourceText)
            return ;

        sourceText = updatedText;
        readValues(updatedText);
        dirty = true;
        scheduleSave();
    }

    function findPresetBlockRanges(text, name) {
        const code = luaMask(text, true);
        const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const expression = new RegExp("\\b" + escapedName + "\\s*=\\s*\\{", "g");
        const ranges = [];
        let match;
        while ((match = expression.exec(code)) !== null) {
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
                break;

            ranges.push({
                "start": match.index,
                "bodyStart": openIdx + 1,
                "closeIdx": closeIdx,
                "body": text.slice(openIdx + 1, closeIdx)
            });
            expression.lastIndex = closeIdx + 1;
        }
        return ranges;
    }

    function setPresetFieldInText(text, blockName, key, value, isBool, isStr, isInt) {
        let rendered;
        if (isBool)
            rendered = String(value);
        else if (isStr)
            rendered = '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
        else if (isInt)
            rendered = String(Math.round(Number(value)));
        else
            rendered = Number(value).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
        const blocks = findPresetBlockRanges(text, blockName);
        if (blocks.length === 0) {
            let configEntry;
            if (blockName === "blur" || blockName === "shadow")
                configEntry = "decoration = {\n        " + blockName + " = {\n            " + key + " = " + rendered + ",\n        },\n    },";
            else
                configEntry = blockName + " = {\n        " + key + " = " + rendered + ",\n    },";
            return text + (text.endsWith("\n") ? "\n" : "\n\n") + "hl.config({\n    " + configEntry + "\n})\n";
        }
        let updatedText = text;
        for (let i = blocks.length - 1; i >= 0; i--) {
            const block = blocks[i];
            const newBody = replaceInBlock(block.body, key, rendered, isBool, isStr, isInt);
            updatedText = updatedText.slice(0, block.bodyStart) + newBody + updatedText.slice(block.closeIdx);
        }
        return updatedText;
    }

    function visualPresetValues(preset) {
        if (preset === "midnight")
            return {
                "rounding": 10,
                "activeOpacity": 0.97,
                "inactiveOpacity": 0.88,
                "blurEnabled": true,
                "blurSize": 6,
                "blurPasses": 3,
                "shadowEnabled": true,
                "shadowRange": 14,
                "shadowRenderPower": 3
            };

        if (preset === "balanced")
            return {
                "rounding": 16,
                "activeOpacity": 0.9,
                "inactiveOpacity": 0.9,
                "blurEnabled": true,
                "blurSize": 6,
                "blurPasses": 4,
                "shadowEnabled": true,
                "shadowRange": 16,
                "shadowRenderPower": 6
            };

        if (preset === "monolith")
            return {
                "rounding": 2,
                "activeOpacity": 1,
                "inactiveOpacity": 0.96,
                "blurEnabled": false,
                "blurSize": 4,
                "blurPasses": 2,
                "shadowEnabled": false,
                "shadowRange": 12,
                "shadowRenderPower": 3
            };

        return null;
    }

    function visualPresetMatches(preset) {
        const target = visualPresetValues(preset);
        if (!target)
            return false;

        return rounding === target.rounding && Math.abs(activeOpacity - target.activeOpacity) < 0.001 && Math.abs(inactiveOpacity - target.inactiveOpacity) < 0.001 && blurEnabled === target.blurEnabled && blurSize === target.blurSize && blurPasses === target.blurPasses && shadowEnabled === target.shadowEnabled && shadowRange === target.shadowRange && shadowRenderPower === target.shadowRenderPower;
    }

    function applyVisualPreset(preset) {
        const target = visualPresetValues(preset);
        if (!target || !fileReady)
            return ;

        const changes = [{
            "blockName": "decoration",
            "key": "rounding",
            "value": target.rounding,
            "isInt": true
        }, {
            "blockName": "decoration",
            "key": "active_opacity",
            "value": target.activeOpacity
        }, {
            "blockName": "decoration",
            "key": "inactive_opacity",
            "value": target.inactiveOpacity
        }, {
            "blockName": "blur",
            "key": "enabled",
            "value": target.blurEnabled,
            "isBool": true
        }, {
            "blockName": "blur",
            "key": "size",
            "value": target.blurSize,
            "isInt": true
        }, {
            "blockName": "blur",
            "key": "passes",
            "value": target.blurPasses,
            "isInt": true
        }, {
            "blockName": "shadow",
            "key": "enabled",
            "value": target.shadowEnabled,
            "isBool": true
        }, {
            "blockName": "shadow",
            "key": "range",
            "value": target.shadowRange,
            "isInt": true
        }, {
            "blockName": "shadow",
            "key": "render_power",
            "value": target.shadowRenderPower,
            "isInt": true
        }];
        let updatedText = sourceText;
        for (let i = 0; i < changes.length; i++) {
            const change = changes[i];
            updatedText = setPresetFieldInText(updatedText, change.blockName, change.key, change.value, !!change.isBool, !!change.isStr, !!change.isInt);
        }
        for (let i = 0; i < changes.length; i++) {
            const change = changes[i];
            const livePath = change.blockName === "blur" || change.blockName === "shadow" ? "decoration:" + change.blockName + ":" + change.key : change.blockName + ":" + change.key;
            applyLive(livePath, change.value);
        }
        if (updatedText === sourceText) {
            readValues(sourceText);
            statusMessage = "Visual preset already active";
            return ;
        }
        sourceText = updatedText;
        readValues(sourceText);
        dirty = true;
        scheduleSave();
    }

    function maybeStartReload() {
        if (!pendingReload || liveApplyProcess.running || pendingLiveQueue.length > 0 || reloadProcess.running)
            return ;

        pendingReload = false;
        reloadProcess.command = ["hyprctl", "reload"];
        reloadProcess.running = true;
        statusMessage = "Reloading Hyprland...";
    }

    function runApply() {
        pendingReload = true;
        maybeStartReload();
    }

    function maybeRunDeferredApply() {
        if (!applyAfterSave && !animationApplyAfterSave)
            return ;

        if (dirty || saveInProgress || saveTimer.running)
            return ;

        if (animationApplyAfterSave && (animationDirty || animationSaveInProgress || animationSaveTimer.running))
            return ;

        applyAfterSave = false;
        animationApplyAfterSave = false;
        runApply();
    }

    function forceApply() {
        const generalPending = dirty || saveInProgress || saveTimer.running;
        const animationsPending = animationDirty || animationSaveInProgress || animationSaveTimer.running;
        if (generalPending || animationsPending) {
            if (generalPending)
                applyAfterSave = true;

            if (animationsPending)
                animationApplyAfterSave = true;

            statusMessage = "Saving changes before applying...";
            if (dirty && !saveInProgress && !saveTimer.running)
                saveTimer.restart();

            if (animationDirty && !animationSaveInProgress && !animationSaveTimer.running)
                animationSaveTimer.restart();

            return ;
        }
        runApply();
    }

    function forceReloadFile() {
        generalFile.reload();
        statusMessage = "Reloading general.lua...";
    }

    Connections {
        function onCurvePreviewProgressChanged() {
            curveGraph.requestPaint();
        }

        function onSelectedCurveNameChanged() {
            curveGraph.requestPaint();
        }

        function onCurveEntriesChanged() {
            curveGraph.requestPaint();
        }

        target: page
    }

    Timer {
        id: saveTimer

        interval: 250
        repeat: false
        onTriggered: {
            if (!dirty || saveInProgress)
                return ;

            const pendingText = sourceText;
            if (generalFile.text() === pendingText) {
                dirty = false;
                queuedSave = false;
                queuedSaveText = "";
                statusMessage = "Saved";
                if (applyAfterSave || animationApplyAfterSave)
                    maybeRunDeferredApply();

                return ;
            }
            saveInProgress = true;
            generalFile.setText(pendingText);
        }
    }

    Timer {
        id: animationSaveTimer

        interval: 250
        repeat: false
        onTriggered: {
            if (!page.animationDirty || page.animationSaveInProgress)
                return ;

            const pendingText = page.animationSourceText;
            if (animationFile.text() === pendingText) {
                page.animationDirty = false;
                page.animationQueuedSave = false;
                page.animationQueuedSaveText = "";
                page.animationStatusMessage = "Saved animations.lua";
                if (page.applyAfterSave || page.animationApplyAfterSave)
                    page.maybeRunDeferredApply();

                return ;
            }
            page.animationSaveInProgress = true;
            animationFile.setText(pendingText);
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
                if (page.activeLivePath.indexOf("animation:") === 0)
                    page.animationStatusMessage = "Live apply failed: " + page.activeLivePath;
                else
                    page.statusMessage = "Live apply failed: " + page.activeLivePath;
                console.warn("Settings: hyprctl eval exited with " + code + " for " + page.activeLivePath);
            }
            if (page.pendingLiveQueue.length > 0)
                liveApplyTimer.restart();
            else
                page.maybeStartReload();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output && /(error|failed|invalid|unknown)/i.test(output)) {
                    if (page.activeLivePath.indexOf("animation:") === 0)
                        page.animationStatusMessage = "Live apply reported an error: " + page.activeLivePath;
                    else
                        page.statusMessage = "Live apply reported an error: " + page.activeLivePath;
                    console.warn("Settings: live apply output for " + page.activeLivePath + ": " + output);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output) {
                    if (page.activeLivePath.indexOf("animation:") === 0)
                        page.animationStatusMessage = "Live apply reported an error: " + page.activeLivePath;
                    else
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
                const widthMigrationMarker = "-- phnexus-explicit-column-widths-default-v1";
                if (page.sourceText.indexOf(widthMigrationMarker) < 0) {
                    page.setBlockField("scrolling", "explicit_column_widths", "0.333,0.5,0.667,1", false, true);
                    if (!page.sourceText.endsWith("\n"))
                        page.sourceText += "\n";

                    page.sourceText += widthMigrationMarker + "\n";
                    page.dirty = true;
                    page.scheduleSave();
                }
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
            page.queuedSave = false;
            page.queuedSaveText = "";
            const savedText = generalFile.text();
            if (page.sourceText !== savedText) {
                page.dirty = true;
                page.scheduleSave();
                return ;
            }
            page.dirty = false;
            page.sourceText = savedText;
            try {
                page.readValues(page.sourceText);
            } catch (e) {
            }
            if (page.applyAfterSave || page.animationApplyAfterSave) {
                page.maybeRunDeferredApply();
                if (page.statusMessage !== "Reloading Hyprland..." && !page.animationApplyAfterSave)
                    page.statusMessage = "Saved";

            } else {
                page.statusMessage = "Saved";
            }
        }
        onSaveFailed: (error) => {
            page.saveInProgress = false;
            page.queuedSave = false;
            page.queuedSaveText = "";
            page.statusMessage = "Could not save general.lua: " + error;
            console.warn("General: could not save " + page.filePath + ": " + error);
        }
    }

    FileView {
        id: animationFile

        path: page.animationFilePath
        preload: true
        watchChanges: false
        atomicWrites: true
        onLoaded: {
            try {
                page.animationSourceText = animationFile.text();
                page.readAnimationValues(page.animationSourceText);
                page.animationFileReady = true;
                page.animationStatusMessage = "animations.lua loaded · " + page.animationEntries.length + " animations · " + page.curveEntries.length + " curves";
            } catch (e) {
                page.animationFileReady = false;
                page.animationStatusMessage = "Error: " + e.message;
            }
        }
        onLoadFailed: (error) => {
            page.animationFileReady = false;
            page.animationStatusMessage = "Unable to load animations.lua: " + error;
            console.warn("General: could not load " + page.animationFilePath + ": " + error);
        }
        onSaved: {
            page.animationSaveInProgress = false;
            page.animationQueuedSave = false;
            page.animationQueuedSaveText = "";
            const savedText = animationFile.text();
            if (page.animationSourceText !== savedText) {
                page.animationDirty = true;
                animationSaveTimer.restart();
                return ;
            }
            page.animationDirty = false;
            try {
                page.readAnimationValues(page.animationSourceText);
                page.animationStatusMessage = "Animations saved · " + page.animationEntries.length + " animations · " + page.curveEntries.length + " curves";
            } catch (e) {
                page.animationStatusMessage = "Saved animations.lua";
            }
            if (page.applyAfterSave || page.animationApplyAfterSave)
                page.maybeRunDeferredApply();

        }
        onSaveFailed: (error) => {
            page.animationSaveInProgress = false;
            page.animationStatusMessage = "Could not save animations.lua: " + error;
            console.warn("General: could not save " + page.animationFilePath + ": " + error);
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

                Text {
                    text: "GENERAL"
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 19
                    font.weight: Font.Normal
                }

                Text {
                    text: "Window layout, borders and visual effects"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

            }

            Row {
                width: parent.width
                height: 30
                spacing: 8

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    color: page.fileReady ? (page.dirty ? "#e5b567" : Theme.ok) : Theme.danger
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: Math.max(20, parent.width - 217)
                    text: page.statusMessage
                    color: Theme.textFaint
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Button {
                    text: "Reload"
                    implicitHeight: 28
                    implicitWidth: 70
                    enabled: page.fileReady
                    onClicked: page.forceReloadFile()

                    background: Rectangle {
                        radius: 7
                        color: parent.hovered ? Theme.bgPanel : Theme.bgCard
                        border.width: 1
                        border.color: "#393939"
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
                    text: "Apply"
                    implicitHeight: 28
                    implicitWidth: 116
                    enabled: page.fileReady
                    onClicked: page.forceApply()

                    background: Rectangle {
                        radius: 9
                        color: parent.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                        border.width: 1
                        border.color: "#393939"
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
                width: parent.width
                height: 1
                color: "#383838"
            }

            Text {
                text: "LAYOUT"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
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
                id: generalSelector1

                width: parent.width
                spacing: 7

                Repeater {
                    model: [{
                        "value": "scrolling",
                        "label": "SCROLLING",
                        "icon": "\uf07e",
                        "description": "Horizontal columns"
                    }, {
                        "value": "dwindle",
                        "label": "DWINDLE",
                        "icon": "\uf00a",
                        "description": "Dynamic tiling"
                    }, {
                        "value": "master",
                        "label": "MASTER",
                        "icon": "\uf2d0",
                        "description": "Master + stack"
                    }]

                    delegate: LayoutOption {
                        required property var modelData

                        label: modelData.label
                        description: modelData.description
                        icon: modelData.icon
                        selected: page.layout === modelData.value
                        onClicked: {
                            page.layout = modelData.value;
                            page.applyLive("general:layout", modelData.value);
                            page.setBlockField("general", "layout", modelData.value, false, true);
                        }
                    }

                }

            }

            Text {
                width: parent.width
                text: page.layout === "scrolling" ? "Best for keyboard-driven column workflows. Configure column width, direction, follow-focus and explicit width presets below." : (page.layout === "dwindle" ? "Automatically split space as windows open. Preserve split direction with the option in Dwindle / Master." : "Keep one primary window with additional windows arranged as a stack.")
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            Rectangle {
                id: tilingTopologyPreview

                width: parent.width
                height: 211
                radius: 14
                color: Theme.bgPanel
                border.width: 1
                border.color: "#393939"

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 9

                    Row {
                        width: parent.width
                        height: 27
                        spacing: 8

                        Column {
                            spacing: 1

                            Text {
                                text: "TILING MAP"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                text: "WORKSPACE / STRUCTURE"
                                color: Theme.textDim
                                font.family: Theme.monoFont
                                font.pixelSize: 8
                                font.letterSpacing: 0.65
                            }

                        }

                        Item {
                            width: Math.max(1, parent.width - 180)
                            height: 1
                        }

                        Text {
                            text: page.layout.toUpperCase()
                            color: Theme.accent
                            font.family: Theme.monoFont
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 125
                        radius: 9
                        color: Theme.bgCard
                        border.width: 1
                        border.color: "#393939"

                        Row {
                            id: scrollingTopology

                            property real focusRatio: Math.min(0.58, Math.max(0.34, page.columnWidth))

                            visible: page.layout === "scrolling"
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Rectangle {
                                width: (parent.width - parent.spacing * 2) * (1 - scrollingTopology.focusRatio) / 2
                                height: parent.height
                                radius: 5
                                color: Theme.alpha(Theme.text, 0.055)
                                border.width: 1
                                border.color: "#393939"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 5

                                    Text {
                                        text: "01"
                                        color: Theme.textDim
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                    }

                                    Rectangle {
                                        width: parent.width * 0.72
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.text, 0.16)
                                    }

                                    Rectangle {
                                        width: parent.width * 0.48
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.text, 0.12)
                                    }

                                    Item {
                                        width: 1
                                        height: Math.max(1, parent.height - 48)
                                    }

                                    Text {
                                        text: "TERM"
                                        color: Theme.textDim
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }

                                }

                            }

                            Rectangle {
                                width: (parent.width - parent.spacing * 2) * scrollingTopology.focusRatio
                                height: parent.height
                                radius: 5
                                color: Theme.alpha(Theme.accent, 0.15)
                                border.width: 1
                                border.color: "#393939"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 5

                                    Row {
                                        spacing: 5

                                        Text {
                                            text: "02"
                                            color: Theme.accent
                                            font.family: Theme.monoFont
                                            font.pixelSize: 9
                                        }

                                        Text {
                                            text: "FOCUSED"
                                            color: Theme.accent
                                            font.family: Theme.monoFont
                                            font.pixelSize: 8
                                            font.weight: Font.DemiBold
                                        }

                                    }

                                    Rectangle {
                                        width: parent.width * 0.86
                                        height: 4
                                        radius: 2
                                        color: Theme.accent
                                    }

                                    Rectangle {
                                        width: parent.width * 0.68
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.accent, 0.58)
                                    }

                                    Rectangle {
                                        width: parent.width * 0.53
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.accent, 0.45)
                                    }

                                    Item {
                                        width: 1
                                        height: Math.max(1, parent.height - 57)
                                    }

                                    Text {
                                        text: "EDITOR"
                                        color: Theme.text
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }

                                }

                            }

                            Rectangle {
                                width: (parent.width - parent.spacing * 2) * (1 - scrollingTopology.focusRatio) / 2
                                height: parent.height
                                radius: 5
                                color: Theme.alpha(Theme.text, 0.055)
                                border.width: 1
                                border.color: "#393939"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 5

                                    Text {
                                        text: "03"
                                        color: Theme.textDim
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                    }

                                    Rectangle {
                                        width: parent.width * 0.72
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.text, 0.16)
                                    }

                                    Rectangle {
                                        width: parent.width * 0.54
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.text, 0.12)
                                    }

                                    Item {
                                        width: 1
                                        height: Math.max(1, parent.height - 48)
                                    }

                                    Text {
                                        text: "WEB"
                                        color: Theme.textDim
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }

                                }

                            }

                        }

                        Row {
                            visible: page.layout === "dwindle"
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Column {
                                width: (parent.width - parent.spacing) * 0.46
                                height: parent.height
                                spacing: 6

                                Rectangle {
                                    width: parent.width
                                    height: (parent.height - parent.spacing) * 0.56
                                    radius: 5
                                    color: Theme.alpha(Theme.accent, 0.15)
                                    border.width: 1
                                    border.color: "#393939"

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 7
                                        spacing: 5

                                        Text {
                                            text: "01 / FOCUSED"
                                            color: Theme.accent
                                            font.family: Theme.monoFont
                                            font.pixelSize: 8
                                        }

                                        Rectangle {
                                            width: parent.width * 0.78
                                            height: 4
                                            radius: 2
                                            color: Theme.accent
                                        }

                                        Rectangle {
                                            width: parent.width * 0.55
                                            height: 4
                                            radius: 2
                                            color: Theme.alpha(Theme.accent, 0.58)
                                        }

                                    }

                                }

                                Rectangle {
                                    width: parent.width
                                    height: (parent.height - parent.spacing) * 0.44
                                    radius: 5
                                    color: Theme.alpha(Theme.text, 0.055)
                                    border.width: 1
                                    border.color: "#393939"

                                    Text {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 7
                                        text: "02"
                                        color: Theme.textSoft
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                    }

                                }

                            }

                            Column {
                                width: parent.width - (parent.width - parent.spacing) * 0.46 - parent.spacing
                                height: parent.height
                                spacing: 6

                                Rectangle {
                                    width: parent.width
                                    height: (parent.height - parent.spacing) * 0.36
                                    radius: 5
                                    color: Theme.alpha(Theme.text, 0.075)
                                    border.width: 1
                                    border.color: "#393939"

                                    Text {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 7
                                        text: "03"
                                        color: Theme.textSoft
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                    }

                                }

                                Rectangle {
                                    width: parent.width
                                    height: (parent.height - parent.spacing) * 0.64
                                    radius: 5
                                    color: Theme.alpha(Theme.text, 0.045)
                                    border.width: 1
                                    border.color: "#393939"

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 7
                                        spacing: 5

                                        Text {
                                            text: "04 / SPLIT"
                                            color: Theme.textDim
                                            font.family: Theme.monoFont
                                            font.pixelSize: 8
                                        }

                                        Rectangle {
                                            width: parent.width * 0.72
                                            height: 4
                                            radius: 2
                                            color: Theme.alpha(Theme.text, 0.2)
                                        }

                                    }

                                }

                            }

                        }

                        Row {
                            visible: page.layout === "master"
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Rectangle {
                                width: (parent.width - parent.spacing) * 0.59
                                height: parent.height
                                radius: 5
                                color: Theme.alpha(Theme.accent, 0.15)
                                border.width: 1
                                border.color: "#393939"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 5

                                    Text {
                                        text: "MASTER"
                                        color: Theme.accent
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                    }

                                    Rectangle {
                                        width: parent.width * 0.8
                                        height: 4
                                        radius: 2
                                        color: Theme.accent
                                    }

                                    Rectangle {
                                        width: parent.width * 0.57
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.accent, 0.58)
                                    }

                                    Item {
                                        width: 1
                                        height: Math.max(1, parent.height - 49)
                                    }

                                    Text {
                                        text: page.masterStatus.toUpperCase()
                                        color: Theme.text
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }

                                }

                            }

                            Column {
                                width: parent.width - (parent.width - parent.spacing) * 0.59 - parent.spacing
                                height: parent.height
                                spacing: 6

                                Rectangle {
                                    width: parent.width
                                    height: (parent.height - parent.spacing) / 2
                                    radius: 5
                                    color: Theme.alpha(Theme.text, 0.075)
                                    border.width: 1
                                    border.color: "#393939"

                                    Text {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 7
                                        text: "STACK 01"
                                        color: Theme.textSoft
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }

                                }

                                Rectangle {
                                    width: parent.width
                                    height: (parent.height - parent.spacing) / 2
                                    radius: 5
                                    color: Theme.alpha(Theme.text, 0.055)
                                    border.width: 1
                                    border.color: "#393939"

                                    Text {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 7
                                        text: "STACK 02"
                                        color: Theme.textDim
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }

                                }

                            }

                        }

                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        height: 22

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 22
                            radius: 6
                            color: Theme.alpha(Theme.text, 0.045)

                            Text {
                                anchors.centerIn: parent
                                text: "DIRECTION  ·  " + page.scrollDirection.toUpperCase()
                                color: Theme.accent
                                font.family: Theme.monoFont
                                font.pixelSize: 8
                            }

                        }

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 22
                            radius: 6
                            color: Theme.alpha(Theme.text, 0.045)

                            Text {
                                anchors.centerIn: parent
                                text: "COLUMN  ·  " + Math.round(page.columnWidth * 100) + "%"
                                color: Theme.accent
                                font.family: Theme.monoFont
                                font.pixelSize: 8
                            }

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
                id: generalSelector2

                width: parent.width
                spacing: 7

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

            WidthChips {
                value: page.explicitColumnWidths
                onChanged: (v) => {
                    page.explicitColumnWidths = v;
                    page.applyLive("scrolling:explicit_column_widths", v);
                    page.setBlockField("scrolling", "explicit_column_widths", v, false, true);
                }
            }

            Text {
                text: "DWINDLE / MASTER"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
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

            Rectangle {
                width: parent.width
                height: generalSelector3.implicitHeight + 14
                radius: 9
                color: Theme.alpha(Theme.text, 0.018)
                border.width: 1
                border.color: "#393939"

                Flow {
                    id: generalSelector3

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    anchors.topMargin: 7
                    height: implicitHeight
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

            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#383838"
            }

            Text {
                text: "GAPS"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                topPadding: 4
            }

            Text {
                text: "SPACING PRESETS"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.1
            }

            Flow {
                width: parent.width
                spacing: 7

                Repeater {
                    model: [{
                        "label": "COMPACT",
                        "gapIn": 2,
                        "gapOut": 6,
                        "icon": "\uf066"
                    }, {
                        "label": "BALANCED",
                        "gapIn": 5,
                        "gapOut": 10,
                        "icon": "\uf0c8"
                    }, {
                        "label": "SPACIOUS",
                        "gapIn": 8,
                        "gapOut": 16,
                        "icon": "\uf065"
                    }]

                    delegate: Segment {
                        required property var modelData

                        icon: modelData.icon
                        label: modelData.label
                        selected: page.gapsIn === modelData.gapIn && page.gapsOut === modelData.gapOut
                        onClicked: page.applyGapPreset(modelData.gapIn, modelData.gapOut)
                    }

                }

            }

            Rectangle {
                id: gapFieldPreview

                width: parent.width
                height: 222
                radius: 14
                color: Theme.bgPanel
                border.width: 1
                border.color: "#393939"

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 24
                        spacing: 8

                        Column {
                            spacing: 1

                            Text {
                                text: "GAP FIELD"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                text: "SPATIAL GEOMETRY / LIVE"
                                color: Theme.textDim
                                font.family: Theme.monoFont
                                font.pixelSize: 8
                                font.letterSpacing: 0.65
                            }

                        }

                        Item {
                            width: Math.max(1, parent.width - 180)
                            height: 1
                        }

                        Text {
                            text: "OUT " + page.gapsOut + "px"
                            color: Theme.accent
                            font.family: Theme.monoFont
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 126
                        radius: 9
                        color: Theme.bgCard
                        border.width: 1
                        border.color: "#393939"

                        Rectangle {
                            id: gapWorkspaceBoundary

                            anchors.fill: parent
                            anchors.margins: Math.min(20, Math.max(4, 4 + page.gapsOut * 0.58))
                            radius: 5
                            color: "transparent"
                            border.width: 1
                            border.color: "#393939"

                            Column {
                                id: gapTilesColumn

                                property real innerGap: Math.min(18, Math.max(2, 2 + page.gapsIn * 0.72))

                                anchors.fill: parent
                                spacing: innerGap
                                anchors.margins: 0

                                Row {
                                    width: parent.width
                                    height: Math.max(18, (parent.height - parent.spacing) / 2)
                                    spacing: gapTilesColumn.innerGap

                                    Rectangle {
                                        width: (parent.width - parent.spacing) / 2
                                        height: parent.height
                                        radius: 4
                                        color: Theme.alpha(Theme.text, 0.2)
                                        border.width: 1
                                        border.color: "#393939"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 5
                                            text: "01"
                                            color: Theme.text
                                            font.family: Theme.monoFont
                                            font.pixelSize: 9
                                        }

                                    }

                                    Rectangle {
                                        width: (parent.width - parent.spacing) / 2
                                        height: parent.height
                                        radius: 4
                                        color: Theme.alpha(Theme.text, 0.075)
                                        border.width: 1
                                        border.color: "#393939"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 5
                                            text: "02"
                                            color: Theme.textSoft
                                            font.family: Theme.monoFont
                                            font.pixelSize: 9
                                        }

                                    }

                                }

                                Row {
                                    width: parent.width
                                    height: Math.max(18, (parent.height - parent.spacing) / 2)
                                    spacing: gapTilesColumn.innerGap

                                    Rectangle {
                                        width: (parent.width - parent.spacing) / 2
                                        height: parent.height
                                        radius: 4
                                        color: Theme.alpha(Theme.text, 0.075)
                                        border.width: 1
                                        border.color: "#393939"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 5
                                            text: "03"
                                            color: Theme.textSoft
                                            font.family: Theme.monoFont
                                            font.pixelSize: 9
                                        }

                                    }

                                    Rectangle {
                                        width: (parent.width - parent.spacing) / 2
                                        height: parent.height
                                        radius: 4
                                        color: Theme.alpha(Theme.text, 0.075)
                                        border.width: 1
                                        border.color: "#393939"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 5
                                            text: "04"
                                            color: Theme.textSoft
                                            font.family: Theme.monoFont
                                            font.pixelSize: 9
                                        }

                                    }

                                }

                            }

                        }

                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        height: 23

                        Rectangle {
                            radius: 6
                            color: Theme.alpha(Theme.text, 0.045)
                            height: 23
                            width: (parent.width - 8) / 2

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: "↔"
                                    color: Theme.accent
                                    font.pixelSize: 11
                                }

                                Text {
                                    text: "INNER  " + page.gapsIn + "px"
                                    color: "#dce2ee"
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                }

                            }

                        }

                        Rectangle {
                            radius: 6
                            color: Theme.alpha(Theme.text, 0.045)
                            height: 23
                            width: (parent.width - 8) / 2

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: "□"
                                    color: Theme.accent
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: "OUTER  " + page.gapsOut + "px"
                                    color: "#dce2ee"
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                }

                            }

                        }

                    }

                }

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
                color: Theme.bgCard
            }

            Text {
                text: "DECORATION"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                topPadding: 4
            }

            Text {
                text: "VISUAL PRESETS"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.1
            }

            Flow {
                width: parent.width
                spacing: 7

                Repeater {
                    model: [{
                        "label": "MIDNIGHT",
                        "value": "midnight",
                        "icon": "\uf186"
                    }, {
                        "label": "BALANCED",
                        "value": "balanced",
                        "icon": "\uf0c8"
                    }, {
                        "label": "MONOLITH",
                        "value": "monolith",
                        "icon": "\uf096"
                    }]

                    delegate: Segment {
                        required property var modelData

                        icon: modelData.icon
                        label: modelData.label
                        selected: page.visualPresetMatches(modelData.value)
                        onClicked: page.applyVisualPreset(modelData.value)
                    }

                }

            }

            Rectangle {
                id: decorationSurfaceLab

                width: parent.width
                height: 251
                radius: 14
                color: Theme.bgPanel
                border.width: 1
                border.color: "#393939"

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 25
                        spacing: 8

                        Column {
                            spacing: 1

                            Text {
                                text: "SURFACE LAB"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                text: "COMPOSITOR / RENDERING"
                                color: Theme.textDim
                                font.family: Theme.monoFont
                                font.pixelSize: 8
                                font.letterSpacing: 0.65
                            }

                        }

                        Item {
                            width: Math.max(1, parent.width - 70)
                            height: 1
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 5
                            color: Theme.alpha(Theme.accent, 0.12)
                            height: 22
                            width: 54

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 3
                                    color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "LIVE"
                                    color: Theme.accent
                                    font.family: Theme.monoFont
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }

                            }

                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 110
                        radius: 9
                        color: Theme.bgCard
                        border.width: 1
                        border.color: "#393939"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 7

                            Rectangle {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height
                                radius: Math.min(24, Math.max(0, page.rounding))
                                color: Theme.alpha(Theme.accent, 0.12)
                                opacity: page.activeOpacity
                                border.width: Math.max(1, Math.min(3, page.borderSize))
                                border.color: "#393939"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 6

                                    Row {
                                        spacing: 3

                                        Rectangle {
                                            width: 5
                                            height: 5
                                            radius: 3
                                            color: Theme.danger
                                        }

                                        Rectangle {
                                            width: 5
                                            height: 5
                                            radius: 3
                                            color: Theme.accent
                                        }

                                        Rectangle {
                                            width: 5
                                            height: 5
                                            radius: 3
                                            color: Theme.accent
                                        }

                                        Item {
                                            width: Math.max(1, parent.width - 70)
                                            height: 1
                                        }

                                        Text {
                                            text: "ACTIVE"
                                            color: Theme.text
                                            font.family: Theme.monoFont
                                            font.pixelSize: 7
                                            font.weight: Font.DemiBold
                                        }

                                    }

                                    Rectangle {
                                        width: parent.width * 0.78
                                        height: 4
                                        radius: 2
                                        color: Theme.accent
                                    }

                                    Rectangle {
                                        width: parent.width * 0.57
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.accent, 0.62)
                                    }

                                    Rectangle {
                                        width: parent.width * 0.68
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.accent, 0.4)
                                    }

                                    Item {
                                        width: 1
                                        height: Math.max(1, parent.height - 60)
                                    }

                                    Text {
                                        text: "EDITOR"
                                        color: Theme.text
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }

                                }

                            }

                            Rectangle {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height
                                radius: Math.min(24, Math.max(0, page.rounding))
                                color: page.blurEnabled ? Theme.alpha(Theme.accent, 0.09) : Theme.bgCard
                                opacity: page.inactiveOpacity
                                border.width: 1
                                border.color: "#393939"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 6

                                    Text {
                                        text: "INACTIVE"
                                        color: Theme.textDim
                                        font.family: Theme.monoFont
                                        font.pixelSize: 7
                                        font.weight: Font.DemiBold
                                    }

                                    Rectangle {
                                        width: parent.width * 0.78
                                        height: 4
                                        radius: 2
                                        color: Theme.textDim
                                    }

                                    Rectangle {
                                        width: parent.width * 0.53
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.text, 0.18)
                                    }

                                    Rectangle {
                                        width: parent.width * 0.65
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.text, 0.14)
                                    }

                                    Item {
                                        width: 1
                                        height: Math.max(1, parent.height - 60)
                                    }

                                    Text {
                                        text: "TERMINAL"
                                        color: Theme.textSoft
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }

                                }

                            }

                        }

                    }

                    Row {
                        width: parent.width
                        spacing: 6
                        height: 40

                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 40
                            radius: 6
                            color: Theme.bgCard

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    text: "RADIUS"
                                    color: Theme.textDim
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 0.5
                                }

                                Text {
                                    text: page.rounding + " px"
                                    color: Theme.text
                                    font.family: Theme.monoFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                            }

                        }

                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 40
                            radius: 6
                            color: Theme.bgCard

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    text: "BLUR"
                                    color: Theme.textDim
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 0.5
                                }

                                Text {
                                    text: page.blurEnabled ? page.blurSize + " px / " + page.blurPasses + "P" : "OFF"
                                    color: page.blurEnabled ? Theme.accent : Theme.textFaint
                                    font.family: Theme.monoFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                            }

                        }

                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 40
                            radius: 6
                            color: Theme.bgCard

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    text: "SHADOW"
                                    color: Theme.textDim
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 0.5
                                }

                                Text {
                                    text: page.shadowEnabled ? "ON / " + page.shadowRange : "OFF"
                                    color: page.shadowEnabled ? Theme.accent : Theme.textFaint
                                    font.family: Theme.monoFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                            }

                        }

                    }

                }

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
                }
                onCommitted: (v) => {
                    page.inactiveOpacity = v;
                    page.setBlockField("decoration", "inactive_opacity", v);
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.bgCard
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
                }
                onCommitted: (v) => {
                    page.blurPasses = Math.round(v * 10);
                    page.setBlockField("blur", "passes", page.blurPasses, false, false, true);
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.bgCard
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
                }
                onCommitted: (v) => {
                    page.shadowRenderPower = Math.round(v * 10);
                    page.setBlockField("shadow", "render_power", page.shadowRenderPower, false, false, true);
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.bgCard
            }

            Text {
                text: "ANIMATIONS & CURVES"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                topPadding: 5
            }

            Text {
                text: "Configure window, fade, layer and workspace transitions"
                color: Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            ToggleRow {
                visible: page.animationFileReady
                label: "ENABLE ALL ANIMATIONS"
                checked: page.animationEnabled
                onToggled: (enabled) => {
                    return page.setAnimationMasterEnabled(enabled);
                }
            }

            Text {
                visible: page.animationFileReady
                text: "ANIMATION PRESETS"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.1
                topPadding: 4
            }

            Flow {
                visible: page.animationFileReady
                width: parent.width
                spacing: 7

                Repeater {
                    model: page.animationPresetOptions()

                    delegate: LayoutOption {
                        required property var modelData

                        label: modelData.label
                        description: modelData.description
                        icon: modelData.icon
                        selected: page.animationPreset === modelData.value
                        onClicked: page.applyAnimationPreset(modelData.value)
                    }

                }

            }

            Text {
                visible: page.animationFileReady
                text: page.animationPreset === "custom" ? "CUSTOM ANIMATION CONFIGURATION" : ("ACTIVE PRESET  ·  " + page.animationPreset.toUpperCase())
                color: page.animationPreset === "custom" ? Theme.textFaint : Theme.accent
                font.family: Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 0.7
            }

            Text {
                visible: page.animationFileReady
                text: "CURVE VISUALIZER"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1.1
                topPadding: 5
            }

            Text {
                visible: page.animationFileReady
                text: "GLOBAL VIEW · SELECT A CURVE TO HIGHLIGHT IT"
                color: Theme.textFaint
                font.family: Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 0.45
            }

            Flow {
                visible: page.animationFileReady && page.curveEntries.length > 0
                width: parent.width
                spacing: 6

                Repeater {
                    model: page.animationFileReady ? page.curveEntries : []

                    delegate: Segment {
                        required property var modelData

                        label: modelData.name.toUpperCase()
                        selected: page.selectedCurveName === modelData.name
                        onClicked: {
                            page.selectedCurveName = modelData.name;
                            curveGraph.requestPaint();
                        }
                    }

                }

            }

            Rectangle {
                visible: page.animationFileReady && page.curveEntries.length > 0
                width: parent.width
                height: 260
                radius: 12
                color: Theme.alpha(Theme.text, 0.018)
                border.width: 1
                border.color: "#393939"

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Row {
                        width: parent.width
                        height: 23
                        spacing: 8

                        Text {
                            width: parent.width - curveTypeBadge.implicitWidth - 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.selectedCurveName ? page.selectedCurveName.toUpperCase() : "CURVE"
                            color: Theme.text
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            id: curveTypeBadge

                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                const entry = page.curveEntries.find(function(item) {
                                    return item.name === page.selectedCurveName;
                                });
                                return entry ? entry.type.toUpperCase() : "";
                            }
                            color: Theme.accent
                            font.family: Theme.monoFont
                            font.pixelSize: 9
                            font.letterSpacing: 0.6
                        }

                    }

                    Canvas {
                        id: curveGraph

                        width: parent.width
                        height: 190
                        antialiasing: true
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const left = 31;
                            const right = 12;
                            const top = 12;
                            const bottom = 24;
                            const plotWidth = Math.max(1, width - left - right);
                            const plotHeight = Math.max(1, height - top - bottom);
                            const yMin = -0.2;
                            const yMax = 1.2;
                            const px = function px(x) {
                                return left + Math.max(0, Math.min(1, x)) * plotWidth;
                            };
                            const py = function py(y) {
                                return top + (yMax - y) / (yMax - yMin) * plotHeight;
                            };
                            ctx.font = "9px monospace";
                            ctx.textBaseline = "middle";
                            ctx.textAlign = "right";
                            ctx.fillStyle = Theme.textFaint;
                            [0, 0.5, 1].forEach(function(value) {
                                const y = py(value);
                                ctx.beginPath();
                                ctx.moveTo(left, y);
                                ctx.lineTo(left + plotWidth, y);
                                ctx.lineWidth = value === 0 ? 1.2 : 1;
                                ctx.strokeStyle = "#393939";
                                ctx.stroke();
                                ctx.fillText(value.toFixed(1), left - 7, y);
                            });
                            ctx.textAlign = "center";
                            ctx.textBaseline = "top";
                            [0, 0.25, 0.5, 0.75, 1].forEach(function(value) {
                                const x = px(value);
                                ctx.beginPath();
                                ctx.moveTo(x, top);
                                ctx.lineTo(x, top + plotHeight);
                                ctx.lineWidth = 1;
                                ctx.strokeStyle = "#393939";
                                ctx.stroke();
                                ctx.fillStyle = Theme.textFaint;
                                ctx.fillText(value === 0 || value === 1 ? value.toFixed(0) : value.toFixed(2), x, top + plotHeight + 7);
                            });
                            ctx.save();
                            ctx.beginPath();
                            ctx.rect(left, top, plotWidth, plotHeight);
                            ctx.clip();
                            const selected = page.curveEntries.find(function(entry) {
                                return entry.name === page.selectedCurveName;
                            });
                            const drawCurve = function drawCurve(entry, color, lineWidth) {
                                if (!entry)
                                    return ;

                                ctx.beginPath();
                                for (let i = 0; i <= 120; i++) {
                                    const point = page.curveGraphPoint(entry, i / 120);
                                    const x = px(point.x);
                                    const y = py(point.y);
                                    if (i === 0)
                                        ctx.moveTo(x, y);
                                    else
                                        ctx.lineTo(x, y);
                                }
                                ctx.strokeStyle = color;
                                ctx.lineWidth = lineWidth;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.stroke();
                            };
                            if (selected) {
                                const area = ctx.createLinearGradient(0, top, 0, top + plotHeight);
                                area.addColorStop(0, Theme.alpha(Theme.accent, 0.2));
                                area.addColorStop(1, Theme.alpha(Theme.accent, 0.015));
                                ctx.beginPath();
                                for (let i = 0; i <= 120; i++) {
                                    const point = page.curveGraphPoint(selected, i / 120);
                                    if (i === 0)
                                        ctx.moveTo(px(point.x), py(point.y));
                                    else
                                        ctx.lineTo(px(point.x), py(point.y));
                                }
                                ctx.lineTo(px(1), py(0));
                                ctx.lineTo(px(0), py(0));
                                ctx.closePath();
                                ctx.fillStyle = area;
                                ctx.fill();
                            }
                            page.curveEntries.forEach(function(entry) {
                                if (entry.name !== page.selectedCurveName)
                                    drawCurve(entry, Theme.alpha(Theme.text, 0.2), 1.15);

                            });
                            if (selected) {
                                drawCurve(selected, Theme.alpha(Theme.accent, 0.2), 6);
                                drawCurve(selected, Theme.alpha(Theme.accent, 0.98), 2.3);
                                const startPoint = page.curveGraphPoint(selected, 0);
                                const endPoint = page.curveGraphPoint(selected, 1);
                                [startPoint, endPoint].forEach(function(point) {
                                    ctx.beginPath();
                                    ctx.arc(px(point.x), py(point.y), 3.2, 0, Math.PI * 2);
                                    ctx.fillStyle = Theme.background;
                                    ctx.fill();
                                    ctx.lineWidth = 1.5;
                                    ctx.strokeStyle = "#393939";
                                    ctx.stroke();
                                });
                                const point = page.curveGraphPoint(selected, page.curvePreviewProgress);
                                const cx = px(point.x);
                                const cy = py(point.y);
                                ctx.beginPath();
                                ctx.moveTo(cx, top + plotHeight);
                                ctx.lineTo(cx, cy);
                                ctx.lineWidth = 1;
                                ctx.strokeStyle = "#393939";
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.arc(cx, cy, 7, 0, Math.PI * 2);
                                ctx.fillStyle = Theme.alpha(Theme.accent, 0.18);
                                ctx.fill();
                                ctx.beginPath();
                                ctx.arc(cx, cy, 3.4, 0, Math.PI * 2);
                                ctx.fillStyle = Theme.accent;
                                ctx.fill();
                                ctx.lineWidth = 1.2;
                                ctx.strokeStyle = Theme.background;
                                ctx.stroke();
                            }
                            ctx.restore();
                        }
                    }

                    Text {
                        width: parent.width
                        text: "PROFILE PREVIEW  ·  WINDOWS MOVE  ·  SPEED " + Number(page.curvePreviewSpeed).toFixed(1) + "  ·  " + page.animationPreset.toUpperCase()
                        color: Theme.textFaint
                        font.family: Theme.monoFont
                        font.pixelSize: 8
                        font.letterSpacing: 0.35
                        horizontalAlignment: Text.AlignRight
                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#393939"
            }

            Text {
                text: "MISC / XWAYLAND"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
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

            Rectangle {
                width: parent.width
                height: 1
                color: "#393939"
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
            var m = str.match(/rgba?\(([0-9a-fA-F]{6,8})\)/i) || str.match(/#([0-9a-fA-F]{6,8})/i);
            if (m) {
                var c = Qt.color("#" + m[1].slice(0, 6));
                hue = c.hslHue;
                sat = c.hslSaturation;
                light = c.hslLightness;
            } else {
                hue = 0;
                sat = 0;
                light = 0.5;
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
            color: Qt.rgba(0, 0, 0, 0.8)
            radius: 18
            border.width: 1
            border.color: "#393939"
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
                    border.color: "#393939"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: colorPopup.target === "active" ? "ACTIVE BORDER" : "INACTIVE BORDER"
                        color: Theme.textFaint
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
                        color: Theme.textGhost
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
                    color: Theme.textFaint
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
                        border.color: "#393939"
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
                    color: Theme.textFaint
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
                        border.color: "#393939"
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
                    color: Theme.textFaint
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
                        border.color: "#393939"
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
                    border.color: "#393939"

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
                    border.color: "#393939"

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

    NumberAnimation on curvePreviewProgress {
        from: 0
        to: 1
        duration: page.curvePreviewDuration
        loops: Animation.Infinite
        running: page.animationFileReady && page.curveEntries.length > 0
    }

    component ColorRow: Item {
        id: colorRowRoot

        property string label: ""
        property string colorValue: ""
        property bool hovered: false

        signal clicked()

        width: parent.width
        height: 42

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: colorRowRoot.hovered ? Theme.alpha(Theme.accent, 0.035) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }

            }

        }

        HoverHandler {
            onHoveredChanged: colorRowRoot.hovered = hovered
        }

        Text {
            id: colorLabel

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(94, Math.min(130, colorRowRoot.width * 0.27))
            text: colorRowRoot.label
            color: Theme.textDim
            font.family: Theme.monoFont
            font.pixelSize: 10
            font.letterSpacing: 1
            elide: Text.ElideRight
        }

        Rectangle {
            id: swatch

            anchors.left: colorLabel.right
            anchors.leftMargin: 8
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
            border.width: 0

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
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: 7
            color: Theme.alpha(Theme.text, 0.025)
            border.width: 1
            border.color: rowHover.containsMouse ? "#555555" : "#393939"

            HoverHandler {
                id: rowHover
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 30
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
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
                var valueText = Number(n).toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
                return valueText === "" ? "0" : valueText;
            }).join(",");
        }

        function updateAt(idx, newVal) {
            if (idx < 0 || idx >= widths.length || !isFinite(newVal))
                return ;

            var arr = widths.slice();
            arr[idx] = Math.max(0.1, Math.min(1, newVal));
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

        function addPreset(value) {
            if (widths.some(function(n) {
                return Math.abs(n - value) < 0.005;
            }))
                return ;

            var arr = widths.slice();
            arr.push(value);
            widths = arr;
            changed(buildString());
        }

        function add() {
            addPreset(0.5);
        }

        width: parent.width
        height: chipColumn.implicitHeight + 4
        onValueChanged: parseWidths()
        Component.onCompleted: parseWidths()

        Column {
            id: chipColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 7

            Text {
                text: "QUICK WIDTHS"
                color: Theme.textGhost
                font.family: Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 1.1
            }

            Flow {
                width: parent.width
                spacing: 5

                Repeater {
                    model: [{
                        "label": "⅓",
                        "value": 0.333
                    }, {
                        "label": "½",
                        "value": 0.5
                    }, {
                        "label": "⅔",
                        "value": 0.667
                    }, {
                        "label": "¾",
                        "value": 0.75
                    }, {
                        "label": "FULL",
                        "value": 1
                    }]

                    delegate: Segment {
                        required property var modelData

                        label: modelData.label
                        selected: chipsRoot.widths.some(function(n) {
                            return Math.abs(n - modelData.value) < 0.005;
                        })
                        onClicked: chipsRoot.addPreset(modelData.value)
                    }

                }

            }

            Text {
                text: "EXPLICIT COLUMN WIDTHS"
                color: Theme.textGhost
                font.family: Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 1.1
            }

            Flow {
                id: chipFlow

                width: parent.width
                spacing: 6

                Repeater {
                    model: chipsRoot.widths

                    delegate: Item {
                        id: chip

                        required property real modelData
                        required property int index
                        property bool editing: false

                        width: editing ? 88 : (chipLabel.implicitWidth + 42)
                        height: 32

                        Rectangle {
                            visible: !chip.editing
                            anchors.fill: parent
                            radius: 9
                            color: chipMouse.containsMouse ? Theme.alpha(Theme.accent, 0.12) : Theme.alpha(Theme.text, 0.045)

                            Text {
                                id: chipLabel

                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    var n = Number(chip.modelData).toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
                                    return n === "" ? "0" : n;
                                }
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Text {
                                visible: chipMouse.containsMouse || removeArea.containsMouse
                                anchors.right: parent.right
                                anchors.rightMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                color: removeArea.containsMouse ? "#ff7777" : Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: chipMouse

                                anchors.fill: parent
                                anchors.rightMargin: 24
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: chip.editing = true
                            }

                            MouseArea {
                                id: removeArea

                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 26
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: chipsRoot.removeAt(chip.index)
                            }

                        }

                        Rectangle {
                            visible: chip.editing
                            anchors.fill: parent
                            radius: 8
                            color: Theme.alpha(Theme.accent, 0.08)

                            TextField {
                                id: editField

                                anchors.fill: parent
                                anchors.margins: 3
                                text: Number(chip.modelData).toFixed(2).replace(/0+$/, "").replace(/\.$/, "")
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 11
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
                    radius: 9
                    color: addHover.containsMouse ? Theme.alpha(Theme.accent, 0.14) : Theme.alpha(Theme.text, 0.045)

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

            Text {
                text: "WIDTH PREVIEW"
                color: Theme.textDim
                font.family: Theme.monoFont
                font.pixelSize: 9
                font.letterSpacing: 1.1
            }

            Rectangle {
                width: parent.width
                height: 178
                radius: 14
                color: Theme.bgPanel
                border.width: 1
                border.color: "#393939"

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 20
                        spacing: 8

                        Text {
                            id: widthLabel

                            text: "COLUMN WIDTHS"
                            color: Theme.text
                            font.family: Theme.monoFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.7
                        }

                        Item {
                            width: Math.max(1, parent.width - widthLabel.implicitWidth - widthState.implicitWidth - 16)
                            height: 1
                        }

                        Text {
                            id: widthState

                            text: chipsRoot.widths.length ? chipsRoot.widths.length + " PRESETS" : "DEFAULT"
                            color: Theme.accent
                            font.family: Theme.monoFont
                            font.pixelSize: 8
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    Flow {
                        width: parent.width
                        spacing: 7

                        Repeater {
                            model: chipsRoot.widths.length ? chipsRoot.widths.slice(0, 6) : [0.5]

                            delegate: Rectangle {
                                required property real modelData
                                required property int index

                                width: Math.max(100, Math.min(176, (parent.width - 14) / 3))
                                height: 118
                                radius: 8
                                color: Theme.bgCard
                                border.width: 1
                                border.color: "#393939"
                                clip: true

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 6

                                    Text {
                                        text: "0" + (index + 1)
                                        color: Theme.textDim
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                    }

                                    Item {
                                        width: parent.width
                                        height: 72

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4
                                            color: Theme.alpha(Theme.text, 0.025)
                                            border.width: 1
                                            border.color: "#393939"
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: Math.max(8, (parent.width - 2) * Math.max(0.1, Math.min(1, Number(modelData) || 0.5)))
                                            radius: 4
                                            color: Theme.alpha(Theme.accent, 0.13)
                                            border.width: 1
                                            border.color: "#393939"

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                height: 5
                                                radius: 3
                                                color: Theme.alpha(Theme.accent, 0.28)
                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

    }

    component LayoutOption: Item {
        id: layoutOptionRoot

        property string label: ""
        property string description: ""
        property string icon: ""
        property bool selected: false
        property bool hovered: false

        signal clicked()

        width: Math.max(118, (parent.width - 14) / 3)
        height: 78

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: layoutOptionRoot.selected ? Theme.alpha(Theme.accent, 0.12) : (layoutOptionRoot.hovered ? Theme.alpha(Theme.text, 0.045) : "transparent")
            border.width: 1
            border.color: layoutOptionRoot.hovered ? "#555555" : "#393939"

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }

            }

        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 9

            Column {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Row {
                    spacing: 7

                    Text {
                        text: layoutOptionRoot.icon
                        color: layoutOptionRoot.selected ? Theme.accent : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: layoutOptionRoot.label
                        color: layoutOptionRoot.selected ? Theme.accent : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                Text {
                    width: parent.width
                    text: layoutOptionRoot.description
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

            }

        }

        HoverHandler {
            onHoveredChanged: layoutOptionRoot.hovered = hovered
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: layoutOptionRoot.clicked()
            onEntered: layoutOptionRoot.hovered = true
            onExited: layoutOptionRoot.hovered = false
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

        width: parent.width
        height: 42

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: sliderRoot.hovered ? Theme.alpha(Theme.accent, 0.035) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }

            }

        }

        HoverHandler {
            onHoveredChanged: sliderRoot.hovered = hovered
        }

        Rectangle {
            id: iconBox

            width: 26
            height: 26
            radius: 8
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.bgPanel
            border.width: 1
            border.color: "#393939"

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
            width: Math.max(78, Math.min(110, sliderRoot.width * 0.25))
            text: sliderRoot.label
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1.2
            elide: Text.ElideRight
        }

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
            onMoved: (v) => {
                return sliderRoot.moved(v);
            }
            onCommitted: (v) => {
                return sliderRoot.committed(v);
            }
        }

        Connections {
            function onValueChanged() {
                if (Math.abs(sliderControl.value - sliderRoot.value) > 1e-06)
                    sliderControl.value = sliderRoot.value;

            }

            target: sliderRoot
        }

    }

    component ToggleRow: Item {
        id: toggleRoot

        property string label: ""
        property bool checked: false
        property bool hovered: false

        signal toggled(bool value)

        width: parent.width
        height: 38

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: toggleRoot.hovered ? Theme.alpha(Theme.accent, 0.035) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }

            }

        }

        HoverHandler {
            onHoveredChanged: toggleRoot.hovered = hovered
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(30, parent.width - 12 - 38 - 28)
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
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: toggleRoot.checked ? Theme.accent : Theme.bgPanel
            border.width: 0

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
        property string icon: ""
        property bool selected: false

        signal clicked()

        width: segText.implicitWidth + (icon !== "" ? 34 : 24)
        height: 30
        radius: Theme.radiusXs
        color: selected ? Theme.alpha(Theme.accent, 0.075) : (segMouse.containsMouse ? Theme.alpha(Theme.accent, 0.035) : "transparent")
        border.width: 1
        border.color: segMouse.containsMouse ? "#555555" : "#393939"

        Text {
            id: segText

            anchors.centerIn: parent
            text: parent.icon !== "" ? parent.icon + "  " + parent.label : parent.label
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
