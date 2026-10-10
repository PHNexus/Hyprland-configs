import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? backdrop : null
    }

    property bool showing: false
    property string uiFontFamily: "Noto Sans"

    function show() { showing = true }
    function hide() { showing = false }
    function toggle() { showing = !showing }

    function nextPage() {
        selectedIndex = (selectedIndex + 1) % navItems.length
    }

    function prevPage() {
        selectedIndex =
            (selectedIndex - 1 + navItems.length) % navItems.length
    }

    onShowingChanged: {
        if (!showing)
            dragging = false
    }

    property real cardMargin: 40
    property real dragMargin: 8
    property bool dragging: false

    property real cardHeightCenter:
        Math.max(1, Math.min(640, root.height - cardMargin * 2))

    property real cardHeightSnapped: cardHeightCenter * 0.6
    property real cardHeight: cardHeightCenter
    property real cardCenterY: (root.height - cardHeight) / 2
    property real cardY: cardCenterY

    property real cardWidthCenter:
        Math.max(1, Math.min(980, root.width - cardMargin * 2))

    property real cardWidthSnapped: cardWidthCenter * 0.85
    property real cardHeightSideSnapped: cardHeightCenter * 1.4
    property real cardWidth: cardWidthCenter
    property real cardCenterX: (root.width - cardWidth) / 2
    property real cardX: cardCenterX

    property string snapPosition: "center"

    property real freeX: 0
    property real freeY: 0
    property real freeW: 0
    property real freeH: 0

    readonly property string statePath:
        Quickshell.env("HOME")
        + "/.config/quickshell/state/settings-state.json"

    function saveState() {
        stateFile.setText(JSON.stringify({
            snap: root.snapPosition,
            x: root.freeX,
            y: root.freeY,
            w: root.freeW,
            h: root.freeH
        }))
    }

    function clampX(v) {
        return Math.max(
            dragMargin,
            Math.min(root.width - cardWidth - dragMargin, v)
        )
    }

    function clampY(v) {
        return Math.max(
            dragMargin,
            Math.min(root.height - cardHeight - dragMargin, v)
        )
    }

    function applySnap(pos) {
        switch (pos) {
        case "top":
            cardWidth = cardWidthCenter
            cardHeight = cardHeightSnapped
            cardX = (root.width - cardWidth) / 2
            cardY = cardMargin
            break

        case "bottom":
            cardWidth = cardWidthCenter
            cardHeight = cardHeightSnapped
            cardX = (root.width - cardWidth) / 2
            cardY = root.height - cardHeight - cardMargin
            break

        case "left":
            cardWidth = cardWidthSnapped
            cardHeight = Math.min(
                cardHeightSideSnapped,
                root.height - dragMargin * 2
            )
            cardX = cardMargin
            cardY = (root.height - cardHeight) / 2
            break

        case "right":
            cardWidth = cardWidthSnapped
            cardHeight = Math.min(
                cardHeightSideSnapped,
                root.height - dragMargin * 2
            )
            cardX = root.width - cardWidth - cardMargin
            cardY = (root.height - cardHeight) / 2
            break

        case "free":
            cardWidth = Math.min(
                freeW > 0 ? freeW : cardWidthCenter,
                root.width - dragMargin * 2
            )
            cardHeight = Math.min(
                freeH > 0 ? freeH : cardHeightCenter,
                root.height - dragMargin * 2
            )
            cardX = clampX(freeX)
            cardY = clampY(freeY)
            break

        default:
            cardHeight = cardHeightCenter
            cardWidth = cardWidthCenter
            cardY = (root.height - cardHeight) / 2
            cardX = (root.width - cardWidth) / 2
        }
    }

    function snapTo(pos) {
        root.snapPosition = pos
        root.applySnap(pos)
        root.saveState()
    }

    function snapTop() { snapTo("top") }
    function snapBottom() { snapTo("bottom") }
    function snapLeft() { snapTo("left") }
    function snapRight() { snapTo("right") }
    function snapCenter() { snapTo("center") }

    function finishDrag() {
        root.dragging = false
        root.snapPosition = "free"
        root.freeX = root.cardX
        root.freeY = root.cardY
        root.freeW = root.cardWidth
        root.freeH = root.cardHeight
        root.saveState()
    }

    onWidthChanged: {
        if (width > 0 && height > 0)
            applySnap(snapPosition)
    }

    onHeightChanged: {
        if (width > 0 && height > 0)
            applySnap(snapPosition)
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())

                if (["center", "top", "bottom", "left", "right", "free"]
                    .indexOf(s.snap) >= 0) {

                    if (typeof s.x === "number") root.freeX = s.x
                    if (typeof s.y === "number") root.freeY = s.y
                    if (typeof s.w === "number") root.freeW = s.w
                    if (typeof s.h === "number") root.freeH = s.h

                    root.snapPosition = s.snap

                    if (root.width > 0 && root.height > 0)
                        root.applySnap(s.snap)
                }
            } catch (e) {
                console.warn(
                    "settings: could not read saved state:", e
                )
            }
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }

        function sound(): void {
            root.selectedIndex = 0
            root.show()
        }

        function audio(): void {
            root.selectedIndex = 0
            root.show()
        }

        function display(): void {
            root.selectedIndex = 1
            root.show()
        }

        function network(): void {
            root.selectedIndex = 2
            root.show()
        }

        function bluetooth(): void {
            root.selectedIndex = 3
            root.show()
        }

        function storage(): void {
            root.selectedIndex = 4
            root.show()
        }

        function power(): void {
            root.selectedIndex = 5
            root.show()
        }

        function configs(): void {
            root.selectedIndex = 6
            root.show()
        }

        function snapTop(): void { root.snapTop() }
        function snapCenter(): void { root.snapCenter() }
        function snapBottom(): void { root.snapBottom() }
        function snapLeft(): void { root.snapLeft() }
        function snapRight(): void { root.snapRight() }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property var sink: Pipewire.defaultAudioSink
    property real pwVolume:
        (sink && sink.audio) ? sink.audio.volume : 0
    property bool pwMuted:
        (sink && sink.audio) ? sink.audio.muted : false

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        focus: root.showing

        Keys.onEscapePressed: root.hide()

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Backtab ||
                (event.key === Qt.Key_Tab &&
                 (event.modifiers & Qt.ShiftModifier))) {
                root.prevPage()
                event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
                root.nextPage()
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    property var navItems: [
        { name: "Audio", icon: "\uf028", page: "Audio" },
        { name: "Display", icon: "\uf108", page: "Display" },
        { name: "Network", icon: "\uf1eb", page: "Network" },
        { name: "Bluetooth", icon: "󰂯", page: "Bluetooth" },
        { name: "Storage", icon: "󰋊", page: "Storage" },
        { name: "Power", icon: "󰐥", page: "Power" },
        { name: "Configs", icon: "󰧮", page: "Configs" }
    ]

    property int selectedIndex: 0

    Rectangle {
        id: card

        x: root.cardX
        y: root.cardY
        width: root.cardWidth
        height: root.cardHeight

        color: Theme.bg
        radius: Theme.radius
        border.color: Theme.accent
        border.width: 0
        clip: true

        opacity: root.showing ? 1 : 0
        visible: root.showing

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        Behavior on x {
            enabled: !root.dragging
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            enabled: !root.dragging
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.animMed
                easing.type: Easing.OutCubic
            }
        }

        // Top-left and bottom-right corner accents
        Rectangle {
            width: 0
            height: 0
            color: Theme.accent2

            anchors {
                top: parent.top
                left: parent.left
                margins: 0
            }
        }

        Rectangle {
            width: 0
            height: 0
            color: Theme.accent2

            anchors {
                top: parent.top
                left: parent.left
                margins: 14
            }
        }

        Rectangle {
            width: 0
            height: 0
            color: Theme.accent2

            anchors {
                bottom: parent.bottom
                right: parent.right
                margins: 14
            }
        }

        Rectangle {
            width: 0
            height: 0
            color: Theme.accent2

            anchors {
                bottom: parent.bottom
                right: parent.right
                margins: 14
            }
        }

        // Window positioning handle
        Item {
            id: positionHandle

            width: 140
            height: 9

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            HoverHandler {
                id: handleHover
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: tabPath

                    property real w: positionHandle.width
                    property real h: positionHandle.height
                    property real r: 6
                    property real fx: 30
                    property real fy: 0

                    // Keep the drag handle invisible: no outline is drawn.
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap

                    startX: 0.5 - fx
                    startY: 0.5

                    PathArc {
                        x: 0.5
                        y: tabPath.fy + 0.5
                        radiusX: tabPath.fx
                        radiusY: tabPath.fy
                        direction: PathArc.Clockwise
                    }

                    PathLine {
                        x: 0.5
                        y: tabPath.h - tabPath.r
                    }

                    PathArc {
                        x: tabPath.r + 0.5
                        y: tabPath.h - 0.5
                        radiusX: tabPath.r
                        radiusY: tabPath.r
                        direction: PathArc.Counterclockwise
                    }

                    PathLine {
                        x: tabPath.w - tabPath.r - 0.5
                        y: tabPath.h - 0.5
                    }

                    PathArc {
                        x: tabPath.w - 0.5
                        y: tabPath.h - tabPath.r
                        radiusX: tabPath.r
                        radiusY: tabPath.r
                        direction: PathArc.Counterclockwise
                    }

                    PathLine {
                        x: tabPath.w - 0.5
                        y: tabPath.fy + 0.5
                    }

                    PathArc {
                        x: tabPath.w - 0.5 + tabPath.fx
                        y: 0.5
                        radiusX: tabPath.fx
                        radiusY: tabPath.fy
                        direction: PathArc.Clockwise
                    }
                }
            }

            MouseArea {
                id: dragArea

                anchors.fill: parent
                anchors.bottomMargin: -6
                acceptedButtons: Qt.LeftButton
                cursorShape: root.dragging
                    ? Qt.ClosedHandCursor
                    : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0
                property real startX: 0
                property real startY: 0
                property bool moved: false

                onPressed: function(mouse) {
                    var p = dragArea.mapToItem(
                        backdrop, mouse.x, mouse.y
                    )

                    pressX = p.x
                    pressY = p.y
                    startX = root.cardX
                    startY = root.cardY
                    moved = false
                    root.dragging = true
                }

                onPositionChanged: function(mouse) {
                    if (!root.dragging)
                        return

                    var p = dragArea.mapToItem(
                        backdrop, mouse.x, mouse.y
                    )

                    moved = true
                    root.cardX = root.clampX(
                        startX + (p.x - pressX)
                    )
                    root.cardY = root.clampY(
                        startY + (p.y - pressY)
                    )
                }

                onReleased: {
                    if (!root.dragging)
                        return

                    if (moved)
                        root.finishDrag()
                    else
                        root.dragging = false
                }

                onCanceled: {
                    if (!root.dragging)
                        return

                    if (moved)
                        root.finishDrag()
                    else
                        root.dragging = false
                }

                onDoubleClicked: root.snapCenter()
            }
        }

        // Bottom positioning controls without individual borders
        Row {
            id: positioningControls

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 12
            }

            spacing: 20
            z: 30

            Repeater {
                model: [
                    { symbol: "◀", action: "left", size: 25 },
                    { symbol: "▲", action: "top", size: 25 },
                    { symbol: "●", action: "center", size: 25 },
                    { symbol: "▼", action: "bottom", size: 25 },
                    { symbol: "▶", action: "right", size: 25 }
                ]

                delegate: Text {
                    required property var modelData

                    text: modelData.symbol
                    font.family: root.uiFontFamily
                    font.pixelSize: modelData.size
                    color: Theme.textDim
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            switch (modelData.action) {
                            case "left":
                                root.snapLeft()
                                break
                            case "top":
                                root.snapTop()
                                break
                            case "center":
                                root.snapCenter()
                                break
                            case "bottom":
                                root.snapBottom()
                                break
                            case "right":
                                root.snapRight()
                                break
                            }
                        }
                    }
                }
            }
        }

        // Settings content
        Column {
            id: settingsContent

            anchors.fill: parent
            anchors.margins: 28
            anchors.bottomMargin: 54
            spacing: 16

            Row {
                width: parent.width
                height: 24
                spacing: 10

                Text {
                    text: "SETTINGS"
                    color: Theme.text
                    font.family: root.uiFontFamily
                    font.pixelSize: 19
                    font.bold: true
                    font.letterSpacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Browser-style horizontal tabs
            Flickable {
                id: tabsFlickable

                width: parent.width
                height: 38
                contentWidth: tabsRow.width
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width

                Row {
                    id: tabsRow

                    height: tabsFlickable.height
                    spacing: 6

                    Repeater {
                        model: root.navItems

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: 100
                            height: 36
                            radius: Theme.radius

                            color: root.selectedIndex === index
                                ? Theme.alpha(Theme.accent, 0.12)
                                : "transparent"

                            border.width:
                                root.selectedIndex === index ? 1 : 0
                            border.color: Theme.accent

                            Row {
                                anchors.centerIn: parent
                                spacing: 7

                                Text {
                                    text: modelData.icon
                                    color: root.selectedIndex === index
                                        ? Theme.text
                                        : Theme.textDim

                                    font.family: Theme.iconFont
                                    font.pixelSize: 14

                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                }

                                Text {
                                    text: modelData.name
                                    color: root.selectedIndex === index
                                        ? Theme.text
                                        : Theme.textDim

                                    font.family: root.uiFontFamily
                                    font.pixelSize: 12

                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedIndex = index
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Item {
                width: parent.width
                height: Math.max(
                    0,
                    parent.height
                    - 24
                    - 38
                    - 1
                    - parent.spacing * 3
                )

                clip: true

                Loader {
                    id: pageLoader

                    anchors.fill: parent

                    source: "Tabs/"
                        + root.navItems[root.selectedIndex].page
                        + ".qml"

                    opacity: 1

                    onSourceChanged: fadeIn.restart()

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animMed
                        }
                    }

                    SequentialAnimation {
                        id: fadeIn

                        PropertyAction {
                            target: pageLoader
                            property: "opacity"
                            value: 0
                        }

                        NumberAnimation {
                            target: pageLoader
                            property: "opacity"
                            to: 1
                            duration: Theme.animMed
                        }
                    }
                }
            }
        }
    }
}