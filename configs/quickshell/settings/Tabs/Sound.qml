import QtQuick
import QtQuick.Controls
import Quickshell.Services.Pipewire
import "../"
Item {
    id: page
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property real sliderMarginRight: 10
    property real sectionSpacing: 4
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }
    property var sink: Pipewire.defaultAudioSink
    property real volume: sink?.audio?.volume ?? 0
    property bool muted: sink?.audio?.muted ?? false
    property var source: Pipewire.defaultAudioSource
    property real inputVolume: source?.audio?.volume ?? 0
    property bool inputMuted: source?.audio?.muted ?? false
    property var outputSinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    property var inputSources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    property var appStreams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
    function displayName(node, fallback) {
        return node?.description || node?.nickname || node?.name || fallback
    }
    function setDefaultOutput(output) {
        if (output)
            Pipewire.preferredDefaultAudioSink = output
    }
    function setDefaultInput(input) {
        if (input)
            Pipewire.preferredDefaultAudioSource = input
    }
    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
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
            spacing: 10

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "SOUND"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.Normal
                }

                Text {
                    text: "Output, input and per-application volume"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#383838"
            }

            Rectangle {
                id: outputRow
                property bool hovered: false
                width: parent.width
                height: 50
                radius: 8
                color: hovered ? Theme.alpha(Theme.text, 0.055) : Theme.alpha(Theme.text, 0.012)
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.12)

                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.alpha(Theme.text, 0.025)
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.12)

                        Text {
                            anchors.centerIn: parent
                            text: page.muted ? "\uf026" : "\uf028"
                            color: page.muted ? Theme.textFaint : Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (page.sink?.audio)
                                    page.sink.audio.muted = !page.sink.audio.muted
                            }
                        }
                    }

                    Column {
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            width: parent.width
                            text: "Output volume"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: page.muted ? "Muted" : Math.round(page.volume * 100) + "%"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Slider {
                        width: Math.max(60, outputRow.width - 158)
                        height: 35
                        anchors.verticalCenter: parent.verticalCenter
                        label: ""
                        icon: ""
                        value: page.muted ? 0 : page.volume
                        onMoved: v => {
                            if (page.sink?.audio) {
                                page.sink.audio.muted = false
                                page.sink.audio.volume = v
                            }
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: outputRow.hovered = hovered
                }
            }

            Column {
                width: parent.width
                spacing: 5

                Repeater {
                    model: page.outputSinks

                    delegate: Rectangle {
                        id: outputCard
                        property bool hovered: false
                        required property var modelData
                        property var output: modelData
                        property bool active: page.sink?.id === output?.id

                        width: parent.width
                        height: 46
                        radius: 8
                        color: active ? Theme.alpha(Theme.text, 0.055) : (hovered ? Theme.alpha(Theme.text, 0.035) : Theme.alpha(Theme.text, 0.012))
                        border.width: 1
                        border.color: active ? Theme.alpha(Theme.text, 0.32) : Theme.alpha(Theme.text, 0.12)

                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 9

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.alpha(Theme.text, 0.025)
                                border.width: 1
                                border.color: Theme.alpha(Theme.text, 0.12)

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf028"
                                    color: outputCard.active ? Theme.accent : Theme.textDim
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                }
                            }

                            Column {
                                width: parent.width - 39
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: page.displayName(output, "Unknown output")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: outputCard.active ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: outputCard.active ? "Default output" : "Audio output"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: outputCard.hovered = true
                            onExited: outputCard.hovered = false
                            onClicked: page.setDefaultOutput(output)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 8
                    visible: page.outputSinks.length === 0
                    color: Theme.alpha(Theme.text, 0.015)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.12)

                    Row {
                        anchors.centerIn: parent
                        spacing: 9

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.text, 0.025)
                            border.width: 1
                            border.color: Theme.alpha(Theme.text, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf028"
                                color: Theme.textFaint
                                font.family: Theme.iconFont
                                font.pixelSize: 16
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                text: "No sound outputs"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "Connect or enable an output device"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 14

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#383838"
                    anchors.centerIn: parent
                }
            }

            Rectangle {
                id: inputRow
                property bool hovered: false
                width: parent.width
                height: 50
                radius: 8
                color: hovered ? Theme.alpha(Theme.text, 0.055) : Theme.alpha(Theme.text, 0.012)
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.12)

                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.alpha(Theme.text, 0.025)
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.12)

                        Text {
                            anchors.centerIn: parent
                            text: page.inputMuted ? "\uf131" : "\uf130"
                            color: page.inputMuted ? Theme.textFaint : Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (page.source?.audio)
                                    page.source.audio.muted = !page.source.audio.muted
                            }
                        }
                    }

                    Column {
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            width: parent.width
                            text: "Input volume"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: page.inputMuted ? "Muted" : Math.round(page.inputVolume * 100) + "%"
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Slider {
                        width: Math.max(60, inputRow.width - 158)
                        height: 35
                        anchors.verticalCenter: parent.verticalCenter
                        label: ""
                        icon: ""
                        value: page.inputMuted ? 0 : page.inputVolume
                        onMoved: v => {
                            const audio = page.source?.audio
                            if (!audio)
                                return
                            audio.muted = false
                            audio.volume = v
                        }
                        onCommitted: v => {
                            const audio = page.source?.audio
                            if (!audio)
                                return
                            audio.muted = false
                            audio.volume = v
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: inputRow.hovered = hovered
                }
            }

            Column {
                width: parent.width
                spacing: 5

                Repeater {
                    model: page.inputSources

                    delegate: Rectangle {
                        id: inputCard
                        property bool hovered: false
                        required property var modelData
                        property var input: modelData
                        property bool active: page.source?.id === input?.id

                        width: parent.width
                        height: 46
                        radius: 8
                        color: active ? Theme.alpha(Theme.text, 0.055) : (hovered ? Theme.alpha(Theme.text, 0.035) : Theme.alpha(Theme.text, 0.012))
                        border.width: 1
                        border.color: active ? Theme.alpha(Theme.text, 0.32) : Theme.alpha(Theme.text, 0.12)

                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 9

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.alpha(Theme.text, 0.025)
                                border.width: 1
                                border.color: Theme.alpha(Theme.text, 0.12)

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf130"
                                    color: inputCard.active ? Theme.accent : Theme.textDim
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                }
                            }

                            Column {
                                width: parent.width - 39
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: page.displayName(input, "Unknown input")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: inputCard.active ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: inputCard.active ? "Default input" : "Audio input"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: inputCard.hovered = true
                            onExited: inputCard.hovered = false
                            onClicked: page.setDefaultInput(input)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 8
                    visible: page.inputSources.length === 0
                    color: Theme.alpha(Theme.text, 0.015)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.12)

                    Row {
                        anchors.centerIn: parent
                        spacing: 9

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.text, 0.025)
                            border.width: 1
                            border.color: Theme.alpha(Theme.text, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf130"
                                color: Theme.textFaint
                                font.family: Theme.iconFont
                                font.pixelSize: 16
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                text: "No sound inputs"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "Connect or enable an input device"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
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

            Row {
                width: parent.width
                spacing: 9

                Text {
                    id: appVolumeLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PER-APP VOLUME"
                    color: Theme.textDim
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                }

                Item {
                    width: Math.max(0, parent.width - appVolumeLabel.implicitWidth - streamCountBadge.width - 16)
                    height: 1
                }

                Rectangle {
                    id: streamCountBadge
                    width: Math.max(26, streamCountText.implicitWidth + 14)
                    height: 24
                    radius: 6
                    color: Theme.alpha(Theme.text, 0.025)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.12)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: streamCountText
                        anchors.centerIn: parent
                        text: page.appStreams.length
                        color: Theme.textFaint
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 5

                Repeater {
                    model: page.appStreams

                    delegate: Rectangle {
                        id: appCard
                        required property var modelData
                        property var stream: modelData
                        property bool hovered: false
                        property bool streamMuted: stream?.audio?.muted ?? false
                        property real streamVolume: stream?.audio?.volume ?? 0

                        width: parent.width
                        height: 48
                        radius: 8
                        color: streamMuted ? Theme.alpha(Theme.danger, 0.045) : (hovered ? Theme.alpha(Theme.text, 0.035) : Theme.alpha(Theme.text, 0.012))
                        border.width: 1
                        border.color: streamMuted ? Theme.alpha(Theme.danger, 0.45) : Theme.alpha(Theme.text, 0.12)

                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        Row {
                            id: appRow
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 9

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: streamMuted ? Theme.alpha(Theme.danger, 0.055) : Theme.alpha(Theme.text, 0.025)
                                border.width: 1
                                border.color: streamMuted ? Theme.alpha(Theme.danger, 0.35) : "#393939"

                                Text {
                                    anchors.centerIn: parent
                                    text: streamMuted ? "\uf026" : "\uf028"
                                    color: streamMuted ? Theme.danger : Theme.text
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (stream?.audio)
                                            stream.audio.muted = !stream.audio.muted
                                    }
                                }
                            }

                            Column {
                                width: 96
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: page.displayName(stream, "Unknown app")
                                    color: streamMuted ? Theme.textDim : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: streamMuted ? "Muted" : Math.round(streamVolume * 100) + "% volume"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            Slider {
                                width: Math.max(50, appRow.width - 144)
                                height: 35
                                anchors.verticalCenter: parent.verticalCenter
                                label: ""
                                icon: ""
                                value: streamMuted ? 0 : streamVolume
                                onMoved: v => {
                                    if (stream?.audio) {
                                        stream.audio.muted = false
                                        stream.audio.volume = v
                                    }
                                }
                                onCommitted: v => {
                                    if (stream?.audio) {
                                        stream.audio.muted = false
                                        stream.audio.volume = v
                                    }
                                }
                            }
                        }

                        HoverHandler {
                            onHoveredChanged: appCard.hovered = hovered
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: 8
                    visible: page.appStreams.length === 0
                    color: Theme.alpha(Theme.text, 0.015)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.12)

                    Row {
                        anchors.centerIn: parent
                        spacing: 9

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.text, 0.025)
                            border.width: 1
                            border.color: Theme.alpha(Theme.text, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf028"
                                color: Theme.textFaint
                                font.family: Theme.iconFont
                                font.pixelSize: 14
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                text: "No active audio streams"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "Applications will appear here when they play audio"
                                color: Theme.textFaint
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
