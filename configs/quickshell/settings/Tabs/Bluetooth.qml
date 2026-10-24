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
        spacing: 14

        Text {
            text: "BLUETOOTH"
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
            width: parent.width
            height: 36
            radius: Theme.radius
            color: page.powered ? Theme.alpha(Theme.accent, 0.1) : Theme.alpha(Theme.textFaint, 0.15)
            border.width: 1
            border.color: page.powered ? Theme.accent : Theme.textFaint

            Text {
                anchors.centerIn: parent
                text: page.adapterStatusLabel
                color: page.powered ? Theme.accent : Theme.textFaint
                font.family: "Noto Sans"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    page.togglePower();
                }
            }

        }

        Text {
            width: parent.width
            visible: page.statusText !== ""
            text: page.statusText
            color: Theme.accent
            font.family: "Noto Sans"
            font.pixelSize: 10
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            visible: !page.adapter
            text: "Waiting for Bluetooth service and adapter..."
            color: Theme.textDim
            font.family: "Noto Sans"
            font.pixelSize: 10
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
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

                Item {
                    width: list.width
                    height: 100
                    visible: page.adapter && !page.powered

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf294"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BLUETOOTH IS OFF"
                            color: Theme.textDim
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }

                    }

                }

                Item {
                    width: list.width
                    height: 112
                    visible: page.powered && repeater.count === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.scanning ? "\uf1eb" : "\uf071"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 22
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.scanning ? "SCANNING FOR DEVICES..." : "NO DEVICES FOUND"
                            color: Theme.textDim
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }

                        Text {
                            width: list.width - 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.scanning ? "Make your device discoverable and keep this page open." : "Waiting for Bluetooth discovery..."
                            color: Theme.textFaint
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
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
                        height: visible ? 52 : 0
                        radius: Theme.radius
                        color: isConnected ? Theme.alpha(Theme.accent, 0.1) : "transparent"
                        border.width: 1
                        border.color: isConnected ? Theme.accent : Theme.border

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

                            x: 14
                            y: 0
                            width: 140
                            height: card.height

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                Text {
                                    id: actionText

                                    width: Math.min(implicitWidth, 80)
                                    height: parent.height
                                    text: page.actionLabel(card.modelData, card)
                                    color: card.isConnected ? Theme.danger : Theme.accent
                                    font.family: "Noto Sans"
                                    font.pixelSize: 10
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            page.deviceAction(card.modelData, card);
                                        }
                                    }

                                }

                                Item {
                                    id: removeButton

                                    width: 28
                                    height: 28
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf293"
                                        color: Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: 16
                                    }

                                    MouseArea {
                                        id: unpairMouseArea

                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            page.removeDevice(card.modelData);
                                        }
                                    }

                                    Rectangle {
                                        visible: unpairMouseArea.containsMouse
                                        z: 100
                                        x: -8
                                        y: removeButton.height + 6
                                        width: tooltipText.width + 16
                                        height: 24
                                        radius: 4
                                        color: "transparent"

                                        Text {
                                            id: tooltipText

                                            anchors.centerIn: parent
                                            text: "Unpair"
                                            color: "white"
                                            font.family: "Noto Sans"
                                            font.pixelSize: 10
                                        }

                                    }

                                }

                            }

                        }

                        Item {
                            id: deviceInfo

                            x: actionArea.width + 28
                            y: 0
                            width: Math.max(0, card.width - actionArea.width - 42)
                            height: card.height

                            Text {
                                id: deviceIcon

                                x: 0
                                y: (parent.height - height) / 2
                                width: 18
                                height: 18
                                text: "\uf294"
                                color: card.isConnected ? Theme.accent : Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignVCenter
                            }

                            Column {
                                id: deviceText

                                x: 28
                                y: (parent.height - height) / 2
                                width: Math.max(0, parent.width - x)
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: card.modelData.name || card.modelData.deviceName || card.modelData.address
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: "Noto Sans"
                                    font.pixelSize: 12
                                }

                                Text {
                                    width: parent.width
                                    text: {
                                        var parts = [];
                                        if (card.modelData.address)
                                            parts.push(card.modelData.address);

                                        if (card.isConnected)
                                            parts.push("connected");
                                        else if (card.modelData.paired)
                                            parts.push("paired");
                                        if (card.modelData.batteryAvailable)
                                            parts.push(Math.round(card.modelData.battery * 100) + "%");

                                        return parts.join("  •  ");
                                    }
                                    color: card.isConnected ? Theme.accent : Theme.textFaint
                                    font.family: "Noto Sans"
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
