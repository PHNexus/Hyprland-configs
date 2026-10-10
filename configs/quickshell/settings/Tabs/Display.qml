import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property var monitors: []
    property var savedState: ({})
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property real sliderMarginRight: 10
    property real labelWidth: 96
    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"
    readonly property string monitorConfigPath: Quickshell.env("HOME") + "/.config/hypr/monitors.lua"
    readonly property var activeMonitors: monitors.filter(m => !m.disabled)
    property var pendingScaleMonitor: null
    property real pendingScaleValue: 1

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
    }

    function loadState() {
        try {
            const saved = JSON.parse(displayFile.text())
            if (saved && typeof saved.monitors === "object" && saved.monitors !== null) {
                savedState = saved.monitors
            }
        } catch (error) {}
    }

    function luaFileText() {
        const lines = []
        const names = Object.keys(savedState)
        for (let i = 0; i < names.length; i++) {
            const entry = savedState[names[i]]
            if (!entry) continue
            if (entry.disabled === true) {
                lines.push(monitorLua({ name: names[i] }, { disabled: true }))
                continue
            }
            if (typeof entry.mode !== "string") continue
            lines.push(monitorLua({ name: names[i] }, {
                mode: entry.mode,
                position: typeof entry.position === "string" ? entry.position : "auto",
                scale: typeof entry.scale === "number" ? entry.scale : 1
            }))
        }
        return lines.join("\n") + "\n"
    }

    Timer {
        id: stateSaveTimer
        interval: 300
        onTriggered: {
            try {
                displayFile.setText(JSON.stringify({ monitors: page.savedState }, null, 2))
            } catch (error) {}
        }
    }

    function monitorPosition(mon) {
        return page.activeMonitors.length <= 1 ? "auto" : mon.x + "x" + mon.y
    }

    function rememberMonitor(mon, fields) {
        if (!mon || !mon.name) return
        const next = Object.assign({}, savedState)
        next[mon.name] = Object.assign({}, next[mon.name] || {}, fields)
        savedState = next
        stateSaveTimer.restart()
    }

    Process {
        id: pReset
        onExited: exitCode => {
            refreshTimer.restart()
        }
    }

    function resetToConfig() {
        stateSaveTimer.stop()
        savedState = ({})
        pReset.command = [
            "sh", "-c",
            "rm -f '" + page.stateDir + "/display.json' '" + page.stateDir + "/display.lua'; hyprctl reload"
        ]
        pReset.running = true
    }

    function monitorMode(mon) { return mon.width + "x" + mon.height + "@" + mon.refreshRate.toFixed(2) }

    function luaString(value) { return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") }

    function monitorLua(mon, options = {}) {
        const values = ["output = \"" + luaString(mon.name) + "\""]
        if (options.mode !== undefined) values.push("mode = \"" + luaString(options.mode) + "\"")
        if (options.position !== undefined) values.push("position = \"" + luaString(options.position) + "\"")
        if (options.scale !== undefined) values.push("scale = " + options.scale)
        if (options.disabled !== undefined) values.push("disabled = " + options.disabled)
        if (options.mirrorOf !== undefined) values.push("mirrorOf = \"" + luaString(options.mirrorOf) + "\"")
        return "hl.monitor({" + values.join(",") + "})"
    }


    // Persist display settings by editing only the matching hl.monitor(...) line.
    // Existing comments, indentation, workspaces and unrelated Lua stay untouched.
    // mode, position and scale are the only fields changed by this page.
    function updateMonitorConfig(output, mode, position, scale, disabled) {
        const source = monitorConfigFile.text()
        if (typeof source !== "string" || source.length === 0) {
            console.warn("Display: could not read " + page.monitorConfigPath)
            return false
        }

        const lines = source.split("\n")
        let found = false
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            if (line.indexOf("hl.monitor(") < 0) continue
            const outputMatch = line.match(/output\s*=\s*[\"']([^\"']+)[\"']/)
            if (!outputMatch || outputMatch[1] !== output) continue

            let updated = line
            const replaceStringField = (key, value) => {
                if (value === null || value === undefined) return
                const pattern = new RegExp('(' + key + '\\s*=\\s*[\"\'])[^\"\']*([\"\'])')
                if (pattern.test(updated)) {
                    updated = updated.replace(pattern, (_, before, after) => before + String(value) + after)
                } else {
                    updated = updated.replace(/\s*}\s*\)\s*$/, ', ' + key + ' = "' + String(value).replace(/\"/g, '\\"') + '})')
                }
            }
            replaceStringField("mode", mode)
            replaceStringField("position", position)
            if (scale !== null && scale !== undefined) {
                const scalePattern = /(scale\s*=\s*)[\d.]+/
                if (scalePattern.test(updated)) {
                    updated = updated.replace(scalePattern, (_, before) => before + Number(scale).toFixed(3).replace(/0+$/, "").replace(/\.$/, ""))
                } else {
                    updated = updated.replace(/\s*}\s*\)\s*$/, ', scale = ' + Number(scale).toFixed(3).replace(/0+$/, "").replace(/\.$/, "") + '})')
                }
            }
            if (disabled !== null && disabled !== undefined) {
                const disabledPattern = /(disabled\s*=\s*)(true|false)/
                if (disabled === true) {
                    if (disabledPattern.test(updated)) updated = updated.replace(disabledPattern, "$1true")
                    else updated = updated.replace(/\s*}\s*\)\s*$/, ', disabled = true})')
                } else if (disabledPattern.test(updated)) {
                    updated = updated.replace(/,\s*disabled\s*=\s*(?:true|false)/, "")
                }
            }
            lines[i] = updated
            found = true
            break
        }

        if (!found) {
            console.warn("Display: no existing hl.monitor entry found for " + output + "; monitors.lua was not changed")
            return false
        }

        const updatedSource = lines.join("\n")
        if (updatedSource !== source) {
            monitorConfigFile.setText(updatedSource)
            configReloadTimer.restart()
        }
        return true
    }

    Timer {
        id: configReloadTimer
        interval: 500
        repeat: false
        onTriggered: {
            pConfigReload.command = ["hyprctl", "reload"]
            pConfigReload.running = true
        }
    }

    Process {
        id: pConfigReload
        onExited: exitCode => refreshTimer.restart()
    }

    function setPosition(mon, x, y) {
        if (!mon || !mon.name) return
        const position = Math.round(Number(x)) + "x" + Math.round(Number(y))
        const mode = monitorMode(mon)
        const scale = mon.scale !== undefined ? mon.scale : 1
        rememberMonitor(mon, { mode: mode, position: position, scale: scale })
        updateMonitorConfig(mon.name, mode, position, scale)
    }

    function graphScale(graphWidth, graphHeight) {
        let maxX = 300, maxY = 180
        for (let i = 0; i < activeMonitors.length; i++) {
            const m = activeMonitors[i]
            const scale = m.scale > 0 ? m.scale : 1
            const x1 = Number(m.x || 0), y1 = Number(m.y || 0)
            const x2 = x1 + m.width / scale, y2 = y1 + m.height / scale
            maxX = Math.max(maxX, Math.abs(x1), Math.abs(x2))
            maxY = Math.max(maxY, Math.abs(y1), Math.abs(y2))
        }
        return Math.max(0.025, Math.min((graphWidth / 2 - 18) / maxX, (graphHeight / 2 - 18) / maxY, 0.22))
    }

    function isMain(mon) {
        return !mon.disabled && page.activeMonitors.length > 0 && mon.x === 0 && mon.y === 0
    }

    Process {
        id: pShell
        onExited: exitCode => {
            refreshTimer.restart()
        }
    }

    function layoutCommands(ordered) {
        const cmds = []
        let x = 0
        for (let i = 0; i < ordered.length; i++) {
            const m = ordered[i]
            const mode = monitorMode(m)
            const pos = x + "x0"
            rememberMonitor(m, { mode: mode, position: pos, disabled: false })
            updateMonitorConfig(m.name, mode, pos, m.scale !== undefined ? m.scale : 1)
            x += Math.round(m.width / m.scale)
        }
        if (ordered.length > 0) cmds.push("hyprctl dispatch focusmonitor '" + ordered[0].name + "'")
        return cmds
    }

    function setMainMonitor(main) {
        if (!main || !main.name || main.disabled) return
        const others = page.activeMonitors.filter(m => m.name !== main.name).sort((a, b) => a.x - b.x)
        const cmds = layoutCommands([main].concat(others))
        pShell.command = ["sh", "-c", cmds.join("; ")]
        pShell.running = true
    }

    function setMonitorEnabled(mon, enabled) {
        if (!mon || !mon.name) return
        let cmds = []
        if (enabled) {
            const entry = savedState[mon.name] || {}
            const mode = typeof entry.mode === "string" ? entry.mode : monitorMode(mon)
            const scale = typeof entry.scale === "number" ? entry.scale : (mon.scale !== undefined ? mon.scale : 1)
            const position = typeof entry.position === "string" ? entry.position : (mon.x + "x" + mon.y)
            rememberMonitor(mon, { mode: mode, scale: scale, position: position, disabled: false })
            updateMonitorConfig(mon.name, mode, position, scale, false)
            cmds.push("hyprctl reload")
        } else {
            if (page.activeMonitors.length <= 1) return
            const wasMain = isMain(mon)
            rememberMonitor(mon, { mode: monitorMode(mon), scale: mon.scale, disabled: true })
            updateMonitorConfig(mon.name, monitorMode(mon), mon.x + "x" + mon.y, mon.scale !== undefined ? mon.scale : 1, true)
            cmds.push("hyprctl keyword monitor '" + mon.name + ",disable'")
            if (wasMain) {
                const rest = page.activeMonitors.filter(m => m.name !== mon.name).sort((a, b) => a.x - b.x)
                cmds = cmds.concat(layoutCommands(rest))
            }
        }
        pShell.command = ["sh", "-c", cmds.join("; ")]
        pShell.running = true
    }

    Process {
        id: pList
        command: ["hyprctl", "monitors", "all", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.monitors = JSON.parse(text)
                } catch (error) {
                    page.monitors = []
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {}
        }
    }

    function refresh() {
        pList.running = true
    }

    Process {
        id: pApply
        property var pendingMon: null

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out.length === 0) return

                const match = out.match(/using suggested scale:\s*([\d.]+)/i)
                if (match && pApply.pendingMon) {
                    const suggested = parseFloat(match[1])
                    page.setScale(pApply.pendingMon, suggested, true)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {}
        }
        onExited: exitCode => {
            refreshTimer.restart()
        }
    }

    function gcd(a, b) { while (b) { [a, b] = [b, a % b] }; return a }

    function validScale(mon, requested) {
        const width = mon.width
        const height = mon.height
        let best = requested
        let bestDistance = Infinity

        for (let i = 84; i <= 1560; i++) {
            const scale = i / 120
            if (scale < 0.7 || scale > 1.3) continue

            const logicalWidth = width / scale
            const logicalHeight = height / scale

            if (Math.abs(logicalWidth - Math.round(logicalWidth)) < 0.0001 &&
                Math.abs(logicalHeight - Math.round(logicalHeight)) < 0.0001) {
                const distance = Math.abs(scale - requested)
                if (distance < bestDistance) {
                    best = scale
                    bestDistance = distance
                }
            }
        }

        return best
    }

    function setScale(mon, scale, isRetry = false) {
        if (!mon || !mon.name) return
        const requested = Number(scale)
        const applied = isRetry ? requested : validScale(mon, requested)
        const idx = page.monitors.findIndex(m => m.name === mon.name)
        if (idx !== -1) {
            const updated = page.monitors.slice()
            updated[idx] = Object.assign({}, updated[idx], { scale: applied })
            page.monitors = updated
        }
        const mode = monitorMode(mon)
        const position = mon.x + "x" + mon.y
        rememberMonitor(mon, { mode: mode, position: position, scale: applied })
        updateMonitorConfig(mon.name, mode, position, applied)
    }

    Process {
        id: pResolution
        stdout: StdioCollector {
            onStreamFinished: {}
        }
        stderr: StdioCollector {
            onStreamFinished: {}
        }
        onExited: exitCode => {
            refreshTimer.restart()
        }
    }

    function resolutionList(mon) {
        if (!mon || !mon.availableModes) return []
        const seen = {}
        const items = []
        for (let i = 0; i < mon.availableModes.length; i++) {
            const match = String(mon.availableModes[i]).match(/^(\d+)x(\d+)@/)
            if (!match) continue
            const key = match[1] + "x" + match[2]
            if (seen[key]) continue
            seen[key] = true
            items.push({ key: key, width: parseInt(match[1]), height: parseInt(match[2]) })
        }
        items.sort((a, b) => (b.width * b.height - a.width * a.height) || (b.width - a.width))
        return items.slice(0, 6).map(item => item.key)
    }

    function bestMode(mon, resolution) {
        if (!mon || !mon.availableModes) return null
        const prefix = resolution + "@"
        let bestRate = null
        let bestDistance = Infinity
        for (let i = 0; i < mon.availableModes.length; i++) {
            const mode = String(mon.availableModes[i])
            if (mode.indexOf(prefix) !== 0) continue
            const rate = parseFloat(mode.substring(prefix.length))
            if (isNaN(rate)) continue
            const distance = Math.abs(rate - mon.refreshRate)
            if (distance < bestDistance || (distance === bestDistance && rate > bestRate)) {
                bestRate = rate
                bestDistance = distance
            }
        }
        return bestRate === null ? null : prefix + bestRate.toFixed(2)
    }

    function setResolution(mon, mode) {
        if (!mon || !mon.name || !mode) return
        const scale = mon.scale !== undefined ? mon.scale : 1
        const position = mon.x + "x" + mon.y
        rememberMonitor(mon, { mode: mode, position: position, scale: scale })
        updateMonitorConfig(mon.name, mode, position, scale)
    }

    function refreshRates(mon) {
        if (!mon || !mon.availableModes) return []
        const prefix = mon.width + "x" + mon.height + "@"
        const seen = {}
        const rates = []
        for (let i = 0; i < mon.availableModes.length; i++) {
            const mode = String(mon.availableModes[i])
            if (mode.indexOf(prefix) !== 0) continue
            const match = mode.match(/@([\d.]+)/)
            if (!match) continue
            const rate = parseFloat(match[1])
            if (isNaN(rate)) continue
            const key = rate.toFixed(2)
            if (seen[key]) continue
            seen[key] = true
            rates.push(rate)
        }
        rates.sort((a, b) => b - a)
        return rates
    }

    function setRefreshRate(mon, rate) {
        if (!mon || !mon.name || rate === undefined) return
        const mode = mon.width + "x" + mon.height + "@" + Number(rate).toFixed(2)
        const scale = mon.scale !== undefined ? mon.scale : 1
        const position = mon.x + "x" + mon.y
        rememberMonitor(mon, { mode: mode, position: position, scale: scale })
        updateMonitorConfig(mon.name, mode, position, scale)
    }

    Timer {
        id: scaleApplyTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (page.pendingScaleMonitor)
                page.setScale(page.pendingScaleMonitor, page.pendingScaleValue)
        }
    }

    Timer { id: refreshTimer; interval: 250; onTriggered: page.refresh() }

    Process {
        id: pEditConfig
        command: ["sh", "-c", "xed ~/.config/hypr/monitors.lua"]
        onExited: exitCode => {}
    }

    function editConfig() {
        if (pEditConfig.running) {
            return
        }
        pEditConfig.running = true
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft; anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop; anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

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

        Column {
            id: content
            width: flick.width
            spacing: 14

            Text {
                text: "DISPLAY"; color: Theme.text
                font.family: "Noto Sans"; font.pixelSize: 19; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // Visual monitor arrangement. Drag a monitor tile to change its position.
            Rectangle {
                id: monitorGraph
                width: parent.width
                height: 260
                radius: Theme.radius
                color: Theme.alpha(Theme.text, 0.025)
                border.width: 1
                border.color: Theme.border
                clip: true
                property real scaleFactor: page.graphScale(width, height)

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
                Rectangle { x: 0; y: monitorGraph.height / 2; width: monitorGraph.width; height: 1; color: Theme.alpha(Theme.text, 0.08); z: 0 }
                Rectangle { x: monitorGraph.width / 2 - 3; y: monitorGraph.height / 2 - 3; width: 6; height: 6; radius: 3; color: Theme.accent; z: 1 }

                Repeater {
                    model: page.activeMonitors
                    delegate: Rectangle {
                        id: monitorTile
                        required property var modelData
                        required property int index
                        property real logicalScale: monitorGraph.scaleFactor
                        property real logicalWidth: modelData.width / (modelData.scale > 0 ? modelData.scale : 1)
                        property real logicalHeight: modelData.height / (modelData.scale > 0 ? modelData.scale : 1)
                        x: monitorGraph.width / 2 + Number(modelData.x || 0) * logicalScale
                        y: monitorGraph.height / 2 + Number(modelData.y || 0) * logicalScale
                        width: Math.max(52, logicalWidth * logicalScale)
                        height: Math.max(38, logicalHeight * logicalScale)
                        radius: 7
                        color: Theme.alpha(index === 0 ? Theme.accent : Theme.text, 0.13)
                        border.width: 2
                        border.color: page.isMain(modelData) ? Theme.accent : Theme.alpha(Theme.text, 0.42)
                        z: 2

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
                            Rectangle { width: 24; height: 2; radius: 1; color: Theme.alpha(Theme.text, 0.4); anchors.horizontalCenter: parent.horizontalCenter }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: monitorTile.modelData.width + " × " + monitorTile.modelData.height
                                color: Theme.textDim
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                            }
                        }

                        MouseArea {
                            id: tileDrag
                            anchors.fill: parent
                            drag.target: monitorTile
                            drag.axis: Drag.XAndYAxis
                            drag.minimumX: 0
                            drag.maximumX: monitorGraph.width - monitorTile.width
                            drag.minimumY: 0
                            drag.maximumY: monitorGraph.height - monitorTile.height
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onReleased: {
                                const factor = monitorGraph.scaleFactor
                                const newX = Math.round((monitorTile.x - monitorGraph.width / 2) / factor)
                                const newY = Math.round((monitorTile.y - monitorGraph.height / 2) / factor)
                                page.setPosition(monitorTile.modelData, newX, newY)
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width; spacing: 8

                Repeater {
                    model: page.monitors

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        property bool off: modelData.disabled === true
                        property bool main: page.isMain(modelData)
                        property real pendingScale: modelData.scale !== undefined ? modelData.scale : 1
                        property real pendingX: modelData.x !== undefined ? modelData.x : 0
                        property real pendingY: modelData.y !== undefined ? modelData.y : 0
                        width: parent.width
                        height: cardColumn.implicitHeight + 20
                        radius: Theme.radius
                        color: "#00000000"; border.width: 1
                        border.color: modelData.focused && !off ? "#454545" : Theme.border

                        Column {
                            id: cardColumn
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 6

                            Item {
                                width: parent.width; height: 24

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        text: card.modelData.name
                                        color: card.off ? Theme.textDim : Theme.text
                                        font.family: "Noto Sans"; font.pixelSize: 14; font.bold: true
                                    }

                                    Text {
                                        visible: !card.off
                                        text: card.modelData.width + "x" + card.modelData.height + " @ " + Math.round(card.modelData.refreshRate) + "Hz"
                                        color: Theme.textDim; font.family: "Noto Sans"; font.pixelSize: 12
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Rectangle {
                                        visible: !card.off && page.activeMonitors.length > 1
                                        width: 84; height: 24; radius: Theme.radius
                                        color: card.main ? Theme.alpha(Theme.accent, 0.10) : (mainMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                        border.width: 1
                                        border.color: card.main || mainMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.main ? "MAIN" : "SET MAIN"
                                            color: card.main ? Theme.accent : Theme.text
                                            font.family: "Noto Sans"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: mainMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            enabled: !card.main
                                            cursorShape: card.main ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: page.setMainMonitor(card.modelData)
                                        }
                                    }

                                    Rectangle {
                                        visible: card.off || page.activeMonitors.length > 1
                                        width: 72; height: 24; radius: Theme.radius
                                        color: toggleMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                                        border.width: 1
                                        border.color: toggleMouse.containsMouse ? Theme.accent : Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.off ? "ENABLE" : "DISABLE"
                                            color: Theme.text
                                            font.family: "Noto Sans"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: toggleMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.setMonitorEnabled(card.modelData, card.off)
                                        }
                                    }
                                }
                            }

                            Row {
                                visible: !card.off
                                width: parent.width; spacing: 8

                                Text {
                                    id: scaleLabel
                                    width: 36; anchors.verticalCenter: parent.verticalCenter
                                    text: "SCALE"; color: Theme.textDim
                                    font.family: "Noto Sans"; font.pixelSize: 11
                                }

                                Controls.Slider {
                                    width: parent.width - 36 - 44 - 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 0; to: 1
                                    value: Math.max(0, Math.min(1, (card.pendingScale - 0.7) / 0.6))
                                    onMoved: {
                                        card.pendingScale = 0.7 + value * 0.6
                                        page.pendingScaleMonitor = card.modelData
                                        page.pendingScaleValue = card.pendingScale
                                        scaleApplyTimer.restart()
                                    }
                                }

                                Text {
                                    width: 44; anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: card.pendingScale.toFixed(2) + "x"
                                    color: Theme.text
                                    font.family: "Noto Sans"; font.pixelSize: 11
                                }
                            }


                            Row {
                                visible: !card.off
                                width: parent.width; spacing: 8

                                Text {
                                    width: 36; height: 28
                                    verticalAlignment: Text.AlignVCenter
                                    text: "RES"; color: Theme.textDim
                                    font.family: "Noto Sans"; font.pixelSize: 11
                                }

                                Flow {
                                    width: parent.width - 36 - 8; spacing: 6

                                    Repeater {
                                        model: card.off ? [] : page.resolutionList(card.modelData)

                                        delegate: Rectangle {
                                            id: resButton
                                            required property string modelData
                                            property bool current: modelData === card.modelData.width + "x" + card.modelData.height
                                            width: 92; height: 28; radius: Theme.radius
                                            color: current ? Theme.alpha(Theme.accent, 0.10) : (resMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                            border.width: 1
                                            border.color: current || resMouse.containsMouse ? Theme.accent : Theme.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: resButton.modelData
                                                color: Theme.text
                                                font.family: "Noto Sans"; font.pixelSize: 11; font.bold: true
                                            }

                                            MouseArea {
                                                id: resMouse
                                                anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const mode = page.bestMode(card.modelData, resButton.modelData)
                                                    if (mode) page.setResolution(card.modelData, mode)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                visible: !card.off
                                width: parent.width; spacing: 8

                                Text {
                                    width: 36; height: 28
                                    verticalAlignment: Text.AlignVCenter
                                    text: "HZ"; color: Theme.textDim
                                    font.family: "Noto Sans"; font.pixelSize: 11
                                }

                                Flow {
                                    width: parent.width - 36 - 8; spacing: 6

                                    Repeater {
                                        model: card.off ? [] : page.refreshRates(card.modelData)

                                        delegate: Rectangle {
                                            id: rateButton
                                            required property var modelData
                                            property bool current: Math.abs(modelData - card.modelData.refreshRate) < 0.05
                                            width: 76; height: 28; radius: Theme.radius
                                            color: current ? Theme.alpha(Theme.accent, 0.10) : (rateMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
                                            border.width: 1
                                            border.color: current || rateMouse.containsMouse ? Theme.accent : Theme.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: rateButton.modelData.toFixed(2)
                                                color: Theme.text
                                                font.family: "Noto Sans"; font.pixelSize: 11; font.bold: true
                                            }

                                            MouseArea {
                                                id: rateMouse
                                                anchors.fill: parent; hoverEnabled: true
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
                width: parent.width; height: 34; radius: Theme.radius
                color: resetMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                border.width: 1
                border.color: resetMouse.containsMouse ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent; text: "RESET TO CONFIG"; color: Theme.text
                    font.family: "Noto Sans"; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.resetToConfig()
                }
            }
        }
    }

    Component.onCompleted: {
        stateDirProcess.running = true
        loadState()
    }
}
