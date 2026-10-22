import "../"
import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io

Item {
    id: page

    property var monitors: []
    property var savedState: ({
    })
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"
    readonly property string monitorConfigPath: Quickshell.env("HOME") + "/.config/hypr/monitors.lua"
    readonly property var activeMonitors: monitors.filter((m) => {
        return !m.disabled;
    })
    property var pendingScaleMonitor: null
    property real pendingScaleValue: 1
    property string pendingMonitorConfigText: ""
    property bool monitorConfigWritePending: false
    property bool monitorConfigWriteInProgress: false
    readonly property var bboxCenter: {
        if (activeMonitors.length === 0)
            return {
            "x": 0,
            "y": 0
        };

        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (let i = 0; i < activeMonitors.length; i++) {
            const m = activeMonitors[i];
            const s = m.scale > 0 ? m.scale : 1;
            const x1 = Number(m.x || 0);
            const y1 = Number(m.y || 0);
            const x2 = x1 + m.width / s;
            const y2 = y1 + m.height / s;
            minX = Math.min(minX, x1, x2);
            minY = Math.min(minY, y1, y2);
            maxX = Math.max(maxX, x1, x2);
            maxY = Math.max(maxY, y1, y2);
        }
        return {
            "x": (minX + maxX) / 2,
            "y": (minY + maxY) / 2
        };
    }

    function loadState() {
        try {
            const saved = JSON.parse(displayFile.text());
            if (saved && typeof saved.monitors === "object" && saved.monitors !== null)
                savedState = saved.monitors;

        } catch (error) {
            console.warn("Display: could not read saved monitor state: " + error);
        }
    }

    function rememberMonitor(mon, fields) {
        if (!mon || !mon.name)
            return ;

        const next = Object.assign({
        }, savedState);
        next[mon.name] = Object.assign({
        }, next[mon.name] || {
        }, fields);
        savedState = next;
        stateSaveTimer.restart();
    }

    function resetToConfig() {
        stateSaveTimer.stop();
        savedState = ({
        });
        pReset.command = ["sh", "-c", "rm -f '" + page.stateDir + "/display.json'; hyprctl reload"];
        pReset.running = true;
    }

    function monitorMode(mon) {
        if (!mon)
            return "";

        const width = Number(mon.width);
        const height = Number(mon.height);
        const rate = Number(mon.refreshRate);
        if (width > 0 && height > 0 && isFinite(rate) && rate > 0)
            return width + "x" + height + "@" + rate.toFixed(2);

        const modes = mon.availableModes || [];
        if (width > 0 && height > 0) {
            const prefix = width + "x" + height + "@";
            for (let i = 0; i < modes.length; i++) {
                const candidate = String(modes[i]).replace(/Hz$/i, "");
                if (candidate.indexOf(prefix) === 0)
                    return candidate;

            }
        }
        if (modes.length > 0)
            return String(modes[0]).replace(/Hz$/i, "");

        return "";
    }

    function luaString(value) {
        return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }

    function updateMonitorConfig(output, mode, position, scale, disabled) {
        const source = page.pendingMonitorConfigText !== "" ? page.pendingMonitorConfigText : monitorConfigFile.text();
        if (typeof source !== "string" || source.length === 0) {
            console.warn("Display: could not read " + page.monitorConfigPath);
            return false;
        }
        const calls = /hl\.monitor\s*\(\s*\{[\s\S]*?\}\s*\)/g;
        let match;
        let updatedSource = source;
        let found = false;
        while ((match = calls.exec(source)) !== null) {
            let block = match[0];
            const outputMatch = block.match(/\boutput\s*=\s*(["'])(.*?)\1/);
            if (!outputMatch || outputMatch[2] !== output)
                continue;

            const replaceStringField = (key, value) => {
                if (value === null || value === undefined)
                    return ;

                const pattern = new RegExp("\\b" + key + "\\s*=\\s*([\"'])([^\"']*)\\1");
                const safeValue = String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
                if (pattern.test(block)) {
                    block = block.replace(pattern, key + ' = "' + safeValue + '"');
                } else {
                    const closing = block.lastIndexOf("}");
                    if (closing < 0)
                        return ;

                    const before = block.slice(0, closing);
                    const trailingMatch = before.match(/\s*$/);
                    const trailing = trailingMatch ? trailingMatch[0] : "";
                    const core = before.slice(0, before.length - trailing.length);
                    const separator = /,\s*$/.test(core) ? " " : ", ";
                    block = core + separator + key + ' = "' + safeValue + '"' + trailing + block.slice(closing);
                }
            };
            const replaceNumberField = (key, value) => {
                if (value === null || value === undefined)
                    return ;

                const number = Number(value);
                if (!isFinite(number) || number <= 0)
                    return ;

                const rendered = number.toFixed(3).replace(/0+$/, "").replace(/\.$/, "");
                const pattern = new RegExp("\\b" + key + "\\s*=\\s*[-+]?(?:\\d+(?:\\.\\d*)?|\\.\\d+)");
                if (pattern.test(block)) {
                    block = block.replace(pattern, key + " = " + rendered);
                } else {
                    const closing = block.lastIndexOf("}");
                    if (closing < 0)
                        return ;

                    const before = block.slice(0, closing);
                    const trailingMatch = before.match(/\s*$/);
                    const trailing = trailingMatch ? trailingMatch[0] : "";
                    const core = before.slice(0, before.length - trailing.length);
                    const separator = /,\s*$/.test(core) ? " " : ", ";
                    block = core + separator + key + " = " + rendered + trailing + block.slice(closing);
                }
            };
            replaceStringField("mode", mode);
            replaceStringField("position", position);
            replaceNumberField("scale", scale);
            if (disabled === true) {
                if (/\bdisabled\s*=\s*(?:true|false)/.test(block)) {
                    block = block.replace(/\bdisabled\s*=\s*(?:true|false)/, "disabled = true");
                } else {
                    const closing = block.lastIndexOf("}");
                    if (closing >= 0) {
                        const before = block.slice(0, closing);
                        const trailingMatch = before.match(/\s*$/);
                        const trailing = trailingMatch ? trailingMatch[0] : "";
                        const core = before.slice(0, before.length - trailing.length);
                        const separator = /,\s*$/.test(core) ? " " : ", ";
                        block = core + separator + "disabled = true" + trailing + block.slice(closing);
                    }
                }
            } else if (disabled === false && /\bdisabled\s*=\s*(?:true|false)/.test(block)) {
                block = block.replace(/\bdisabled\s*=\s*(?:true|false)/, "disabled = false");
            }
            updatedSource = source.slice(0, match.index) + block + source.slice(match.index + match[0].length);
            found = true;
            break;
        }
        if (!found) {
            console.warn("Display: no existing hl.monitor entry found for " + output);
            return false;
        }
        if (updatedSource !== source) {
            page.pendingMonitorConfigText = updatedSource;
            page.monitorConfigWritePending = true;
            monitorConfigWriteTimer.restart();
        }
        return true;
    }

    function setPosition(mon, x, y) {
        if (!mon || !mon.name)
            return ;

        const position = Math.round(Number(x)) + "x" + Math.round(Number(y));
        const mode = monitorMode(mon);
        const scale = mon.scale !== undefined ? mon.scale : 1;
        rememberMonitor(mon, {
            "mode": mode,
            "position": position,
            "scale": scale
        });
        updateMonitorConfig(mon.name, mode, position, scale);
    }

    function gluePosition(movedMon, x, y, w, h) {
        if (activeMonitors.length <= 1)
            return {
            "x": Math.round(x),
            "y": Math.round(y)
        };

        let bestDist = Infinity;
        let best = {
            "x": Math.round(x),
            "y": Math.round(y)
        };
        for (let i = 0; i < activeMonitors.length; i++) {
            const other = activeMonitors[i];
            if (other.name === movedMon.name)
                continue;

            const s = other.scale > 0 ? other.scale : 1;
            const ox = Number(other.x || 0);
            const oy = Number(other.y || 0);
            const ow = other.width / s;
            const oh = other.height / s;
            const candidates = [{
                "x": ox + ow,
                "y": y,
                "dist": Math.abs(ox + ow - x)
            }, {
                "x": ox - w,
                "y": y,
                "dist": Math.abs(ox - w - x)
            }, {
                "x": x,
                "y": oy - h,
                "dist": Math.abs(oy - h - y)
            }, {
                "x": x,
                "y": oy + oh,
                "dist": Math.abs(oy + oh - y)
            }];
            for (let c = 0; c < candidates.length; c++) {
                const cand = candidates[c];
                if (cand.dist < bestDist) {
                    bestDist = cand.dist;
                    best = {
                        "x": Math.round(cand.x),
                        "y": Math.round(cand.y)
                    };
                }
            }
        }
        return best;
    }

    function graphScale(graphWidth, graphHeight) {
        if (activeMonitors.length === 0)
            return 0.15;

        const cx = bboxCenter.x;
        const cy = bboxCenter.y;
        let maxHalfW = 150, maxHalfH = 100;
        for (let i = 0; i < activeMonitors.length; i++) {
            const m = activeMonitors[i];
            const s = m.scale > 0 ? m.scale : 1;
            const x1 = Number(m.x || 0) - cx;
            const y1 = Number(m.y || 0) - cy;
            const x2 = x1 + m.width / s;
            const y2 = y1 + m.height / s;
            maxHalfW = Math.max(maxHalfW, Math.abs(x1), Math.abs(x2));
            maxHalfH = Math.max(maxHalfH, Math.abs(y1), Math.abs(y2));
        }
        const margin = 24;
        const availW = Math.max(50, graphWidth / 2 - margin);
        const availH = Math.max(50, graphHeight / 2 - margin);
        return Math.max(0.025, Math.min(availW / maxHalfW, availH / maxHalfH, 0.25));
    }

    function isMain(mon) {
        return !mon.disabled && page.activeMonitors.length > 0 && mon.x === 0 && mon.y === 0;
    }

    function layoutCommands(ordered) {
        const cmds = [];
        let x = 0;
        for (let i = 0; i < ordered.length; i++) {
            const m = ordered[i];
            const mode = monitorMode(m);
            const pos = x + "x0";
            rememberMonitor(m, {
                "mode": mode,
                "position": pos,
                "disabled": false
            });
            const safeScale = Number(m.scale) > 0 ? Number(m.scale) : 1;
            updateMonitorConfig(m.name, mode, pos, safeScale);
            x += Math.round(Number(m.width) / safeScale);
        }
        if (ordered.length > 0)
            cmds.push("hyprctl dispatch focusmonitor '" + ordered[0].name + "'");

        return cmds;
    }

    function setMainMonitor(main) {
        if (!main || !main.name || main.disabled)
            return ;

        const others = page.activeMonitors.filter((m) => {
            return m.name !== main.name;
        }).sort((a, b) => {
            return a.x - b.x;
        });
        const cmds = layoutCommands([main].concat(others));
        pShell.command = ["sh", "-c", cmds.join("; ")];
        pShell.running = true;
    }

    function setMonitorEnabled(mon, enabled) {
        if (!mon || !mon.name)
            return ;

        let cmds = [];
        if (enabled) {
            const entry = savedState[mon.name] || {
            };
            const liveMode = monitorMode(mon);
            const savedMode = typeof entry.mode === "string" && /^\d+x\d+@\d+(?:\.\d+)?$/.test(entry.mode) ? entry.mode : "";
            const mode = savedMode || liveMode;
            if (!mode) {
                console.warn("Display: no valid mode is available to re-enable " + mon.name);
                return ;
            }
            const scaleValue = Number(entry.scale !== undefined ? entry.scale : mon.scale);
            const scale = isFinite(scaleValue) && scaleValue > 0 ? scaleValue : 1;
            const position = typeof entry.position === "string" && /^-?\d+x-?\d+$/.test(entry.position) ? entry.position : (Number(mon.x || 0) + "x" + Number(mon.y || 0));
            rememberMonitor(mon, {
                "mode": mode,
                "scale": scale,
                "position": position,
                "disabled": false
            });
            const configUpdated = updateMonitorConfig(mon.name, mode, position, scale, false);
            if (!configUpdated)
                return ;

            if (!page.monitorConfigWritePending && !page.monitorConfigWriteInProgress)
                configReloadTimer.restart();

        } else {
            if (page.activeMonitors.length <= 1)
                return ;

            const wasMain = isMain(mon);
            rememberMonitor(mon, {
                "mode": monitorMode(mon),
                "scale": mon.scale,
                "disabled": true
            });
            const configUpdated = updateMonitorConfig(mon.name, monitorMode(mon), mon.x + "x" + mon.y, mon.scale !== undefined ? mon.scale : 1, true);
            if (!configUpdated)
                return ;

            cmds.push("hyprctl keyword monitor '" + mon.name + ",disable'");
            if (wasMain) {
                const rest = page.activeMonitors.filter((m) => {
                    return m.name !== mon.name;
                }).sort((a, b) => {
                    return a.x - b.x;
                });
                cmds = cmds.concat(layoutCommands(rest));
            }
        }
        if (cmds.length > 0) {
            pShell.command = ["sh", "-c", cmds.join("; ")];
            pShell.running = true;
        }
    }

    function refresh() {
        pList.running = true;
    }

    function scaleOptions(mon) {
        if (!mon || !mon.width || !mon.height)
            return [];

        const options = [];
        const width = mon.width;
        const height = mon.height;
        for (let i = 84; i <= 1560; i++) {
            const scale = i / 120;
            if (scale < 0.7 || scale > 1.3)
                continue;

            const logicalWidth = width / scale;
            const logicalHeight = height / scale;
            if (Math.abs(logicalWidth - Math.round(logicalWidth)) < 0.01 && Math.abs(logicalHeight - Math.round(logicalHeight)) < 0.01)
                options.push(scale);

        }
        return options;
    }

    function validScale(mon, requested) {
        const options = page.scaleOptions(mon);
        if (options.length === 0)
            return 1;

        let best = options[0];
        let bestDistance = Math.abs(options[0] - requested);
        for (let i = 1; i < options.length; i++) {
            const d = Math.abs(options[i] - requested);
            if (d < bestDistance) {
                best = options[i];
                bestDistance = d;
            }
        }
        return best;
    }

    function hasScaleOptions(mon) {
        return page.scaleOptions(mon).length > 1;
    }

    function setScale(mon, scale, isRetry = false) {
        if (!mon || !mon.name)
            return ;

        const requested = Number(scale);
        const applied = isRetry ? requested : validScale(mon, requested);
        const idx = page.monitors.findIndex((m) => {
            return m.name === mon.name;
        });
        if (idx !== -1) {
            const updated = page.monitors.slice();
            updated[idx] = Object.assign({
            }, updated[idx], {
                "scale": applied
            });
            page.monitors = updated;
        }
        const mode = monitorMode(mon);
        const position = mon.x + "x" + mon.y;
        rememberMonitor(mon, {
            "mode": mode,
            "position": position,
            "scale": applied
        });
        updateMonitorConfig(mon.name, mode, position, applied);
    }

    function resolutionList(mon) {
        if (!mon || !mon.availableModes)
            return [];

        const seen = {
        };
        const items = [];
        for (let i = 0; i < mon.availableModes.length; i++) {
            const match = String(mon.availableModes[i]).match(/^(\d+)x(\d+)@/);
            if (!match)
                continue;

            const key = match[1] + "x" + match[2];
            if (seen[key])
                continue;

            seen[key] = true;
            items.push({
                "key": key,
                "width": parseInt(match[1]),
                "height": parseInt(match[2])
            });
        }
        items.sort((a, b) => {
            return (b.width * b.height - a.width * a.height) || (b.width - a.width);
        });
        return items.slice(0, 6).map((item) => {
            return item.key;
        });
    }

    function bestMode(mon, resolution) {
        if (!mon || !mon.availableModes)
            return null;

        const prefix = resolution + "@";
        let bestRate = null;
        let bestDistance = Infinity;
        for (let i = 0; i < mon.availableModes.length; i++) {
            const mode = String(mon.availableModes[i]);
            if (mode.indexOf(prefix) !== 0)
                continue;

            const rate = parseFloat(mode.substring(prefix.length));
            if (isNaN(rate))
                continue;

            const distance = Math.abs(rate - mon.refreshRate);
            if (distance < bestDistance || (distance === bestDistance && rate > bestRate)) {
                bestRate = rate;
                bestDistance = distance;
            }
        }
        return bestRate === null ? null : prefix + bestRate.toFixed(2);
    }

    function setResolution(mon, mode) {
        if (!mon || !mon.name || !mode)
            return ;

        const scale = mon.scale !== undefined ? mon.scale : 1;
        const position = mon.x + "x" + mon.y;
        rememberMonitor(mon, {
            "mode": mode,
            "position": position,
            "scale": scale
        });
        updateMonitorConfig(mon.name, mode, position, scale);
    }

    function refreshRates(mon) {
        if (!mon || !mon.availableModes)
            return [];

        const prefix = mon.width + "x" + mon.height + "@";
        const seen = {
        };
        const rates = [];
        for (let i = 0; i < mon.availableModes.length; i++) {
            const mode = String(mon.availableModes[i]);
            if (mode.indexOf(prefix) !== 0)
                continue;

            const match = mode.match(/@([\d.]+)/);
            if (!match)
                continue;

            const rate = parseFloat(match[1]);
            if (isNaN(rate))
                continue;

            const key = rate.toFixed(2);
            if (seen[key])
                continue;

            seen[key] = true;
            rates.push(rate);
        }
        rates.sort((a, b) => {
            return b - a;
        });
        return rates;
    }

    function setRefreshRate(mon, rate) {
        if (!mon || !mon.name || rate === undefined)
            return ;

        const mode = mon.width + "x" + mon.height + "@" + Number(rate).toFixed(2);
        const scale = mon.scale !== undefined ? mon.scale : 1;
        const position = mon.x + "x" + mon.y;
        rememberMonitor(mon, {
            "mode": mode,
            "position": position,
            "scale": scale
        });
        updateMonitorConfig(mon.name, mode, position, scale);
    }

    Component.onCompleted: {
        stateDirProcess.running = true;
        loadState();
    }

    Process {
        id: stateDirProcess

        command: ["mkdir", "-p", page.stateDir]
    }

    FileView {
        id: displayFile

        path: page.stateDir + "/display.json"
        blockLoading: true
    }

    FileView {
        id: monitorConfigFile

        path: page.monitorConfigPath
        blockLoading: true
        onSaved: {
            page.monitorConfigWriteInProgress = false;
            if (page.monitorConfigWritePending) {
                monitorConfigWriteTimer.restart();
                return ;
            }
            page.pendingMonitorConfigText = "";
            configReloadTimer.restart();
        }
        onSaveFailed: (error) => {
            page.monitorConfigWriteInProgress = false;
            console.warn("Display: failed to save monitors.lua: " + error);
            if (page.monitorConfigWritePending)
                monitorConfigWriteTimer.restart();
            else
                page.pendingMonitorConfigText = "";
        }
    }

    Timer {
        id: stateSaveTimer

        interval: 300
        onTriggered: {
            try {
                displayFile.setText(JSON.stringify({
                    "monitors": page.savedState
                }, null, 2));
            } catch (error) {
            }
        }
    }

    Process {
        id: pReset

        onExited: (exitCode) => {
            refreshTimer.restart();
        }
    }

    Timer {
        id: monitorConfigWriteTimer

        interval: 60
        repeat: false
        onTriggered: {
            if (!page.monitorConfigWritePending || page.pendingMonitorConfigText === "")
                return ;

            if (page.monitorConfigWriteInProgress)
                return ;

            page.monitorConfigWritePending = false;
            page.monitorConfigWriteInProgress = true;
            monitorConfigFile.setText(page.pendingMonitorConfigText);
        }
    }

    Timer {
        id: configReloadTimer

        interval: 500
        repeat: false
        onTriggered: {
            pConfigReload.command = ["hyprctl", "reload"];
            pConfigReload.running = true;
        }
    }

    Process {
        id: pConfigReload

        onExited: (exitCode) => {
            return refreshTimer.restart();
        }
    }

    Process {
        id: pShell

        onExited: (exitCode) => {
            refreshTimer.restart();
        }
    }

    Process {
        id: pList

        command: ["hyprctl", "monitors", "all", "-j"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.monitors = JSON.parse(text);
                } catch (error) {
                    page.monitors = [];
                }
            }
        }

    }

    Timer {
        id: scaleApplyTimer

        interval: 180
        repeat: false
        onTriggered: {
            if (page.pendingScaleMonitor)
                page.setScale(page.pendingScaleMonitor, page.pendingScaleValue);

        }
    }

    Timer {
        id: refreshTimer

        interval: 250
        onTriggered: page.refresh()
    }

    Flickable {
        id: flick

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

            width: flick.width
            spacing: 14

            Text {
                text: "DISPLAY"
                color: Theme.text
                font.family: "Noto Sans"
                font.pixelSize: 19
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Rectangle {
                id: monitorGraph

                property real scaleFactor: page.graphScale(width, height)
                property real centerX: page.bboxCenter.x
                property real centerY: page.bboxCenter.y

                width: parent.width
                height: 260
                radius: Theme.radius
                color: Theme.alpha(Theme.text, 0.025)
                border.width: 1
                border.color: Theme.border
                clip: true

                Repeater {
                    model: 5

                    delegate: Rectangle {
                        required property int index

                        x: (index + 1) * monitorGraph.width / 6
                        y: 0
                        width: 1
                        height: monitorGraph.height
                        color: Theme.alpha(Theme.text, 0.035)
                        z: 0
                    }

                }

                Rectangle {
                    x: 0
                    y: monitorGraph.height / 2
                    width: monitorGraph.width
                    height: 1
                    color: Theme.alpha(Theme.text, 0.08)
                    z: 0
                }

                Rectangle {
                    x: monitorGraph.width / 2 - 3
                    y: monitorGraph.height / 2 - 3
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.accent
                    z: 1
                }

                Repeater {
                    model: page.activeMonitors

                    delegate: Rectangle {
                        id: monitorTile

                        required property var modelData
                        required property int index
                        readonly property real tileScale: monitorGraph.scaleFactor
                        readonly property real tileW: modelData.width / (modelData.scale > 0 ? modelData.scale : 1)
                        readonly property real tileH: modelData.height / (modelData.scale > 0 ? modelData.scale : 1)

                        x: monitorGraph.width / 2 + (Number(modelData.x || 0) - monitorGraph.centerX) * tileScale
                        y: monitorGraph.height / 2 + (Number(modelData.y || 0) - monitorGraph.centerY) * tileScale
                        width: Math.max(52, tileW * tileScale)
                        height: Math.max(38, tileH * tileScale)
                        radius: 7
                        color: Theme.alpha(index === 0 ? Theme.accent : Theme.text, 0.13)
                        border.width: 2
                        border.color: page.isMain(modelData) ? Theme.accent : Theme.alpha(Theme.text, 0.42)
                        z: dragMouse.pressed ? 5 : 2

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: monitorTile.modelData.name
                                color: Theme.text
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Rectangle {
                                width: 24
                                height: 2
                                radius: 1
                                color: Theme.alpha(Theme.text, 0.4)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: monitorTile.modelData.width + " × " + monitorTile.modelData.height
                                color: Theme.textDim
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                            }

                        }

                        MouseArea {
                            id: dragMouse

                            property real pressGraphX: 0
                            property real pressGraphY: 0
                            property real startWorldX: 0
                            property real startWorldY: 0
                            property bool moved: false

                            function applyGlue(mouseX, mouseY) {
                                const factor = monitorGraph.scaleFactor;
                                const p = dragMouse.mapToItem(monitorGraph, mouseX, mouseY);
                                const dxWorld = (p.x - pressGraphX) / factor;
                                const dyWorld = (p.y - pressGraphY) / factor;
                                const wantX = startWorldX + dxWorld;
                                const wantY = startWorldY + dyWorld;
                                const glued = page.gluePosition(monitorTile.modelData, wantX, wantY, monitorTile.tileW, monitorTile.tileH);
                                monitorTile.x = monitorGraph.width / 2 + (glued.x - monitorGraph.centerX) * factor;
                                monitorTile.y = monitorGraph.height / 2 + (glued.y - monitorGraph.centerY) * factor;
                                return glued;
                            }

                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: function(mouse) {
                                const p = dragMouse.mapToItem(monitorGraph, mouse.x, mouse.y);
                                pressGraphX = p.x;
                                pressGraphY = p.y;
                                startWorldX = Number(monitorTile.modelData.x || 0);
                                startWorldY = Number(monitorTile.modelData.y || 0);
                                moved = false;
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed)
                                    return ;

                                moved = true;
                                applyGlue(mouse.x, mouse.y);
                            }
                            onReleased: function(mouse) {
                                if (!moved)
                                    return ;

                                const glued = applyGlue(mouse.x, mouse.y);
                                page.setPosition(monitorTile.modelData, glued.x, glued.y);
                            }
                        }

                    }

                }

            }

            Column {
                width: parent.width
                spacing: 8

                Repeater {
                    model: page.monitors

                    delegate: Rectangle {
                        id: card

                        required property var modelData
                        property bool off: modelData.disabled === true
                        property bool main: page.isMain(modelData)
                        readonly property bool scaleAvailable: page.hasScaleOptions(modelData)

                        width: parent.width
                        height: cardColumn.implicitHeight + 20
                        radius: Theme.radius
                        color: "#00000000"
                        border.width: 1
                        border.color: modelData.focused && !off ? "#454545" : Theme.border

                        Column {
                            id: cardColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 6

                            Item {
                                width: parent.width
                                height: 24

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        text: card.modelData.name
                                        color: card.off ? Theme.textDim : Theme.text
                                        font.family: "Noto Sans"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Text {
                                        visible: !card.off
                                        text: card.modelData.width + "x" + card.modelData.height + " @ " + Math.round(card.modelData.refreshRate) + "Hz"
                                        color: Theme.textDim
                                        font.family: "Noto Sans"
                                        font.pixelSize: 12
                                    }

                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Rectangle {
                                        visible: !card.off && page.activeMonitors.length > 1
                                        width: 84
                                        height: 24
                                        radius: Theme.radius
                                        color: card.main ? Theme.alpha(Theme.accent, 0.1) : (mainMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                        border.width: 1
                                        border.color: card.main || mainMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.main ? "MAIN" : "SET MAIN"
                                            color: card.main ? Theme.accent : Theme.text
                                            font.family: "Noto Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: mainMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !card.main
                                            cursorShape: card.main ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: page.setMainMonitor(card.modelData)
                                        }

                                    }

                                    Rectangle {
                                        visible: card.off || page.activeMonitors.length > 1
                                        width: 72
                                        height: 24
                                        radius: Theme.radius
                                        color: toggleMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                                        border.width: 1
                                        border.color: toggleMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.off ? "ENABLE" : "DISABLE"
                                            color: Theme.text
                                            font.family: "Noto Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: toggleMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.setMonitorEnabled(card.modelData, card.off)
                                        }

                                    }

                                }

                            }

                            Row {
                                visible: !card.off
                                width: parent.width
                                spacing: 8

                                Text {
                                    width: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "SCALE"
                                    color: Theme.textDim
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                }

                                Controls.Slider {
                                    visible: card.scaleAvailable
                                    width: parent.width - 36 - 44 - 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 0
                                    to: 1
                                    value: Math.max(0, Math.min(1, ((card.modelData.scale || 1) - 0.7) / 0.6))
                                    onMoved: {
                                        const newScale = 0.7 + value * 0.6;
                                        page.pendingScaleMonitor = card.modelData;
                                        page.pendingScaleValue = newScale;
                                        scaleApplyTimer.restart();
                                    }
                                }

                                Text {
                                    visible: !card.scaleAvailable
                                    width: parent.width - 36 - 44 - 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Only 1.00x available on this resolution"
                                    color: Theme.textFaint
                                    font.family: "Noto Sans"
                                    font.pixelSize: 10
                                    font.italic: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: 44
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: (card.modelData.scale || 1).toFixed(2) + "x"
                                    color: Theme.text
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                }

                            }

                            Row {
                                visible: !card.off
                                width: parent.width
                                spacing: 8

                                Text {
                                    width: 36
                                    height: 28
                                    verticalAlignment: Text.AlignVCenter
                                    text: "RES"
                                    color: Theme.textDim
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                }

                                Flow {
                                    width: parent.width - 36 - 8
                                    spacing: 6

                                    Repeater {
                                        model: card.off ? [] : page.resolutionList(card.modelData)

                                        delegate: Rectangle {
                                            id: resButton

                                            required property string modelData
                                            property bool current: modelData === card.modelData.width + "x" + card.modelData.height

                                            width: 92
                                            height: 28
                                            radius: Theme.radius
                                            color: current ? Theme.alpha(Theme.accent, 0.1) : (resMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                            border.width: 1
                                            border.color: current || resMouse.containsMouse ? Theme.accent : Theme.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: resButton.modelData
                                                color: Theme.text
                                                font.family: "Noto Sans"
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: resMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const mode = page.bestMode(card.modelData, resButton.modelData);
                                                    if (mode)
                                                        page.setResolution(card.modelData, mode);

                                                }
                                            }

                                        }

                                    }

                                }

                            }

                            Row {
                                visible: !card.off
                                width: parent.width
                                spacing: 8

                                Text {
                                    width: 36
                                    height: 28
                                    verticalAlignment: Text.AlignVCenter
                                    text: "HZ"
                                    color: Theme.textDim
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                }

                                Flow {
                                    width: parent.width - 36 - 8
                                    spacing: 6

                                    Repeater {
                                        model: card.off ? [] : page.refreshRates(card.modelData)

                                        delegate: Rectangle {
                                            id: rateButton

                                            required property var modelData
                                            property bool current: Math.abs(modelData - card.modelData.refreshRate) < 0.05

                                            width: 76
                                            height: 28
                                            radius: Theme.radius
                                            color: current ? Theme.alpha(Theme.accent, 0.1) : (rateMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                            border.width: 1
                                            border.color: current || rateMouse.containsMouse ? Theme.accent : Theme.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: rateButton.modelData.toFixed(2)
                                                color: Theme.text
                                                font.family: "Noto Sans"
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: rateMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: page.setRefreshRate(card.modelData, rateButton.modelData)
                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 34
                radius: Theme.radius
                color: resetMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                border.width: 1
                border.color: resetMouse.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "RESET TO CONFIG"
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 1
                }

                MouseArea {
                    id: resetMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.resetToConfig()
                }

            }

        }

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            background: Rectangle {
                color: "transparent"
                radius: width / 2
            }

            contentItem: Rectangle {
                color: "transparent"
                radius: width / 2
            }

        }

    }

}
