import "../"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth

Item {
    id: page

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.state === BluetoothAdapterState.Enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false
    readonly property string adapterStatusLabel: {
        if (!adapter)
            return "BLUETOOTH UNAVAILABLE";

        if (adapter.state === BluetoothAdapterState.Enabling)
            return "BLUETOOTH STARTING";

        if (adapter.state === BluetoothAdapterState.Disabling)
            return "BLUETOOTH TURNING OFF";

        if (adapter.state === BluetoothAdapterState.Blocked)
            return "BLUETOOTH BLOCKED";

        return powered ? "BLUETOOTH ON" : "BLUETOOTH OFF";
    }
    property string statusText: ""
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property bool manualOff: false
    property bool powerRequestPending: false
    property bool requestedPower: false
    property bool discoveryCommandPending: false
    property bool desiredDiscovery: false
    property bool lastDiscoveryRequest: false

    function setStatus(text) {
        page.statusText = text;
        if (text !== "")
            statusTimer.restart();
        else
            statusTimer.stop();
    }

    function setDiscovering(on) {
        var shouldDiscover = Boolean(on) && page.visible;
        page.desiredDiscovery = shouldDiscover;
        if (!page.adapter || page.adapter.state !== BluetoothAdapterState.Enabled)
            return ;

        if (page.discoveryCommandPending || page.adapter.discovering === shouldDiscover)
            return ;

        page.discoveryCommandPending = true;
        page.lastDiscoveryRequest = shouldDiscover;
        page.adapter.discovering = shouldDiscover;
        discoveryCommandTimer.restart();
    }

    function syncDiscovery() {
        if (!page.adapter || page.adapter.state !== BluetoothAdapterState.Enabled)
            return ;

        page.setDiscovering(page.visible && page.powered);
    }

    function requestPower(on) {
        if (!page.adapter) {
            page.setStatus("Bluetooth service or adapter unavailable.");
            return ;
        }
        if (on && page.adapter.state === BluetoothAdapterState.Blocked) {
            page.setStatus("Bluetooth is blocked by the system.");
            return ;
        }
        if (on === page.powered && !page.powerRequestPending) {
            page.syncDiscovery();
            return ;
        }
        page.requestedPower = Boolean(on);
        page.powerRequestPending = true;
        page.adapter.enabled = Boolean(on);
        page.setStatus(on ? "Turning Bluetooth on..." : "Turning Bluetooth off...");
        powerTimeout.restart();
    }

    function tryAutoPower() {
        if (!page.adapter || page.manualOff || page.powered || page.powerRequestPending)
            return ;

        if (page.adapter.state === BluetoothAdapterState.Enabling || page.adapter.state === BluetoothAdapterState.Disabling)
            return ;

        if (page.adapter.state === BluetoothAdapterState.Blocked) {
            page.setStatus("Bluetooth is blocked by the system.");
            return ;
        }
        page.requestPower(true);
    }

    function togglePower() {
        if (!page.adapter) {
            page.setStatus("Bluetooth service or adapter unavailable.");
            return ;
        }
        if (page.adapter.state === BluetoothAdapterState.Enabling || page.adapter.state === BluetoothAdapterState.Disabling) {
            page.setStatus("Please wait for Bluetooth to finish changing state.");
            return ;
        }
        if (page.powered) {
            page.manualOff = true;
            page.setDiscovering(false);
            page.requestPower(false);
        } else {
            page.manualOff = false;
            page.requestPower(true);
        }
    }

    function deviceAction(dev, deviceCard) {
        if (!dev || !deviceCard || deviceCard.actionPending)
            return ;

        var name = dev.name || dev.deviceName || dev.address || "device";
        if (dev.blocked) {
            page.setStatus(name + " is blocked by Bluetooth.");
            return ;
        }
        if (dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting) {
            page.setStatus("Please wait for " + name + " to finish changing state.");
            return ;
        }
        if (deviceCard.timedOut) {
            var retryAction = deviceCard.lastFailedAction;
            if (retryAction === "connect" && (dev.connected || dev.state === BluetoothDeviceState.Connected)) {
                deviceCard.timedOut = false;
                deviceCard.lastFailedAction = "";
                page.setStatus("Connected to " + name);
                return ;
            }
            if (retryAction === "disconnect") {
                deviceCard.timedOut = false;
                deviceCard.lastFailedAction = "";
                if (!dev.connected && dev.state === BluetoothDeviceState.Disconnected) {
                    page.setStatus(name + " is already disconnected.");
                    return ;
                }
                deviceCard.beginDisconnect();
                return ;
            }
            deviceCard.timedOut = false;
            deviceCard.lastFailedAction = "";
            if (retryAction === "pair" && !dev.paired) {
                deviceCard.beginPairing();
                return ;
            }
            if (!dev.paired) {
                deviceCard.beginPairing();
                return ;
            }
            deviceCard.beginConnect();
            return ;
        }
        if (dev.connected || dev.state === BluetoothDeviceState.Connected) {
            deviceCard.beginDisconnect();
            return ;
        }
        if (dev.pairing) {
            page.setStatus("Pairing with " + name + "...");
            return ;
        }
        page.setDiscovering(false);
        dev.trusted = true;
        if (!dev.paired) {
            deviceCard.beginPairing();
            return ;
        }
        deviceCard.beginConnect();
    }

    function removeDevice(dev) {
        if (!dev)
            return ;

        for (var i = 0; i < repeater.count; i++) {
            var deviceCard = repeater.itemAt(i);
            if (deviceCard && deviceCard.modelData === dev) {
                deviceCard.beginForget();
                return ;
            }
        }
        if (dev.connected || dev.state === BluetoothDeviceState.Connected || dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting) {
            dev.disconnect();
            page.setStatus("Disconnecting before removing " + (dev.name || dev.deviceName || dev.address || "device") + "...");
            return ;
        }
        if (typeof BluetoothState !== "undefined" && BluetoothState.markRemoved)
            BluetoothState.markRemoved(dev);

        dev.forget();
    }

    function actionLabel(dev, deviceCard) {
        if (!dev)
            return "";

        if (deviceCard && deviceCard.timedOut)
            return "RETRY";

        if (deviceCard && deviceCard.actionPending) {
            if (deviceCard.pendingAction === "pair")
                return "PAIRING...";

            if (deviceCard.pendingAction === "connect")
                return "CONNECTING...";

            if (deviceCard.pendingAction === "disconnect")
                return "DISCONNECTING...";

        }
        if (dev.pairing)
            return "PAIRING...";

        if (dev.connected || dev.state === BluetoothDeviceState.Connected)
            return "DISCONNECT";

        switch (dev.state) {
        case BluetoothDeviceState.Connecting:
            return "CONNECTING...";
        case BluetoothDeviceState.Disconnecting:
            return "DISCONNECTING...";
        default:
            return dev.paired ? "CONNECT" : "PAIR";
        }
    }

    onAdapterChanged: {
        page.tryAutoPower();
        page.syncDiscovery();
    }
    onVisibleChanged: {
        page.syncDiscovery();
        if (page.visible)
            page.tryAutoPower();

    }
    onPoweredChanged: {
        page.syncDiscovery();
        if (!page.powerRequestPending)
            page.setStatus(page.powered ? "Bluetooth on" : "Bluetooth off");

    }
    Component.onCompleted: {
        page.tryAutoPower();
        page.syncDiscovery();
    }
    Component.onDestruction: {
        page.setDiscovering(false);
    }

    Timer {
        id: statusTimer

        interval: 4000
        onTriggered: page.statusText = ""
    }

    Timer {
        id: discoveryCommandTimer

        interval: 1200
        repeat: false
        onTriggered: {
            page.discoveryCommandPending = false;
            if (page.desiredDiscovery !== page.lastDiscoveryRequest)
                page.setDiscovering(page.desiredDiscovery);

        }
    }

    Timer {
        id: powerTimeout

        interval: 10000
        repeat: false
        onTriggered: {
            if (!page.adapter) {
                page.powerRequestPending = false;
                page.setStatus("Bluetooth service or adapter unavailable.");
                return ;
            }
            var complete = page.requestedPower ? page.powered : !page.powered;
            page.powerRequestPending = false;
            if (complete) {
                page.setStatus(page.requestedPower ? "Bluetooth on" : "Bluetooth off");
                page.syncDiscovery();
            } else {
                page.setStatus(page.requestedPower ? "Could not turn Bluetooth on. Check the adapter or service." : "Could not turn Bluetooth off.");
            }
        }
    }

    Timer {
        id: powerRecoveryTimer

        interval: 1000
        repeat: false
        onTriggered: {
            if (page.adapter && page.visible && !page.manualOff && !page.powerRequestPending && page.adapter.state === BluetoothAdapterState.Disabled)
                page.requestPower(true);

        }
    }

    Connections {
        function onStateChanged() {
            if (!page.adapter)
                return ;

            if (page.adapter.state === BluetoothAdapterState.Enabled) {
                if (page.powerRequestPending && page.requestedPower) {
                    page.powerRequestPending = false;
                    powerTimeout.stop();
                    page.setStatus("Bluetooth on");
                }
                page.syncDiscovery();
            } else if (page.adapter.state === BluetoothAdapterState.Disabled) {
                page.setDiscovering(false);
                if (page.powerRequestPending && !page.requestedPower) {
                    page.powerRequestPending = false;
                    powerTimeout.stop();
                    page.setStatus("Bluetooth off");
                } else if (!page.manualOff && !page.powerRequestPending && page.visible) {
                    powerRecoveryTimer.restart();
                }
            } else if (page.adapter.state === BluetoothAdapterState.Blocked) {
                page.setDiscovering(false);
                if (page.powerRequestPending) {
                    page.powerRequestPending = false;
                    powerTimeout.stop();
                }
                page.setStatus("Bluetooth is blocked by the system.");
            }
        }

        target: page.adapter
        ignoreUnknownSignals: true
    }

    Column {
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
                text: "BLUETOOTH"
                color: "#f0f0f0"
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.weight: Font.Normal
            }

            Text {
                text: "Nearby devices, pairing and connection status"
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
            id: powerStatus

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
                anchors.right: powerAction.left
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
                        text: "\uf294"
                        color: page.powered ? "#eeeeee" : "#858585"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                    }

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: "Bluetooth"
                        color: "#f0f0f0"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        text: page.adapter ? page.adapterStatusLabel.toLowerCase() : "waiting for adapter"
                        color: "#999999"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                }

            }

            Rectangle {
                id: powerAction

                property bool actionHovered: false

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: page.powered ? 76 : 64
                height: 28
                radius: 7
                color: actionHovered ? Theme.alpha(Theme.text, 0.05) : Theme.alpha(Theme.text, 0.025)
                border.width: 1
                border.color: actionHovered ? "#777777" : "#505050"

                Text {
                    anchors.centerIn: parent
                    text: page.powered ? "Disable" : "Enable"
                    color: "#eeeeee"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: powerAction.actionHovered = true
                    onExited: powerAction.actionHovered = false
                    onClicked: page.togglePower()
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
                onHoveredChanged: powerStatus.hovered = hovered
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

        Text {
            width: parent.width
            visible: page.statusText !== ""
            text: page.statusText
            color: "#999999"
            font.family: Theme.fontFamily
            font.pixelSize: 10
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignLeft
            leftPadding: 2
        }

        Text {
            width: parent.width
            visible: !page.adapter
            text: "Waiting for Bluetooth service and adapter..."
            color: "#999999"
            font.family: Theme.fontFamily
            font.pixelSize: 10
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignLeft
            leftPadding: 2
        }

        Flickable {
            id: flick

            width: parent.width
            height: Math.max(0, parent.height - y)
            clip: true
            contentWidth: width
            contentHeight: list.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: flick.width
                spacing: 6

                Rectangle {
                    width: list.width
                    height: 70
                    radius: 10
                    visible: page.adapter && !page.powered
                    color: Theme.alpha(Theme.text, 0.015)
                    border.width: 1
                    border.color: "#393939"

                    Row {
                        anchors.centerIn: parent
                        spacing: 12

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.text, 0.025)
                            border.width: 1
                            border.color: "#404040"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf294"
                                color: "#999999"
                                font.family: Theme.iconFont
                                font.pixelSize: 16
                            }

                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: "Bluetooth is off"
                                color: "#eeeeee"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            Text {
                                text: "Turn on the adapter to discover devices"
                                color: "#999999"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }

                        }

                    }

                }

                Rectangle {
                    width: list.width
                    height: 76
                    radius: 10
                    visible: page.powered && repeater.count === 0
                    color: Theme.alpha(Theme.text, 0.015)
                    border.width: 1
                    border.color: "#393939"

                    Row {
                        anchors.centerIn: parent
                        spacing: 12

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.text, 0.025)
                            border.width: 1
                            border.color: "#404040"

                            Text {
                                anchors.centerIn: parent
                                text: page.scanning ? "\uf1eb" : "\uf071"
                                color: "#dedede"
                                font.family: Theme.iconFont
                                font.pixelSize: 16
                            }

                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: page.scanning ? "Scanning devices" : "No devices found"
                                color: "#eeeeee"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            Text {
                                text: page.scanning ? "Make devices discoverable and keep this page open." : "Click here to scan again."
                                color: "#999999"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !page.scanning
                        onClicked: page.setDiscovering(true)
                    }

                }

                Repeater {
                    id: repeater

                    model: page.adapter && page.powered ? page.adapter.devices : null

                    delegate: Rectangle {
                        id: card

                        required property BluetoothDevice modelData
                        property bool connectAfterPair: false
                        property bool actionPending: false
                        property bool timedOut: false
                        property string pendingAction: ""
                        property string lastFailedAction: ""
                        property bool forgetPending: false
                        readonly property bool isConnected: modelData.connected || modelData.state === BluetoothDeviceState.Connected
                        readonly property string deviceKey: modelData.address || modelData.name || ""

                        function beginPairing() {
                            if (actionPending || !modelData)
                                return ;

                            timedOut = false;
                            lastFailedAction = "";
                            connectAfterPair = true;
                            actionPending = true;
                            pendingAction = "pair";
                            actionTimeout.interval = 30000;
                            actionTimeout.restart();
                            modelData.trusted = true;
                            page.setStatus("Pairing with " + (modelData.name || modelData.deviceName || modelData.address) + "...");
                            modelData.pair();
                        }

                        function beginConnect() {
                            if (!modelData || (actionPending && pendingAction !== "pair"))
                                return ;

                            timedOut = false;
                            lastFailedAction = "";
                            connectAfterPair = false;
                            actionPending = true;
                            pendingAction = "connect";
                            actionTimeout.interval = 18000;
                            actionTimeout.restart();
                            page.setStatus("Connecting to " + (modelData.name || modelData.deviceName || modelData.address) + "...");
                            modelData.connect();
                        }

                        function beginDisconnect() {
                            if (!modelData || actionPending)
                                return ;

                            timedOut = false;
                            lastFailedAction = "";
                            actionPending = true;
                            pendingAction = "disconnect";
                            actionTimeout.interval = 10000;
                            actionTimeout.restart();
                            page.setStatus("Disconnecting from " + (modelData.name || modelData.deviceName || modelData.address) + "...");
                            modelData.disconnect();
                        }

                        function finishAction(message) {
                            actionTimeout.stop();
                            actionPending = false;
                            timedOut = false;
                            pendingAction = "";
                            lastFailedAction = "";
                            connectAfterPair = false;
                            page.setStatus(message);
                        }

                        function beginForget() {
                            if (!modelData || forgetPending)
                                return ;

                            forgetPending = true;
                            actionTimeout.stop();
                            actionPending = false;
                            timedOut = false;
                            pendingAction = "";
                            connectAfterPair = false;
                            var name = modelData.name || modelData.deviceName || modelData.address || "device";
                            page.setStatus("Removing " + name + "...");
                            if (!modelData.connected && modelData.state === BluetoothDeviceState.Disconnected) {
                                finalizeForget();
                                return ;
                            }
                            modelData.disconnect();
                            forgetTimeout.restart();
                        }

                        function finalizeForget() {
                            if (!forgetPending || !modelData)
                                return ;

                            forgetTimeout.stop();
                            var target = modelData;
                            var name = target.name || target.deviceName || target.address || "device";
                            forgetPending = false;
                            if (typeof BluetoothState !== "undefined" && BluetoothState.markRemoved)
                                BluetoothState.markRemoved(target);

                            target.forget();
                            page.setStatus("Removal requested for " + name + ".");
                        }

                        visible: !(typeof BluetoothState !== "undefined" && BluetoothState.removingDevices && BluetoothState.removingDevices[deviceKey])
                        width: list.width
                        height: visible ? 54 : 0
                        radius: 10
                        color: isConnected ? Theme.alpha(Theme.text, 0.035) : (cardHover.hovered ? Theme.alpha(Theme.text, 0.045) : Theme.alpha(Theme.text, 0.015))
                        border.width: 1
                        border.color: cardHover.hovered ? "#555555" : "#393939"

                        HoverHandler {
                            id: cardHover
                        }

                        Timer {
                            id: forgetTimeout

                            interval: 10000
                            repeat: false
                            onTriggered: {
                                if (!card.forgetPending)
                                    return ;

                                var name = card.modelData.name || card.modelData.deviceName || card.modelData.address || "device";
                                card.forgetPending = false;
                                page.setStatus("Could not disconnect " + name + "; device was not removed.");
                            }
                        }

                        Timer {
                            id: actionTimeout

                            interval: 18000
                            repeat: false
                            onTriggered: {
                                if (!card.actionPending)
                                    return ;

                                var name = card.modelData.name || card.modelData.deviceName || card.modelData.address || "device";
                                if (card.pendingAction === "connect" && (card.modelData.connected || card.modelData.state === BluetoothDeviceState.Connected)) {
                                    card.finishAction("Connected to " + name);
                                    return ;
                                }
                                if (card.pendingAction === "disconnect" && !card.modelData.connected && card.modelData.state === BluetoothDeviceState.Disconnected) {
                                    card.finishAction("Disconnected from " + name);
                                    return ;
                                }
                                if (card.pendingAction === "pair" && card.modelData.paired) {
                                    card.beginConnect();
                                    return ;
                                }
                                var failedAction = card.pendingAction;
                                card.actionPending = false;
                                card.timedOut = true;
                                card.lastFailedAction = failedAction;
                                card.pendingAction = "";
                                card.connectAfterPair = false;
                                if (failedAction === "pair")
                                    page.setStatus("Pairing failed or timed out for " + name + ".");
                                else if (failedAction === "disconnect")
                                    page.setStatus("Could not disconnect " + name + ".");
                                else
                                    page.setStatus("Connection failed or timed out for " + name + ".");
                            }
                        }

                        Connections {
                            function onPairedChanged() {
                                if (card.modelData.paired && card.connectAfterPair && card.pendingAction === "pair")
                                    card.beginConnect();

                            }

                            function onConnectedChanged() {
                                var name = card.modelData.name || card.modelData.deviceName || card.modelData.address || "device";
                                if (card.modelData.connected) {
                                    if (card.actionPending && card.pendingAction === "connect") {
                                        card.finishAction("Connected to " + name);
                                    } else if (!card.actionPending) {
                                        card.timedOut = false;
                                        card.lastFailedAction = "";
                                        page.setStatus("Connected to " + name);
                                    }
                                } else if (card.actionPending && card.pendingAction === "disconnect" && card.modelData.state === BluetoothDeviceState.Disconnected) {
                                    card.finishAction("Disconnected from " + name);
                                }
                            }

                            function onStateChanged() {
                                var name = card.modelData.name || card.modelData.deviceName || card.modelData.address || "device";
                                if (card.forgetPending && !card.modelData.connected && card.modelData.state === BluetoothDeviceState.Disconnected) {
                                    card.finalizeForget();
                                    return ;
                                }
                                if (card.modelData.state === BluetoothDeviceState.Connected) {
                                    if (card.actionPending && card.pendingAction === "connect") {
                                        card.finishAction("Connected to " + name);
                                    } else if (!card.actionPending) {
                                        card.timedOut = false;
                                        card.lastFailedAction = "";
                                        page.setStatus("Connected to " + name);
                                    }
                                } else if (card.actionPending && card.pendingAction === "disconnect" && card.modelData.state === BluetoothDeviceState.Disconnected) {
                                    card.finishAction("Disconnected from " + name);
                                } else if (!card.actionPending && card.modelData.state === BluetoothDeviceState.Disconnected && card.lastFailedAction === "disconnect") {
                                    card.timedOut = false;
                                    card.lastFailedAction = "";
                                    page.setStatus("Disconnected from " + name);
                                }
                            }

                            target: card.modelData
                            ignoreUnknownSignals: true
                        }

                        Item {
                            id: actionArea

                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 118
                            height: 34

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    id: actionButton

                                    property bool hovered: false

                                    width: 82
                                    height: 28
                                    radius: 7
                                    color: hovered ? Theme.alpha(Theme.text, 0.05) : Theme.alpha(Theme.text, 0.025)
                                    border.width: 1
                                    border.color: hovered ? "#777777" : "#4b4b4b"

                                    Text {
                                        id: actionText

                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        text: page.actionLabel(card.modelData, card)
                                        color: "#eeeeee"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: actionButton.hovered = true
                                        onExited: actionButton.hovered = false
                                        onClicked: page.deviceAction(card.modelData, card)
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

                                Item {
                                    id: removeButton

                                    width: 26
                                    height: 28
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 7
                                        color: unpairMouseArea.containsMouse ? Theme.alpha(Theme.text, 0.06) : "transparent"
                                        border.width: 1
                                        border.color: unpairMouseArea.containsMouse ? "#555555" : "transparent"

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

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf293"
                                        color: unpairMouseArea.containsMouse ? "#eeeeee" : "#999999"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        id: unpairMouseArea

                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: page.removeDevice(card.modelData)
                                    }

                                    ToolTip {
                                        visible: unpairMouseArea.containsMouse
                                        delay: 600
                                        padding: 5
                                        parent: removeButton
                                        x: Math.round((removeButton.width - width) / 2)
                                        y: removeButton.height + 6

                                        background: Rectangle {
                                            color: "#202126"
                                            radius: 5
                                            border.width: 1
                                            border.color: "#414141"
                                        }

                                        contentItem: Text {
                                            text: "Unpair"
                                            color: "#eeeeee"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            font.weight: Font.Medium
                                        }

                                    }

                                }

                            }

                        }

                        Item {
                            id: deviceInfo

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: actionArea.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 38

                            Row {
                                anchors.fill: parent
                                spacing: 10

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.alpha(Theme.text, 0.025)
                                    border.width: 1
                                    border.color: "#414141"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf294"
                                        color: card.isConnected ? "#eeeeee" : "#a0a0a0"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 15
                                    }

                                }

                                Column {
                                    width: Math.max(0, parent.width - 42)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: card.modelData.name || card.modelData.deviceName || card.modelData.address
                                        elide: Text.ElideRight
                                        color: "#f0f0f0"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: card.isConnected ? Font.DemiBold : Font.Medium
                                    }

                                    Text {
                                        width: parent.width
                                        text: {
                                            var parts = [];
                                            if (card.isConnected)
                                                parts.push("Connected");
                                            else if (card.modelData.paired)
                                                parts.push("Paired");
                                            else
                                                parts.push("Available");
                                            if (card.modelData.address)
                                                parts.push(card.modelData.address);

                                            if (card.modelData.batteryAvailable)
                                                parts.push(Math.round(card.modelData.battery * 100) + "% battery");

                                            return parts.join(" · ");
                                        }
                                        color: "#999999"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
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
