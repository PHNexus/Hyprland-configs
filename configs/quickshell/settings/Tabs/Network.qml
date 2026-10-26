import "../"
import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: page

    property bool wifiEnabled: true
    property var networks: []
    property string pendingSsid: ""
    property var ethernet: ({
        "device": "",
        "state": "disconnected",
        "connection": ""
    })
    property string monoFont: Theme.monoFont
    property real downSpeed: 0
    property real upSpeed: 0
    property real lastRx: -1
    property real lastTx: -1
    property real lastTs: 0
    property real peakSpeed: 1
    property var downHistory: []
    property var upHistory: []
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    readonly property string icDown: "\uf019"
    readonly property string icUp: "\uf093"
    readonly property string icWifi: "\uf1eb"
    readonly property string icLock: "\uf023"
    readonly property string icEth: "\uf6ff"

    function formatSpeed(bps) {
        if (bps < 1024)
            return bps.toFixed(0) + " B/s";

        if (bps < 1024 * 1024)
            return (bps / 1024).toFixed(1) + " KB/s";

        if (bps < 1024 * 1024 * 1024)
            return (bps / 1024 / 1024).toFixed(2) + " MB/s";

        return (bps / 1024 / 1024 / 1024).toFixed(2) + " GB/s";
    }

    function setWifiEnabled(on) {
        page.wifiEnabled = on;
        pRadioSet.command = ["nmcli", "networking", on ? "on" : "off"];
        pRadioSet.running = true;
    }

    function connectOpen(ssid) {
        pConnect.command = ["nmcli", "device", "wifi", "connect", ssid];
        pConnect.running = true;
    }

    function connectSecured(ssid, password) {
        pConnect.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
        pConnect.running = true;
    }

    function disconnect(ssid) {
        pConnect.command = ["nmcli", "device", "disconnect", ssid];
        pConnect.running = true;
    }

    Component.onCompleted: {
        pRadioGet.running = true;
        pList.running = true;
        pEthernet.running = true;
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            pRadioGet.running = true;
        }
    }

    Timer {
        interval: 1500
        running: page.wifiEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (page.wifiEnabled && !pList.running)
                pList.running = true;

        }
    }

    Process {
        id: pNet

        command: ["cat", "/proc/net/dev"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var rx = 0;
                var tx = 0;
                for (var i = 2; i < lines.length; ++i) {
                    var line = lines[i].trim();
                    if (!line)
                        continue;

                    var idx = line.indexOf(":");
                    if (idx < 0)
                        continue;

                    var name = line.slice(0, idx).trim();
                    if (name === "lo" || name.indexOf("veth") === 0 || name.indexOf("docker") === 0 || name.indexOf("br-") === 0 || name.indexOf("virbr") === 0)
                        continue;

                    var parts = line.slice(idx + 1).trim().split(/\s+/);
                    rx += parseFloat(parts[0]) || 0;
                    tx += parseFloat(parts[8]) || 0;
                }
                var now = Date.now();
                if (page.lastTs > 0) {
                    var dt = (now - page.lastTs) / 1000;
                    if (dt > 0) {
                        page.downSpeed = Math.max(0, (rx - page.lastRx) / dt);
                        page.upSpeed = Math.max(0, (tx - page.lastTx) / dt);
                    }
                }
                page.lastRx = rx;
                page.lastTx = tx;
                page.lastTs = now;
                page.peakSpeed = Math.max(page.downSpeed, page.upSpeed, page.peakSpeed * 0.97, 1);
                var dh = page.downHistory.slice();
                dh.push(page.downSpeed);
                if (dh.length > 60)
                    dh.shift();

                page.downHistory = dh;
                var uh = page.upHistory.slice();
                uh.push(page.upSpeed);
                if (uh.length > 60)
                    uh.shift();

                page.upHistory = uh;
            }
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pNet.running)
                pNet.running = true;

        }
    }

    Process {
        id: pEthernet

        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]

        stdout: StdioCollector {
            onStreamFinished: {
                var result = {
                    "device": "",
                    "state": "disconnected",
                    "connection": ""
                };
                var raw = text.trim();
                if (raw) {
                    var lines = raw.split("\n");
                    for (var i = 0; i < lines.length; ++i) {
                        var line = lines[i].trim();
                        if (!line)
                            continue;

                        var fields = line.split(":");
                        if (fields.length < 4)
                            continue;

                        if (fields[1] === "ethernet") {
                            result.device = fields[0];
                            result.state = fields[2];
                            result.connection = fields.slice(3).join(":");
                            break;
                        }
                    }
                }
                page.ethernet = result;
            }
        }

        stderr: StdioCollector {
        }

    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pEthernet.running)
                pEthernet.running = true;

        }
    }

    Process {
        id: pRadioGet

        command: ["nmcli", "networking"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                page.wifiEnabled = text.trim() === "enabled";
                if (page.wifiEnabled && !pList.running)
                    pList.running = true;

            }
        }

    }

    Process {
        id: pRadioSet

        stdout: StdioCollector {
            onStreamFinished: {
                pRadioGet.running = true;
            }
        }

    }

    Process {
        id: pList

        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var raw = text.trim();
                if (raw) {
                    var lines = raw.split("\n");
                    for (var i = 0; i < lines.length; ++i) {
                        var line = lines[i].trim();
                        if (!line)
                            continue;

                        var fields = [];
                        var current = "";
                        var escaped = false;
                        for (var j = 0; j < line.length; ++j) {
                            var ch = line[j];
                            if (escaped) {
                                current += ch;
                                escaped = false;
                            } else if (ch === "\\") {
                                escaped = true;
                            } else if (ch === ":" && fields.length < 3) {
                                fields.push(current);
                                current = "";
                            } else {
                                current += ch;
                            }
                        }
                        fields.push(current);
                        if (fields.length < 4 || !fields[1])
                            continue;

                        var signal = parseInt(fields[2]);
                        if (isNaN(signal))
                            signal = 0;

                        out.push({
                            "ssid": fields[1],
                            "signal": signal,
                            "secured": fields[3] !== "" && fields[3] !== "--",
                            "connected": fields[0] === "*"
                        });
                    }
                }
                page.networks = out;
            }
        }

        stderr: StdioCollector {
        }

    }

    Process {
        id: pConnect

        function refresh() {
            page.pendingSsid = "";
            pEthernet.running = true;
            if (page.wifiEnabled)
                pList.running = true;

        }

        stdout: StdioCollector {
            onStreamFinished: pConnect.refresh()
        }

        stderr: StdioCollector {
            onStreamFinished: pConnect.refresh()
        }

    }

    Column {
        id: content

        anchors.fill: parent
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom
        spacing: 12

        Column {
            width: parent.width
            spacing: 3

            Text {
                text: "NETWORK"
                color: "#f0f0f0"
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.weight: Font.Normal
            }

            Text {
                text: "Wi-Fi, Ethernet and live traffic"
                color: "#999999"
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#383838"
        }

        Rectangle {
            id: wifiToggle

            property bool hovered: false

            width: parent.width
            height: 54
            radius: 10
            color: hovered ? Theme.alpha(Theme.text, 0.045) : Theme.alpha(Theme.text, 0.015)
            border.width: 1
            border.color: hovered ? "#555555" : "#393939"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: wifiAction.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: Theme.alpha(Theme.text, 0.025)
                    border.width: 1
                    border.color: "#414141"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: page.icWifi
                        color: page.wifiEnabled ? "#eeeeee" : "#858585"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                    }

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: "Wi-Fi"
                        color: "#f0f0f0"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        text: page.wifiEnabled ? "Wireless networking enabled" : "Wireless networking disabled"
                        color: "#999999"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                }

            }

            Rectangle {
                id: wifiAction

                property bool hovered: false

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: page.wifiEnabled ? 76 : 64
                height: 28
                radius: 7
                color: hovered ? Theme.alpha(Theme.text, 0.05) : Theme.alpha(Theme.text, 0.025)
                border.width: 1
                border.color: hovered ? "#777777" : "#505050"

                Text {
                    anchors.centerIn: parent
                    text: page.wifiEnabled ? "Disable" : "Enable"
                    color: "#eeeeee"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: wifiAction.hovered = true
                    onExited: wifiAction.hovered = false
                    onClicked: page.setWifiEnabled(!page.wifiEnabled)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 120
                    }

                }

            }

            HoverHandler {
                onHoveredChanged: wifiToggle.hovered = hovered
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

        Rectangle {
            id: trafficPanel

            width: parent.width
            height: 48
            radius: 10
            color: Theme.alpha(Theme.text, 0.015)
            border.width: 1
            border.color: "#393939"

            Column {
                anchors.fill: parent
                anchors.margins: 8
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 4

                Item {
                    width: parent.width
                    height: 14

                    Row {
                        anchors.fill: parent
                        spacing: 8

                        Text {
                            width: 16
                            text: page.icDown
                            color: "#70c98b"
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            id: downHeatmap

                            width: parent.width - 16 - 90 - parent.spacing * 2
                            height: parent.height
                            spacing: 1

                            Repeater {
                                model: 60

                                delegate: Rectangle {
                                    required property int index
                                    property int histIdx: page.downHistory.length - 60 + index
                                    property real sample: histIdx >= 0 && histIdx < page.downHistory.length ? page.downHistory[histIdx] : 0
                                    property real intensity: Math.min(1, sample / Math.max(1, page.peakSpeed))

                                    width: (downHeatmap.width - 59) / 60
                                    height: downHeatmap.height
                                    radius: 1
                                    color: sample > 0.01 ? Qt.rgba(0.44, 0.79, 0.55, 0.22 + 0.78 * intensity) : Qt.rgba(0.44, 0.79, 0.55, 0.06)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }

                                    }

                                }

                            }

                        }

                        Text {
                            width: 90
                            text: page.formatSpeed(page.downSpeed)
                            color: "#f2f2f2"
                            font.family: Theme.monoFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

                Item {
                    width: parent.width
                    height: 14

                    Row {
                        anchors.fill: parent
                        spacing: 8

                        Text {
                            width: 16
                            text: page.icUp
                            color: "#e5b567"
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            id: upHeatmap

                            width: parent.width - 16 - 90 - parent.spacing * 2
                            height: parent.height
                            spacing: 1

                            Repeater {
                                model: 60

                                delegate: Rectangle {
                                    required property int index
                                    property int histIdx: page.upHistory.length - 60 + index
                                    property real sample: histIdx >= 0 && histIdx < page.upHistory.length ? page.upHistory[histIdx] : 0
                                    property real intensity: Math.min(1, sample / Math.max(1, page.peakSpeed))

                                    width: (upHeatmap.width - 59) / 60
                                    height: upHeatmap.height
                                    radius: 1
                                    color: sample > 0.01 ? Qt.rgba(0.9, 0.71, 0.4, 0.22 + 0.78 * intensity) : Qt.rgba(0.9, 0.71, 0.4, 0.06)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }

                                    }

                                }

                            }

                        }

                        Text {
                            width: 90
                            text: page.formatSpeed(page.upSpeed)
                            color: "#f2f2f2"
                            font.family: Theme.monoFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

            }

        }

        Rectangle {
            id: ethCard

            property bool hovered: false

            width: parent.width
            height: 54
            radius: 10
            color: hovered ? Theme.alpha(Theme.text, 0.045) : Theme.alpha(Theme.text, 0.015)
            border.width: 1
            border.color: hovered ? "#555555" : "#393939"

            HoverHandler {
                onHoveredChanged: ethCard.hovered = hovered
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: ethState.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: Theme.alpha(Theme.text, 0.025)
                    border.width: 1
                    border.color: "#414141"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: page.icEth
                        color: page.ethernet.state === "connected" ? "#eeeeee" : "#858585"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                    }

                }

                Column {
                    width: Math.max(0, parent.width - 42)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: "Ethernet"
                        color: "#f0f0f0"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        text: page.ethernet.state === "connected" ? (page.ethernet.connection || page.ethernet.device) : "No active Ethernet connection"
                        color: "#999999"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                }

            }

            Rectangle {
                id: ethState

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: page.ethernet.state === "connected" ? 82 : 96
                height: 25
                radius: 7
                color: Theme.alpha(Theme.text, 0.025)
                border.width: 1
                border.color: "#4b4b4b"

                Text {
                    anchors.centerIn: parent
                    text: page.ethernet.state === "connected" ? "CONNECTED" : "DISCONNECTED"
                    color: page.ethernet.state === "connected" ? "#f0f0f0" : "#999999"
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }

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

        Row {
            width: parent.width
            height: 20
            spacing: 8

            Text {
                text: "AVAILABLE NETWORKS"
                color: "#e8e8e8"
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.wifiEnabled ? page.networks.length + (page.networks.length === 1 ? " network" : " networks") : "Wi-Fi is off"
                color: "#969696"
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

        }

        Item {
            id: listContainer

            width: parent.width
            height: Math.max(0, parent.height - y)

            Flickable {
                id: networksFlick

                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: networkPanel.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: networkColumn

                    width: networksFlick.width
                    spacing: 0

                    Rectangle {
                        id: networkPanel

                        width: networkColumn.width
                        height: networkRows.implicitHeight + 2
                        radius: 10
                        color: Theme.alpha(Theme.text, 0.015)
                        border.width: 1
                        border.color: "#393939"

                        Column {
                            id: networkRows

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 1
                            anchors.rightMargin: 1
                            anchors.topMargin: 1
                            spacing: 0

                            Rectangle {
                                visible: !page.wifiEnabled
                                width: networkRows.width
                                height: visible ? 70 : 0
                                color: "transparent"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Rectangle {
                                        width: 34
                                        height: 34
                                        radius: 8
                                        color: Theme.alpha(Theme.text, 0.025)
                                        border.width: 1
                                        border.color: "#404040"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: page.icWifi
                                            color: "#999999"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 16
                                        }

                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3

                                        Text {
                                            text: "Wi-Fi is disabled"
                                            color: "#eeeeee"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                        }

                                        Text {
                                            text: "Enable wireless networking to find nearby networks."
                                            color: "#999999"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                        }

                                    }

                                }

                            }

                            Rectangle {
                                visible: page.wifiEnabled && page.networks.length === 0
                                width: networkRows.width
                                height: visible ? 74 : 0
                                color: "transparent"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Rectangle {
                                        width: 34
                                        height: 34
                                        radius: 8
                                        color: Theme.alpha(Theme.text, 0.025)
                                        border.width: 1
                                        border.color: "#404040"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: page.icWifi
                                            color: "#dedede"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 16
                                        }

                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3

                                        Text {
                                            text: "Scanning networks"
                                            color: "#eeeeee"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                        }

                                        Text {
                                            text: "Nearby networks will appear here."
                                            color: "#999999"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                        }

                                    }

                                }

                            }

                            Repeater {
                                model: page.networks

                                delegate: Column {
                                    id: networkEntry

                                    required property var modelData
                                    property bool hovered: false

                                    width: networkRows.width
                                    spacing: 0

                                    Rectangle {
                                        id: networkCard

                                        width: parent.width
                                        height: 54
                                        radius: 0
                                        color: modelData.connected ? Theme.alpha(Theme.text, 0.035) : (networkEntry.hovered ? Theme.alpha(Theme.text, 0.025) : "transparent")

                                        HoverHandler {
                                            onHoveredChanged: networkEntry.hovered = hovered
                                        }

                                        Rectangle {
                                            width: 2
                                            height: parent.height - 16
                                            radius: 1
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: "#eeeeee"
                                            visible: modelData.connected
                                        }

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10

                                            Item {
                                                width: 20
                                                height: parent.height

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 2

                                                    Repeater {
                                                        model: 4

                                                        delegate: Rectangle {
                                                            required property int index

                                                            width: 3
                                                            height: 5 + index * 3
                                                            radius: 1
                                                            anchors.bottom: parent.bottom
                                                            color: (networkEntry.modelData.signal || 0) >= (index + 1) * 25 ? "#dcdcdc" : "#444444"
                                                        }

                                                    }

                                                }

                                            }

                                            Text {
                                                visible: networkEntry.modelData.secured
                                                text: page.icLock
                                                color: "#a0a0a0"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 11
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Column {
                                                width: Math.max(0, parent.width - 20 - (networkEntry.modelData.secured ? 18 : 0) - 82 - 20 - parent.spacing * 2)
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3

                                                Text {
                                                    width: parent.width
                                                    text: networkEntry.modelData.ssid
                                                    color: networkEntry.modelData.connected ? "#ffffff" : "#ededed"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: networkEntry.modelData.connected ? Font.DemiBold : Font.Medium
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: (networkEntry.modelData.connected ? "Connected · " : "") + (networkEntry.modelData.secured ? "Secured" : "Open network") + " · " + networkEntry.modelData.signal + "% signal"
                                                    color: "#999999"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                }

                                            }

                                            Rectangle {
                                                id: connectBtn

                                                property bool hovered: false

                                                width: 82
                                                height: 27
                                                radius: 7
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: hovered ? Theme.alpha(Theme.text, 0.05) : Theme.alpha(Theme.text, 0.025)
                                                border.width: 1
                                                border.color: hovered ? "#777777" : "#4b4b4b"

                                                Text {
                                                    anchors.centerIn: parent
                                                    width: parent.width - 8
                                                    text: networkEntry.modelData.connected ? "Disconnect" : (page.pendingSsid === networkEntry.modelData.ssid ? "Cancel" : "Connect")
                                                    color: "#eeeeee"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onEntered: connectBtn.hovered = true
                                                    onExited: connectBtn.hovered = false
                                                    onClicked: {
                                                        if (networkEntry.modelData.connected)
                                                            page.disconnect(networkEntry.modelData.ssid);
                                                        else if (networkEntry.modelData.secured)
                                                            page.pendingSsid = page.pendingSsid === networkEntry.modelData.ssid ? "" : networkEntry.modelData.ssid;
                                                        else
                                                            page.connectOpen(networkEntry.modelData.ssid);
                                                    }
                                                }

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }

                                                }

                                                Behavior on border.color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }

                                                }

                                            }

                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 130
                                            }

                                        }

                                    }

                                    Rectangle {
                                        id: passwordRow

                                        visible: page.pendingSsid === networkEntry.modelData.ssid
                                        width: parent.width
                                        height: visible ? 46 : 0
                                        color: Theme.alpha(Theme.text, 0.025)

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 8

                                            Rectangle {
                                                width: Math.max(0, Math.min(320, parent.width - 98))
                                                height: 30
                                                radius: 7
                                                color: Theme.alpha(Theme.text, 0.015)
                                                border.width: 1
                                                border.color: passwordField.activeFocus ? "#a0a0a0" : "#454545"
                                                anchors.verticalCenter: parent.verticalCenter

                                                TextInput {
                                                    id: passwordField

                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    color: "#eeeeee"
                                                    font.family: Theme.monoFont
                                                    font.pixelSize: 11
                                                    echoMode: TextInput.Password
                                                    focus: page.pendingSsid === networkEntry.modelData.ssid
                                                    selectByMouse: true
                                                    Keys.onReturnPressed: page.connectSecured(networkEntry.modelData.ssid, text)
                                                }

                                            }

                                            Rectangle {
                                                width: 78
                                                height: 30
                                                radius: 7
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: "#eeeeee"
                                                border.width: 1
                                                border.color: "#f5f5f5"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Connect"
                                                    color: "#151515"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: page.connectSecured(networkEntry.modelData.ssid, passwordField.text)
                                                }

                                            }

                                        }

                                    }

                                    Rectangle {
                                        visible: index < page.networks.length - 1 || page.pendingSsid === networkEntry.modelData.ssid
                                        width: parent.width - 24
                                        height: 1
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: "#383838"
                                    }

                                }

                            }

                        }

                    }

                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOff

                    background: Rectangle {
                        color: "transparent"
                    }

                    contentItem: Rectangle {
                        color: "transparent"
                    }

                }

            }

        }

    }

}
