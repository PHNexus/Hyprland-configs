import "../"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth

Item {
    id: page

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false

    property string statusText: ""
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property bool manualOff: false

    function setStatus(text) {
        page.statusText = text

        if (text !== "")
            statusTimer.restart()
        else
            statusTimer.stop()
    }

    function tryAutoPower() {
        if (!page.adapter || page.manualOff)
            return

        if (page.adapter.enabled)
            return

        page.adapter.enabled = true
    }

    function setDiscovering(on) {
        if (!page.adapter || !page.powered)
            return

        page.adapter.discovering = Boolean(on)
    }

    function togglePower() {
        if (!page.adapter) {
            page.setStatus("Bluetooth service unavailable, attempting to initialize...")
            return
        }

        if (page.adapter.enabled) {
            page.manualOff = true
            page.setDiscovering(false)
            page.adapter.enabled = false
            page.setStatus("Bluetooth off")
            return
        }

        page.manualOff = false
        page.adapter.enabled = true
        page.setStatus("Turning Bluetooth on...")
    }

    function deviceAction(dev, deviceCard) {
        if (!dev)
            return

        var name = dev.name || dev.deviceName || dev.address || "device"

        if (dev.state === BluetoothDeviceState.Connected) {
            page.setStatus("Disconnecting " + name + "...")
            dev.disconnect()
            return
        }

        if (dev.state === BluetoothDeviceState.Connecting) {
            page.setStatus("Connecting to " + name + "...")
            return
        }

        if (dev.state === BluetoothDeviceState.Disconnecting) {
            page.setStatus("Disconnecting " + name + "...")
            return
        }

        if (dev.pairing) {
            page.setStatus("Pairing with " + name + "...")
            return
        }

        page.setDiscovering(false)
        dev.trusted = true

        if (!dev.paired) {
            if (deviceCard)
                deviceCard.connectAfterPair = true

            page.setStatus("Pairing with " + name + "...")
            dev.pair()
            return
        }

        page.setStatus("Connecting to " + name + "...")
        dev.connect()
    }

    function removeDevice(dev) {
        if (!dev)
            return

        BluetoothState.markRemoved(dev)

        if (
            dev.state === BluetoothDeviceState.Connected ||
            dev.state === BluetoothDeviceState.Connecting ||
            dev.state === BluetoothDeviceState.Disconnecting
        ) {
            dev.disconnect()
        }

        dev.forget()
    }

    function actionLabel(dev) {
        if (!dev)
            return ""

        if (dev.pairing)
            return "PAIRING..."

        switch (dev.state) {
        case BluetoothDeviceState.Connected:
            return "DISCONNECT"

        case BluetoothDeviceState.Connecting:
            return "CONNECTING..."

        case BluetoothDeviceState.Disconnecting:
            return "DISCONNECTING..."

        default:
            return dev.paired ? "CONNECT" : "PAIR"
        }
    }

    onAdapterChanged: {
        page.tryAutoPower()
    }

    onVisibleChanged: {
        if (page.visible) {
            page.tryAutoPower()
            page.setDiscovering(page.powered)
        } else {
            page.setDiscovering(false)
        }
    }

    onPoweredChanged: {
        if (page.powered) {
            page.setDiscovering(page.visible)
        } else {
            page.setDiscovering(false)
        }
    }

    Component.onCompleted: {
        page.tryAutoPower()
    }

    Component.onDestruction: {
        page.setDiscovering(false)
    }

    Timer {
        id: statusTimer

        interval: 3500

        onTriggered: {
            page.statusText = ""
        }
    }

    Timer {
        id: autoPowerTimer

        interval: 1500
        repeat: true
        running: true

        onTriggered: {
            if (!page.adapter) {
                return
            }
            if (!page.adapter.enabled && !page.manualOff) {
                page.adapter.enabled = true
            }
        }
    }

    Connections {
        target: page.adapter

        function onEnabledChanged() {
            if (page.adapter && page.adapter.enabled) {
                page.setStatus("Bluetooth on")
                page.setDiscovering(page.visible)
            } else {
                page.setDiscovering(false)
            }
        }
    }

    Timer {
        id: discoveryRetryTimer

        interval: 1500
        repeat: true

        running: page.powered &&
                 page.adapter &&
                 page.adapter.enabled

        onTriggered: {
            if (
                page.adapter &&
                page.powered &&
                !page.adapter.discovering
            ) {
                page.adapter.discovering = true
            }
        }
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

            color: page.powered
                   ? Theme.alpha(Theme.accent, 0.1)
                   : Theme.alpha(Theme.textFaint, 0.15)

            border.width: 1
            border.color: page.powered
                          ? Theme.accent
                          : Theme.textFaint

            Text {
                anchors.centerIn: parent

                text: {
                    if (!page.adapter)
                        return "BLUETOOTH UNAVAILABLE"

                    return page.powered
                           ? "BLUETOOTH ON"
                           : "BLUETOOTH OFF"
                }

                color: page.powered
                       ? Theme.accent
                       : Theme.textFaint

                font.family: "Noto Sans"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    page.togglePower()
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
                            text: page.scanning
                                  ? "SCANNING FOR DEVICES..."
                                  : "NO DEVICES FOUND"

                            color: Theme.textDim
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }

                        Text {
                            width: list.width - 20
                            anchors.horizontalCenter: parent.horizontalCenter

                            text: page.scanning
                                  ? "Make your device discoverable and keep this page open."
                                  : "Waiting for Bluetooth discovery..."

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

                    model: page.adapter && page.powered
                           ? page.adapter.devices
                           : null

                    delegate: Rectangle {
                        id: card

                        required property BluetoothDevice modelData

                        property bool connectAfterPair: false

                        readonly property bool isConnected:
                            modelData.state === BluetoothDeviceState.Connected

                        readonly property string deviceKey:
                            modelData.address || modelData.name || ""

                        visible: !(BluetoothState.removingDevices &&
                                   BluetoothState.removingDevices[deviceKey])

                        width: list.width
                        height: visible ? 52 : 0
                        radius: Theme.radius

                        color: isConnected
                               ? Theme.alpha(Theme.accent, 0.1)
                               : "transparent"

                        border.width: 1
                        border.color: isConnected
                                      ? Theme.accent
                                      : Theme.border

                        Connections {
                            target: card.modelData

                            function onPairedChanged() {
                                if (
                                    card.modelData.paired &&
                                    card.connectAfterPair
                                ) {
                                    card.connectAfterPair = false
                                    card.modelData.trusted = true

                                    page.setStatus(
                                        "Connecting to " +
                                        (card.modelData.name ||
                                         card.modelData.deviceName ||
                                         card.modelData.address) + "..."
                                    )

                                    card.modelData.connect()
                                }
                            }

                            function onStateChanged() {
                                if (
                                    card.modelData.state ===
                                    BluetoothDeviceState.Connected
                                ) {
                                    page.setStatus(
                                        "Connected to " +
                                        (card.modelData.name ||
                                         card.modelData.deviceName ||
                                         card.modelData.address)
                                    )
                                }
                            }

                            function onPairingChanged() {
                                if (
                                    !card.modelData.pairing &&
                                    !card.modelData.paired &&
                                    card.connectAfterPair
                                ) {
                                    card.connectAfterPair = false
                                    page.setStatus("Pairing failed. Check Bluetooth permissions.")
                                }
                            }
                        }

                        Item {
                            id: actionArea

                            x: 14
                            y: 0
                            width: 120
                            height: card.height

                            Text {
                                id: actionText

                                x: 0
                                y: (parent.height - height) / 2

                                width: Math.min(
                                    implicitWidth,
                                    parent.width - removeButton.width - 12
                                )

                                text: page.actionLabel(card.modelData)
                                color: card.isConnected
                                       ? Theme.danger
                                       : Theme.accent

                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        page.deviceAction(
                                            card.modelData,
                                            card
                                        )
                                    }
                                }
                            }

                            Item {
                                id: removeButton

                                x: actionText.width + 12
                                y: (parent.height - height) / 2

                                width: 28
                                height: 28

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
                                        page.removeDevice(card.modelData)
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

                        Item {
                            id: deviceInfo

                            x: actionArea.width + 28
                            y: 0

                            width: Math.max(
                                0,
                                card.width - actionArea.width - 42
                            )

                            height: card.height

                            Text {
                                id: deviceIcon

                                x: 0
                                y: (parent.height - height) / 2

                                width: 18
                                height: 18

                                text: "\uf294"

                                color: card.isConnected
                                       ? Theme.accent
                                       : Theme.textDim

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

                                    text: card.modelData.name ||
                                          card.modelData.deviceName ||
                                          card.modelData.address

                                    elide: Text.ElideRight
                                    color: Theme.text

                                    font.family: "Noto Sans"
                                    font.pixelSize: 12
                                }

                                Text {
                                    width: parent.width

                                    text: {
                                        var parts = []

                                        if (card.modelData.address)
                                            parts.push(card.modelData.address)

                                        if (card.isConnected)
                                            parts.push("connected")
                                        else if (card.modelData.paired)
                                            parts.push("paired")

                                        if (card.modelData.batteryAvailable) {
                                            parts.push(
                                                Math.round(
                                                    card.modelData.battery * 100
                                                ) + "%"
                                            )
                                        }

                                        return parts.join("  •  ")
                                    }

                                    color: card.isConnected
                                           ? Theme.accent
                                           : Theme.textFaint

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