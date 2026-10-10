
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0

    property string currentProfile: ""
    property var availableProfiles: []

    property bool hasBattery: false
    property int batteryPercent: 0
    property string batteryStatus: ""

    function profileLabel(governor) {
        switch (governor) {
        case "powersave":
            return "POWER SAVER"
        case "schedutil":
            return "BALANCED"
        case "ondemand":
            return "ON DEMAND"
        case "conservative":
            return "CONSERVATIVE"
        case "performance":
            return "PERFORMANCE"
        case "userspace":
            return "USERSPACE"
        default:
            return governor.toUpperCase()
        }
    }

    function profileIcon(governor) {
        switch (governor) {
        case "powersave":
        case "conservative":
            return "\uf06c"
        case "schedutil":
        case "ondemand":
            return "\uf24e"
        case "performance":
            return "\uf0e7"
        default:
            return "\uf013"
        }
    }

    function profileDescription(governor) {
        switch (governor) {
        case "powersave":
            return "Lower power usage"
        case "schedutil":
            return "Dynamic CPU scaling"
        case "ondemand":
            return "Scale on demand"
        case "conservative":
            return "Gradual frequency scaling"
        case "performance":
            return "Highest performance"
        case "userspace":
            return "User-controlled frequency"
        default:
            return "CPU governor"
        }
    }

    function setProfile(governor) {
        if (profileSet.running)
            return

        if (page.availableProfiles.indexOf(governor) === -1)
            return

        profileSet.command = [
            "sudo",
            "-n",
            "/usr/bin/cpupower",
            "frequency-set",
            "-g",
            governor
        ]

        profileSet.running = true
    }

    function refresh() {
        if (!profileGet.running)
            profileGet.running = true

        if (!profileList.running)
            profileList.running = true

        if (!batteryGet.running)
            batteryGet.running = true
    }

    Process {
        id: profileGet

        command: [
            "sh",
            "-c",
            "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const governor = text.trim()

                if (governor.length > 0)
                    page.currentProfile = governor
            }
        }
    }

    Process {
        id: profileList

        command: [
            "sh",
            "-c",
            "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output.length > 0) {
                    const found = output.split(/\s+/)
                    const preferredOrder = [
                        "powersave",
                        "schedutil",
                        "ondemand",
                        "conservative",
                        "performance",
                        "userspace"
                    ]

                    found.sort(function(a, b) {
                        let ai = preferredOrder.indexOf(a)
                        let bi = preferredOrder.indexOf(b)

                        if (ai === -1)
                            ai = preferredOrder.length

                        if (bi === -1)
                            bi = preferredOrder.length

                        return ai - bi
                    })

                    page.availableProfiles = found
                }
            }
        }
    }

    Process {
        id: profileSet

        onExited: exitCode => {
            if (exitCode !== 0) {
                Quickshell.execDetached([
                    "notify-send",
                    "CPU governor",
                    "Failed to change governor. Check cpupower and sudo permissions."
                ])
            }

            refreshTimer.restart()
        }
    }

    Process {
        id: batteryGet

        command: [
            "sh",
            "-c",
            "for b in /sys/class/power_supply/BAT*; do " +
            "if [ -r \"$b/capacity\" ] && [ -r \"$b/status\" ]; then " +
            "cat \"$b/capacity\"; cat \"$b/status\"; exit 0; fi; done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                if (lines.length >= 2 && lines[0].length > 0) {
                    const percent = parseInt(lines[0])

                    if (!isNaN(percent)) {
                        page.batteryPercent = Math.max(
                            0,
                            Math.min(100, percent)
                        )

                        page.batteryStatus = lines[1].trim()
                        page.hasBattery = true
                        return
                    }
                }

                page.hasBattery = false
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 400

        onTriggered: page.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true

        onTriggered: {
            if (!batteryGet.running)
                batteryGet.running = true

            if (!profileGet.running)
                profileGet.running = true
        }
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

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            background: Rectangle {
                color: "transparent"
                radius: width / 2
            }

            contentItem: Rectangle {
                color: Theme.accent
                radius: width / 2
            }
        }

        Column {
            id: content

            width: flick.width
            spacing: 14

            Text {
                text: "POWER"
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

            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "CPU GOVERNOR"
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 2
                }

                Text {
                    width: parent.width
                    text: page.currentProfile.length > 0
                          ? "CURRENT: " + page.currentProfile.toUpperCase()
                          : "CURRENT: DETECTING..."
                    color: Theme.textDim
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: page.availableProfiles

                        delegate: Rectangle {
                            id: card

                            required property string modelData

                            readonly property bool selected:
                                page.currentProfile === modelData

                            property bool hovered: false

                            width: (
                                parent.width -
                                parent.spacing * (page.availableProfiles.length - 1)
                            ) / Math.max(1, page.availableProfiles.length)

                            height: 100
                            radius: Theme.radius

                            color: selected
                                   ? Theme.alpha(Theme.accent, 0.10)
                                   : hovered
                                     ? Theme.alpha(Theme.accent, 0.08)
                                     : "#00000000"

                            border.width: 1
                            border.color: (selected || hovered)
                                          ? Theme.accent
                                          : Theme.border

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Theme.radius

                                    anchors.horizontalCenter: parent.horizontalCenter

                                    color: card.selected
                                           ? Theme.alpha(Theme.accent, 0.10)
                                           : Theme.alpha("#A0A0A0", 0.15)

                                    border.width: 1
                                    border.color: card.selected
                                                  ? Theme.accent
                                                  : Theme.border

                                    Text {
                                        anchors.centerIn: parent

                                        text: page.profileIcon(card.modelData)
                                        color: card.selected
                                               ? Theme.accent
                                               : "#A0A0A0"

                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    text: page.profileLabel(card.modelData)
                                    color: Theme.text

                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 1
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    text: page.profileDescription(card.modelData)
                                    color: Theme.textDim

                                    font.family: "Noto Sans"
                                    font.pixelSize: 9
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    visible: card.selected
                                    text: "ACTIVE"
                                    color: Theme.accent

                                    font.family: "Noto Sans"
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !profileSet.running

                                onEntered: card.hovered = true
                                onExited: card.hovered = false

                                onClicked: {
                                    if (!card.selected)
                                        page.setProfile(card.modelData)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: page.availableProfiles.length === 0

                    width: parent.width
                    text: "No CPU governors detected. Check the cpufreq driver."
                    color: Theme.textDim

                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width

                    text: "Available governors are detected directly from the kernel."
                    color: Theme.textDim

                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                visible: page.hasBattery

                width: parent.width
                height: 100
                radius: Theme.radius

                color: "#00000000"
                border.width: 1
                border.color: Theme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Row {
                        spacing: 10

                        Text {
                            text: "BATTERY"
                            color: Theme.text

                            font.family: "Noto Sans"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            text: page.batteryStatus.toUpperCase()
                            color: Theme.textDim

                            font.family: "Noto Sans"
                            font.pixelSize: 12
                        }

                        Text {
                            visible: page.batteryStatus === "Charging"

                            text: "CHARGING"
                            color: Theme.accent2

                            font.family: "Noto Sans"
                            font.pixelSize: 10
                        }
                    }

                    Item {
                        width: parent.width
                        height: levelLabel.implicitHeight

                        Text {
                            id: levelLabel

                            anchors.left: parent.left
                            text: "LEVEL"
                            color: Theme.textDim

                            font.family: "Noto Sans"
                            font.pixelSize: 11
                        }

                        Text {
                            anchors.right: parent.right

                            text: page.batteryPercent + "%"
                            color: Theme.text

                            font.family: "Noto Sans"
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3

                        color: Theme.alpha("#A0A0A0", 0.15)

                        Rectangle {
                            width: parent.width * Math.max(
                                0,
                                Math.min(1, page.batteryPercent / 100)
                            )

                            height: parent.height
                            radius: 3

                            color: page.batteryPercent <= 15
                                   ? "#E05555"
                                   : Theme.accent2

                            Behavior on width {
                                NumberAnimation {
                                    duration: 200
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: page.refresh()
}
