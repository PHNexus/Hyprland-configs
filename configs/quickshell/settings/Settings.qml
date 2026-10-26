import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

FloatingWindow {
    id: root

    property bool showing: false
    property bool cardVisible: false
    property int selectedIndex: 0
    property var sink: Pipewire.defaultAudioSink
    property var navEntries: [{
        "group": "DISPLAY & SOUND",
        "name": "Display",
        "short": "1",
        "icon": "\uf108",
        "page": "Display"
    }, {
        "group": "DISPLAY & SOUND",
        "name": "Sound",
        "short": "2",
        "icon": "\uf028",
        "page": "Sound"
    }, {
        "group": "CONNECTIVITY",
        "name": "Network",
        "short": "5",
        "icon": "\uf1eb",
        "page": "Network"
    }, {
        "group": "CONNECTIVITY",
        "name": "Bluetooth",
        "short": "6",
        "icon": "󰂯",
        "page": "Bluetooth"
    }, {
        "group": "SYSTEM",
        "name": "Storage",
        "short": "7",
        "icon": "󰋊",
        "page": "Storage"
    }, {
        "group": "SYSTEM",
        "name": "Power",
        "short": "9",
        "icon": "󰐥",
        "page": "Power"
    }, {
        "group": "ADVANCED",
        "name": "General",
        "short": "4",
        "icon": "\uf013",
        "page": "General"
    }, {
        "group": "ADVANCED",
        "name": "Input",
        "short": "3",
        "icon": "\uf11c",
        "page": "Input"
    }, {
        "group": "ADVANCED",
        "name": "Keybinds",
        "short": "8",
        "icon": "󰌌",
        "page": "Keybinds"
    }, {
        "group": "ADVANCED",
        "name": "AutoStart",
        "short": "0",
        "icon": "󰧮",
        "page": "Autostart"
    }, {
        "group": "ADVANCED",
        "name": "Configs",
        "short": "-",
        "icon": "󰧮",
        "page": "Configs"
    }]

    function show() {
        cardVisible = true;
        if (showing) {
            if (!root.backingWindowVisible) {
                showing = false;
                windowRecoveryTimer.restart();
            }
            return ;
        }
        showing = true;
    }

    function hide() {
        windowRecoveryTimer.stop();
        showing = false;
        cardVisible = false;
    }

    function toggle() {
        if (showing && root.backingWindowVisible) {
            hide();
            return ;
        }
        show();
    }

    function isFirstOfGroup(idx) {
        if (idx === 0)
            return true;

        return navEntries[idx].group !== navEntries[idx - 1].group;
    }

    title: "Settings"
    color: "transparent"
    visible: showing
    implicitWidth: 940
    implicitHeight: 640
    minimumSize: Qt.size(720, 480)
    maximumSize: Qt.size(1400, 900)
    onClosed: {
        windowRecoveryTimer.stop();
        root.showing = false;
        root.cardVisible = false;
    }
    onVisibleChanged: {
        if (visible) {
            card.opacity = 0;
            card.scale = 0.96;
            openAnimation.start();
        }
    }

    Timer {
        id: windowRecoveryTimer

        interval: 50
        repeat: false
        onTriggered: {
            if (root.cardVisible)
                root.showing = true;

        }
    }

    ParallelAnimation {
        id: openAnimation

        NumberAnimation {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: card
            property: "scale"
            from: 0.96
            to: 1
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }

    }

    IpcHandler {
        function toggle() {
            root.toggle();
        }

        function show() {
            root.show();
        }

        function hide() {
            root.hide();
        }

        function sound() {
            root.selectedIndex = 1;
            root.show();
        }

        function display() {
            root.selectedIndex = 0;
            root.show();
        }

        function network() {
            root.selectedIndex = 2;
            root.show();
        }

        function bluetooth() {
            root.selectedIndex = 3;
            root.show();
        }

        function storage() {
            root.selectedIndex = 4;
            root.show();
        }

        function power() {
            root.selectedIndex = 5;
            root.show();
        }

        function general() {
            root.selectedIndex = 6;
            root.show();
        }

        function input() {
            root.selectedIndex = 7;
            root.show();
        }

        function keybinds() {
            root.selectedIndex = 8;
            root.show();
        }

        function autostart() {
            root.selectedIndex = 9;
            root.show();
        }

        function configs() {
            root.selectedIndex = 10;
            root.show();
        }

        target: "settings"
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Rectangle {
        id: card

        anchors.fill: parent
        color: Theme.glass
        radius: Theme.radius
        border.width: 0
        clip: true
        opacity: 0
        scale: 0.96
        transformOrigin: Item.Center

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.ringOuter

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: parent.radius
                anchors.rightMargin: parent.radius
                height: 1
                color: Theme.tint("#ffffff", 0.08)
            }

        }

        Item {
            anchors.fill: parent
            anchors.margins: 22

            Column {
                id: sidebar

                width: 180
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                spacing: 0

                Item {
                    width: parent.width
                    height: 56

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 9
                            color: Theme.tint("#ffffff", 0.06)
                            border.width: 1
                            border.color: Theme.borderStrong
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                radius: 6
                                color: Theme.tint("#ffffff", 0.1)
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: 3
                                color: Theme.accent

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: Theme.tint("#ffffff", 0.15)
                                }

                            }

                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: "Settings"
                                color: Theme.text
                                font.family: Theme.displayFont
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                font.letterSpacing: -0.2
                            }

                            Text {
                                text: "v1.0"
                                color: Theme.textFaint
                                font.family: Theme.monoFont
                                font.pixelSize: 9
                                font.letterSpacing: 1.2
                            }

                        }

                    }

                }

                Item {
                    width: 1
                    height: 6
                }

                Repeater {
                    model: root.navEntries

                    delegate: Column {
                        required property var modelData
                        required property int index

                        width: sidebar.width
                        spacing: 0

                        Item {
                            width: parent.width
                            height: root.isFirstOfGroup(index) ? 24 : 0
                            visible: root.isFirstOfGroup(index)

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: modelData.group
                                color: Theme.textGhost
                                font.family: Theme.monoFont
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                font.letterSpacing: 1.6
                            }

                        }

                        Item {
                            id: navItem

                            readonly property bool active: root.selectedIndex === index

                            width: sidebar.width
                            height: 36

                            Item {
                                width: 8
                                height: 20
                                anchors.left: parent.left
                                anchors.leftMargin: -4
                                anchors.verticalCenter: parent.verticalCenter
                                visible: navItem.active
                                opacity: navItem.active ? 1 : 0

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8
                                    height: 20
                                    radius: 4
                                    color: Theme.tint("#ffffff", 0.15)
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: 16
                                    radius: 1.5
                                    color: Theme.accent
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.animFast
                                    }

                                }

                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 2
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                radius: Theme.radiusSm
                                color: navItem.active ? Theme.bgCard : (itemMouse.containsMouse ? Theme.bgPanel : "transparent")
                                border.width: navItem.active ? 1 : 0
                                border.color: Theme.border

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.animFast
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on border.width {
                                    NumberAnimation {
                                        duration: Theme.animFast
                                    }

                                }

                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                Text {
                                    text: modelData.icon
                                    color: navItem.active ? Theme.accent : Theme.textFaint
                                    font.family: Theme.iconFont
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.animFast
                                        }

                                    }

                                }

                                Text {
                                    text: modelData.name
                                    color: navItem.active ? Theme.text : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: navItem.active ? Font.Medium : Font.Normal
                                    font.letterSpacing: -0.1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.animFast
                                        }

                                    }

                                }

                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                radius: 5
                                color: navItem.active ? Theme.tint("#ffffff", 0.08) : "transparent"
                                border.width: navItem.active ? 1 : 0
                                border.color: Theme.border
                                visible: navItem.active || itemMouse.containsMouse

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.short
                                    color: navItem.active ? Theme.textSoft : Theme.textGhost
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.animFast
                                    }

                                }

                            }

                            MouseArea {
                                id: itemMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedIndex = index
                            }

                        }

                    }

                }

                Item {
                    width: 1
                    height: 4
                }

            }

            Rectangle {
                id: divider

                x: sidebar.x + sidebar.width + 12
                y: 6
                width: 1
                height: parent.height - 12
                color: Theme.border
            }

            Item {
                anchors.left: divider.right
                anchors.leftMargin: 28
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                Item {
                    id: contentHeader

                    width: parent.width
                    height: 56

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Row {
                            spacing: 10

                            Text {
                                text: root.navEntries[root.selectedIndex].name
                                color: Theme.text
                                font.family: Theme.displayFont
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                                font.letterSpacing: -0.4
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: Theme.textGhost
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "configure"
                                color: Theme.textFaint
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                                font.letterSpacing: 1.3
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.navEntries[root.selectedIndex].icon
                        color: Theme.textGhost
                        font.family: Theme.iconFont
                        font.pixelSize: 30
                        opacity: 0.35
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.border
                    }

                }

                Item {
                    anchors.top: contentHeader.bottom
                    anchors.topMargin: 20
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true

                    Loader {
                        id: pageLoader

                        anchors.fill: parent
                        source: "Tabs/" + root.navEntries[root.selectedIndex].page + ".qml"
                        onSourceChanged: fadeIn.restart()

                        SequentialAnimation {
                            id: fadeIn

                            PropertyAction {
                                target: pageLoader
                                property: "opacity"
                                value: 0
                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: pageLoader
                                    property: "opacity"
                                    to: 1
                                    duration: Theme.animMed
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: pageLoader
                                    property: "scale"
                                    from: 0.99
                                    to: 1
                                    duration: Theme.animMed
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animMed
                            }

                        }

                    }

                }

            }

        }

    }

}
