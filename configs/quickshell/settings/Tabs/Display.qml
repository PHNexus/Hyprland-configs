import "../"
import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Effects
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
    property bool layoutDragging: false
    readonly property real edgeTolerance: 2
    readonly property real preferredEdgeOverlap: 24
    readonly property var bboxCenter: {
        if (activeMonitors.length === 0)
            return {
            "x": 0,
            "y": 0
        };

        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        for (let i = 0; i < activeMonitors.length; i++) {
            const r = monitorRect(activeMonitors[i]);
            minX = Math.min(minX, r.x);
            minY = Math.min(minY, r.y);
            maxX = Math.max(maxX, r.x + r.w);
            maxY = Math.max(maxY, r.y + r.h);
        }
        return {
            "x": (minX + maxX) / 2,
            "y": (minY + maxY) / 2
        };
    }

    function monitorRect(mon) {
        if (!mon)
            return {
            "x": 0,
            "y": 0,
            "w": 0,
            "h": 0
        };

        const scale = Number(mon.scale) > 0 ? Number(mon.scale) : 1;
        return {
            "x": Number(mon.x || 0),
            "y": Number(mon.y || 0),
            "w": Number(mon.width || 0) / scale,
            "h": Number(mon.height || 0) / scale
        };
    }

    function clamp(value, minimum, maximum) {
        if (minimum > maximum)
            return (minimum + maximum) / 2;

        return Math.max(minimum, Math.min(maximum, value));
    }

    function overlapLength(aStart, aSize, bStart, bSize) {
        return Math.min(aStart + aSize, bStart + bSize) - Math.max(aStart, bStart);
    }

    function requiredEdgeOverlap(w, h, otherW, otherH) {
        return Math.min(preferredEdgeOverlap, Math.max(1, Math.min(w, h, otherW, otherH) * 0.05));
    }

    function dockCandidate(mon, otherRect, side, wantedX, wantedY) {
        const r = monitorRect(mon);
        const overlap = requiredEdgeOverlap(r.w, r.h, otherRect.w, otherRect.h);
        let x = wantedX;
        let y = wantedY;
        if (side === "right") {
            x = otherRect.x + otherRect.w;
            y = clamp(wantedY, otherRect.y - r.h + overlap, otherRect.y + otherRect.h - overlap);
        } else if (side === "left") {
            x = otherRect.x - r.w;
            y = clamp(wantedY, otherRect.y - r.h + overlap, otherRect.y + otherRect.h - overlap);
        } else if (side === "below") {
            y = otherRect.y + otherRect.h;
            x = clamp(wantedX, otherRect.x - r.w + overlap, otherRect.x + otherRect.w - overlap);
        } else if (side === "above") {
            y = otherRect.y - r.h;
            x = clamp(wantedX, otherRect.x - r.w + overlap, otherRect.x + otherRect.w - overlap);
        }
        return {
            "x": Math.round(x),
            "y": Math.round(y),
            "side": side
        };
    }

    function rectanglesOverlap(a, b) {
        return Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x) > 1 && Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y) > 1;
    }

    function connectedLayoutPositions() {
        const items = activeMonitors.filter((m) => {
            return Number(m.width) > 0 && Number(m.height) > 0;
        });
        const result = ({
        });
        if (items.length === 0)
            return result;

        let anchorIndex = items.findIndex((m) => {
            return Math.abs(Number(m.x || 0)) <= 1 && Math.abs(Number(m.y || 0)) <= 1;
        });
        if (anchorIndex < 0)
            anchorIndex = 0;

        const anchor = items[anchorIndex];
        const anchorRect = monitorRect(anchor);
        const placed = [{
            "mon": anchor,
            "x": anchorRect.x,
            "y": anchorRect.y,
            "w": anchorRect.w,
            "h": anchorRect.h
        }];
        const remaining = items.filter((m) => {
            return m.name !== anchor.name;
        });
        result[anchor.name] = {
            "x": anchorRect.x,
            "y": anchorRect.y
        };
        while (remaining.length > 0) {
            let best = null;
            for (let i = 0; i < remaining.length; i++) {
                const mon = remaining[i];
                const current = monitorRect(mon);
                for (let j = 0; j < placed.length; j++) {
                    const parent = placed[j];
                    const parentRect = {
                        "x": parent.x,
                        "y": parent.y,
                        "w": parent.w,
                        "h": parent.h
                    };
                    const sides = ["right", "left", "below", "above"];
                    for (let k = 0; k < sides.length; k++) {
                        const candidate = dockCandidate(mon, parentRect, sides[k], current.x, current.y);
                        const rect = {
                            "x": candidate.x,
                            "y": candidate.y,
                            "w": current.w,
                            "h": current.h
                        };
                        let collides = false;
                        for (let n = 0; n < placed.length; n++) {
                            if (placed[n].mon.name !== parent.mon.name && rectanglesOverlap(rect, placed[n])) {
                                collides = true;
                                break;
                            }
                        }
                        if (collides)
                            continue;

                        const distance = Math.abs(candidate.x - current.x) + Math.abs(candidate.y - current.y);
                        if (!best || distance < best.distance)
                            best = {
                            "mon": mon,
                            "candidate": candidate,
                            "rect": rect,
                            "distance": distance,
                            "index": i
                        };

                    }
                }
            }
            if (!best) {
                const mon = remaining[0];
                const current = monitorRect(mon);
                const parent = placed[placed.length - 1];
                best = {
                    "mon": mon,
                    "candidate": dockCandidate(mon, parent, "right", current.x, current.y),
                    "index": 0
                };
                best.rect = {
                    "x": best.candidate.x,
                    "y": best.candidate.y,
                    "w": current.w,
                    "h": current.h
                };
            }
            result[best.mon.name] = {
                "x": best.candidate.x,
                "y": best.candidate.y
            };
            placed.push({
                "mon": best.mon,
                "x": best.candidate.x,
                "y": best.candidate.y,
                "w": best.rect.w,
                "h": best.rect.h
            });
            remaining.splice(best.index, 1);
        }
        return result;
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
        pReset.command = ["sh", "-c", "rm -f '" + page.stateDir + "/display.json' '" + page.stateDir + "/display.lua'; hyprctl reload"];
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

        const px = Math.round(Number(x));
        const py = Math.round(Number(y));
        const position = px + "x" + py;
        const mode = monitorMode(mon);
        const scale = mon.scale !== undefined ? mon.scale : 1;
        const index = page.monitors.findIndex((m) => {
            return m.name === mon.name;
        });
        if (index !== -1) {
            const updated = page.monitors.slice();
            updated[index] = Object.assign({
            }, updated[index], {
                "x": px,
                "y": py
            });
            page.monitors = updated;
        }
        rememberMonitor(mon, {
            "mode": mode,
            "position": position,
            "scale": scale
        });
        updateMonitorConfig(mon.name, mode, position, scale);
    }

    function dockingConstraints(mon) {
        const constraints = [];
        for (let i = 0; i < activeMonitors.length; i++) {
            const other = activeMonitors[i];
            if (other.name === mon.name)
                continue;

            const rect = monitorRect(other);
            constraints.push({
                "name": other.name,
                "x": rect.x,
                "y": rect.y,
                "w": rect.w,
                "h": rect.h
            });
        }
        return constraints;
    }

    function constrainConnectedPosition(mon, x, y, constraints) {
        const r = monitorRect(mon);
        if (constraints.length === 0)
            return {
            "x": Math.round(x),
            "y": Math.round(y)
        };

        const sides = ["right", "left", "below", "above"];
        let bestValid = null;
        let bestFallback = null;
        for (let i = 0; i < constraints.length; i++) {
            const parent = constraints[i];
            for (let j = 0; j < sides.length; j++) {
                const candidate = dockCandidate(mon, parent, sides[j], x, y);
                const rect = {
                    "x": candidate.x,
                    "y": candidate.y,
                    "w": r.w,
                    "h": r.h
                };
                let collisionArea = 0;
                for (let k = 0; k < constraints.length; k++) {
                    const other = constraints[k];
                    if (other.name === parent.name)
                        continue;

                    const overlapX = Math.max(0, Math.min(rect.x + rect.w, other.x + other.w) - Math.max(rect.x, other.x));
                    const overlapY = Math.max(0, Math.min(rect.y + rect.h, other.y + other.h) - Math.max(rect.y, other.y));
                    collisionArea += overlapX * overlapY;
                }
                const dx = candidate.x - x;
                const dy = candidate.y - y;
                const distance = dx * dx + dy * dy;
                const fallbackScore = distance + collisionArea * 1000;
                if (!bestFallback || fallbackScore < bestFallback.score)
                    bestFallback = {
                    "candidate": candidate,
                    "score": fallbackScore
                };

                if (collisionArea <= 1 && (!bestValid || distance < bestValid.score))
                    bestValid = {
                    "candidate": candidate,
                    "score": distance
                };

            }
        }
        const best = bestValid || bestFallback;
        return best ? {
            "x": best.candidate.x,
            "y": best.candidate.y
        } : {
            "x": Math.round(x),
            "y": Math.round(y)
        };
    }

    function normalizeMonitorPositions() {
        if (layoutDragging || monitorConfigWritePending || monitorConfigWriteInProgress)
            return ;

        const positions = connectedLayoutPositions();
        const active = activeMonitors.slice();
        for (let i = 0; i < active.length; i++) {
            const mon = active[i];
            const target = positions[mon.name];
            if (!target)
                continue;

            if (Math.abs(Number(mon.x || 0) - target.x) > 1 || Math.abs(Number(mon.y || 0) - target.y) > 1)
                setPosition(mon, target.x, target.y);

        }
    }

    function graphScale(graphWidth, graphHeight) {
        if (activeMonitors.length === 0)
            return 0.15;

        const center = bboxCenter;
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        for (let i = 0; i < activeMonitors.length; i++) {
            const r = monitorRect(activeMonitors[i]);
            minX = Math.min(minX, r.x);
            minY = Math.min(minY, r.y);
            maxX = Math.max(maxX, r.x + r.w);
            maxY = Math.max(maxY, r.y + r.h);
        }
        const margin = 24;
        const halfW = Math.max(1, Math.abs(minX - center.x), Math.abs(maxX - center.x));
        const halfH = Math.max(1, Math.abs(minY - center.y), Math.abs(maxY - center.y));
        return Math.max(0.025, Math.min((graphWidth / 2 - margin) / halfW, (graphHeight / 2 - margin) / halfH, 0.25));
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
        id: displayLua

        path: page.stateDir + "/display.lua"
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
                    layoutNormalizeTimer.restart();
                } catch (error) {
                    page.monitors = [];
                    console.warn("Display: failed to parse monitor data: " + error);
                }
            }
        }

    }

    Timer {
        id: layoutNormalizeTimer

        interval: 350
        repeat: false
        onTriggered: page.normalizeMonitorPositions()
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

            Row {
                width: parent.width
                height: 46
                spacing: 12

                Rectangle {
                    width: 40
                    height: 40
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.alpha(Theme.text, 0.025)
                    border.width: 1
                    border.color: "#414141"
                    layer.enabled: true

                    Text {
                        anchors.centerIn: parent
                        text: "\uf108"
                        color: Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: 19
                    }

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#8f95a1"
                        shadowOpacity: 0.28
                        shadowBlur: 0.38
                        shadowVerticalOffset: 2
                    }

                }

                Column {
                    width: Math.max(90, parent.width - 40 - 64 - parent.spacing * 2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: "Displays"
                        color: Theme.text
                        font.family: Theme.displayFont
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: "Arrange monitors and tune display settings"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                }

                Rectangle {
                    width: 64
                    height: 28
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.alpha(Theme.text, 0.025)
                    border.width: 1
                    border.color: "#414141"
                    layer.enabled: true

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "\uf108"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: String(page.activeMonitors.length)
                            color: Theme.text
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#8f95a1"
                        shadowOpacity: 0.28
                        shadowBlur: 0.38
                        shadowVerticalOffset: 2
                    }

                }

            }

            Row {
                width: parent.width
                height: 26
                spacing: 8

                Text {
                    width: 104
                    text: "WORKSPACE MAP"
                    color: Theme.text
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }

                Text {
                    width: Math.max(60, parent.width - 104 - 15 - parent.spacing * 2)
                    text: "Drag displays to rearrange"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }

                Text {
                    width: 15
                    text: "\uf2f1"
                    color: Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.refresh()
                    }

                }

            }

            Rectangle {
                id: monitorGraph

                property real scaleFactor: page.graphScale(width, height)
                property real centerX: page.bboxCenter.x
                property real centerY: page.bboxCenter.y

                width: parent.width
                height: 270
                radius: 12
                color: Theme.alpha(Theme.text, 0.012)
                border.width: 0
                border.color: "transparent"
                clip: true

                Repeater {
                    model: 5

                    delegate: Rectangle {
                        required property int index

                        x: (index + 1) * monitorGraph.width / 6
                        y: 0
                        width: 1
                        height: monitorGraph.height
                        color: Theme.alpha(Theme.text, 0.012)
                        z: 0
                    }

                }

                Rectangle {
                    x: 0
                    y: monitorGraph.height / 2
                    width: monitorGraph.width
                    height: 1
                    color: Theme.alpha(Theme.text, 0.025)
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
                        required property var modelData
                        readonly property real tileScale: monitorGraph.scaleFactor
                        readonly property real tileW: modelData.width / (modelData.scale > 0 ? modelData.scale : 1)
                        readonly property real tileH: modelData.height / (modelData.scale > 0 ? modelData.scale : 1)
                        readonly property var displayPosition: page.monitorRect(modelData)

                        x: monitorGraph.width / 2 + (displayPosition.x - monitorGraph.centerX) * tileScale + 2
                        y: monitorGraph.height / 2 + (displayPosition.y - monitorGraph.centerY) * tileScale + 3
                        width: Math.max(52, tileW * tileScale)
                        height: Math.max(38, tileH * tileScale)
                        radius: 8
                        color: "transparent"
                        border.width: 1
                        border.color: "#393939"
                        z: 0.5
                    }

                }

                Text {
                    x: 13
                    y: 11
                    text: "LAYOUT"
                    color: Theme.alpha(Theme.text, 0.34)
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 0.7
                    z: 4
                }

                Text {
                    x: 13
                    y: monitorGraph.height - 22
                    text: page.layoutDragging ? "MOVING DISPLAY" : "DRAG TO REPOSITION"
                    color: Theme.alpha(Theme.text, 0.42)
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.letterSpacing: 0.4
                    z: 4
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
                        readonly property var displayPosition: page.monitorRect(modelData)

                        x: monitorGraph.width / 2 + (displayPosition.x - monitorGraph.centerX) * tileScale
                        y: monitorGraph.height / 2 + (displayPosition.y - monitorGraph.centerY) * tileScale
                        width: Math.max(52, tileW * tileScale)
                        height: Math.max(38, tileH * tileScale)
                        radius: 8
                        color: Theme.alpha(index === 0 ? Theme.accent : Theme.text, 0.13)
                        border.width: 1
                        border.color: page.isMain(monitorTile.modelData) ? "#555555" : "#393939"
                        layer.enabled: true
                        z: dragMouse.pressed ? 5 : 2

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: monitorTile.modelData.name
                                color: Theme.text
                                font.family: "Noto Sans"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                width: 24
                                height: 2
                                radius: 1
                                color: page.isMain(monitorTile.modelData) ? Theme.accent : Theme.textDim
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
                            property var dragConstraints: []

                            function applyConnectedDrag(mouseX, mouseY) {
                                const factor = monitorGraph.scaleFactor;
                                const p = dragMouse.mapToItem(monitorGraph, mouseX, mouseY);
                                const dxWorld = (p.x - pressGraphX) / factor;
                                const dyWorld = (p.y - pressGraphY) / factor;
                                const wantedX = startWorldX + dxWorld;
                                const wantedY = startWorldY + dyWorld;
                                const next = page.constrainConnectedPosition(monitorTile.modelData, wantedX, wantedY, dragConstraints);
                                monitorTile.x = monitorGraph.width / 2 + (next.x - monitorGraph.centerX) * factor;
                                monitorTile.y = monitorGraph.height / 2 + (next.y - monitorGraph.centerY) * factor;
                                return next;
                            }

                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: function(mouse) {
                                page.layoutDragging = true;
                                const p = dragMouse.mapToItem(monitorGraph, mouse.x, mouse.y);
                                pressGraphX = p.x;
                                pressGraphY = p.y;
                                startWorldX = monitorTile.displayPosition.x;
                                startWorldY = monitorTile.displayPosition.y;
                                dragConstraints = page.dockingConstraints(monitorTile.modelData);
                                moved = false;
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed)
                                    return ;

                                moved = true;
                                applyConnectedDrag(mouse.x, mouse.y);
                            }
                            onReleased: function(mouse) {
                                if (moved) {
                                    const next = applyConnectedDrag(mouse.x, mouse.y);
                                    page.setPosition(monitorTile.modelData, next.x, next.y);
                                }
                                page.layoutDragging = false;
                                dragConstraints = [];
                            }
                            onCanceled: {
                                page.layoutDragging = false;
                                dragConstraints = [];
                            }
                        }

                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#8f95a1"
                            shadowOpacity: 0.28
                            shadowBlur: 0.38
                            shadowVerticalOffset: 2
                        }

                    }

                }

            }

            Column {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    height: 25
                    spacing: 8

                    Text {
                        text: "CONNECTED DISPLAYS"
                        color: Theme.text
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: String(page.monitors.length)
                        color: Theme.textFaint
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                Repeater {
                    model: page.monitors

                    delegate: Rectangle {
                        id: card

                        required property var modelData
                        property bool off: modelData.disabled === true
                        property bool main: page.isMain(modelData)
                        readonly property bool scaleAvailable: page.hasScaleOptions(modelData)

                        width: parent.width
                        height: cardColumn.implicitHeight + 22
                        radius: 11
                        color: card.off ? Theme.alpha(Theme.text, 0.008) : (cardHover.hovered ? Theme.alpha(Theme.text, 0.03) : Theme.alpha(Theme.text, 0.014))
                        border.width: 1
                        border.color: cardHover.hovered ? "#555555" : "#393939"
                        layer.enabled: true

                        HoverHandler {
                            id: cardHover
                        }

                        Rectangle {
                            x: 0
                            y: 10
                            width: 3
                            height: Math.max(0, parent.height - 20)
                            radius: 1.5
                            color: card.off ? Theme.alpha(Theme.text, 0.1) : (card.main ? Theme.accent : Theme.alpha("#aeb4bf", 0.28))
                        }

                        Column {
                            id: cardColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 6

                            Item {
                                width: parent.width
                                height: 32

                                Rectangle {
                                    x: 0
                                    width: 30
                                    height: 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 8
                                    color: Theme.alpha(Theme.text, 0.025)
                                    border.width: 1
                                    border.color: "#414141"
                                    layer.enabled: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf108"
                                        color: card.off ? Theme.textFaint : Theme.accent
                                        font.family: Theme.iconFont
                                        font.pixelSize: 15
                                    }

                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: "#8f95a1"
                                        shadowOpacity: 0.28
                                        shadowBlur: 0.38
                                        shadowVerticalOffset: 2
                                    }

                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 38
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        text: card.modelData.name
                                        color: card.off ? Theme.textDim : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
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
                                        radius: 7
                                        color: card.main ? Theme.alpha(Theme.accent, 0.07) : (mainMouse.containsMouse ? Theme.alpha(Theme.accent, 0.05) : Theme.alpha(Theme.text, 0.015))
                                        border.width: 1
                                        border.color: card.main ? "#555555" : (mainMouse.containsMouse ? "#555555" : "#393939")
                                        layer.enabled: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.main ? "MAIN" : "SET MAIN"
                                            color: card.main ? Theme.accent : Theme.text
                                            font.family: "Noto Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: mainMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !card.main
                                            cursorShape: card.main ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: page.setMainMonitor(card.modelData)
                                        }

                                        layer.effect: MultiEffect {
                                            shadowEnabled: true
                                            shadowColor: "#8f95a1"
                                            shadowOpacity: 0.28
                                            shadowBlur: 0.38
                                            shadowVerticalOffset: 2
                                        }

                                    }

                                    Rectangle {
                                        visible: card.off || page.activeMonitors.length > 1
                                        width: 72
                                        height: 24
                                        radius: 7
                                        color: toggleMouse.containsMouse ? Theme.alpha(Theme.accent, 0.05) : Theme.alpha(Theme.text, 0.015)
                                        border.width: 1
                                        border.color: toggleMouse.containsMouse ? "#555555" : "#393939"
                                        layer.enabled: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.off ? "ENABLE" : "DISABLE"
                                            color: Theme.text
                                            font.family: "Noto Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: toggleMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.setMonitorEnabled(card.modelData, card.off)
                                        }

                                        layer.effect: MultiEffect {
                                            shadowEnabled: true
                                            shadowColor: "#8f95a1"
                                            shadowOpacity: 0.28
                                            shadowBlur: 0.38
                                            shadowVerticalOffset: 2
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
                                    id: scaleSlider

                                    visible: card.scaleAvailable
                                    width: parent.width - 36 - 44 - 16
                                    height: 22
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

                                    background: Rectangle {
                                        x: scaleSlider.leftPadding
                                        y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                                        width: scaleSlider.availableWidth
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.text, 0.14)

                                        Rectangle {
                                            width: scaleSlider.visualPosition * parent.width
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.accent
                                        }

                                    }

                                    handle: Rectangle {
                                        x: scaleSlider.leftPadding + scaleSlider.visualPosition * (scaleSlider.availableWidth - width)
                                        y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: Theme.text
                                        border.width: 2
                                        border.color: Theme.accent
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
                                    text: (card.modelData.scale || 1).toFixed(2) + "×"
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
                                            radius: 7
                                            color: current ? Theme.alpha(Theme.accent, 0.07) : (resMouse.containsMouse ? Theme.alpha(Theme.accent, 0.05) : Theme.alpha(Theme.text, 0.015))
                                            border.width: 1
                                            border.color: current ? "#555555" : (resMouse.containsMouse ? "#555555" : "#393939")
                                            layer.enabled: true

                                            Text {
                                                anchors.centerIn: parent
                                                text: resButton.modelData
                                                color: resButton.current ? Theme.accent : Theme.text
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

                                            layer.effect: MultiEffect {
                                                shadowEnabled: true
                                                shadowColor: "#8f95a1"
                                                shadowOpacity: 0.28
                                                shadowBlur: 0.38
                                                shadowVerticalOffset: 2
                                            }

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 110
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
                                            radius: 7
                                            color: current ? Theme.alpha(Theme.accent, 0.07) : (rateMouse.containsMouse ? Theme.alpha(Theme.accent, 0.05) : Theme.alpha(Theme.text, 0.015))
                                            border.width: 1
                                            border.color: current ? "#555555" : (rateMouse.containsMouse ? "#555555" : "#393939")
                                            layer.enabled: true

                                            Text {
                                                anchors.centerIn: parent
                                                text: rateButton.modelData.toFixed(2)
                                                color: rateButton.current ? Theme.accent : Theme.text
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

                                            layer.effect: MultiEffect {
                                                shadowEnabled: true
                                                shadowColor: "#8f95a1"
                                                shadowOpacity: 0.28
                                                shadowBlur: 0.38
                                                shadowVerticalOffset: 2
                                            }

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 110
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                        }

                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#8f95a1"
                            shadowOpacity: 0.28
                            shadowBlur: 0.38
                            shadowVerticalOffset: 2
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 130
                            }

                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 130
                            }

                        }

                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 34
                radius: 8
                color: resetMouse.containsMouse ? Theme.alpha(Theme.text, 0.035) : Theme.alpha(Theme.text, 0.015)
                border.width: 1
                border.color: resetMouse.containsMouse ? "#555555" : "#393939"
                layer.enabled: true

                Text {
                    anchors.centerIn: parent
                    text: "RESET TO CONFIG"
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    id: resetMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.resetToConfig()
                }

                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#8f95a1"
                    shadowOpacity: 0.28
                    shadowBlur: 0.38
                    shadowVerticalOffset: 2
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
