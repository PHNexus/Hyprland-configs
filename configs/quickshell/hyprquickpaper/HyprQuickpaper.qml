import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Qt.labs.folderlistmodel

PanelWindow {
    id: root

    property bool pickerOpen: false
    property string selectedWallpaperPath: ""
    property bool mouseMode: true
    property int imageHeight: 450
    property int inactiveImageHeight: 350

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: pickerOpen
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: pickerOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    function resolvePath(path) {
        var value = String(path || "").trim()
        value = value.replace(/\$(\w+)/g, function(match, variableName) {
            return Quickshell.env(variableName) || ""
        })
        if (value.startsWith("~"))
            value = (Quickshell.env("HOME") || "") + value.substring(1)
        return value
    }

    function folderUrl(path) {
        var value = resolvePath(path)
        if (value.length === 0)
            return "file:///"
        if (value.startsWith("file://"))
            return value
        return "file://" + value
    }

    function cachedFileUrl(fileName) {
        var base = resolvePath(config.cache_path)
        if (base.length === 0)
            return ""
        if (!base.endsWith("/"))
            base += "/"
        if (base.startsWith("file://"))
            return base + fileName
        return "file://" + base + fileName
    }

    // Resolve the original file URL through FolderListModel instead of
    // relying on model roles inside the delegate. fileUrl is the current Qt role;
    // fileURL is retained for compatibility with older versions.
    function originalFileUrl(index) {
        if (index < 0 || index >= wallpapers.count)
            return ""

        var url = wallpapers.get(index, "fileUrl")
        if (!url)
            url = wallpapers.get(index, "fileURL")
        if (url)
            return String(url)

        var path = wallpapers.get(index, "filePath")
        if (!path)
            return ""

        path = String(path)
        if (path.startsWith("file://"))
            return path
        return "file://" + path
    }

    // Calculate the scroll limit from the delegate count, even when
    // the last delegate has not yet been instantiated by the ListView.
    function clampX(x) {
        var total = wallpapers.count
        var tile = list.tileWidth
        var gap = list.spacing

        if (total <= 0 || tile <= 0)
            return 0

        var totalContentWidth = total * tile + Math.max(0, total - 1) * gap
        var maxX = Math.max(0, totalContentWidth - list.width)
        return Math.max(0, Math.min(x, maxX))
    }

    function selectIndex(index, keepVisible) {
        if (wallpapers.count <= 0)
            return

        var nextIndex = Math.max(0, Math.min(index, wallpapers.count - 1))
        if (nextIndex === list.selectedIndex)
            return

        list.previousSelectedIndex = list.selectedIndex
        list.selectedIndex = nextIndex

        // Only keyboard navigation automatically moves the list.
        // Selecting a wallpaper with the mouse does not force the scroll to follow it.
        if (keepVisible === true)
            ensureVisibleAnimated(nextIndex)
    }

    function keyboardSelect(direction) {
        mouseMode = false
        list.keyboardMode = true
        selectIndex(list.selectedIndex + direction, true)
    }

    function ensureVisibleAnimated(index) {
        if (index < 0 || index >= wallpapers.count || list.width <= 0)
            return

        var stride = list.tileWidth + list.spacing
        var expandedWidth = list.tileWidth * 1.50 + 40
        var extraWidth = Math.max(0, expandedWidth - list.tileWidth) / 2
        var itemStart = index * stride - extraWidth
        var itemEnd = index * stride + list.tileWidth + extraWidth
        // Compare against the desired endpoint, not the intermediate frame.
        // This stays correct when multiple keys arrive during the animation.
        var target = list.wheelTargetX

        if (index === 0) {
            target = 0
        } else if (itemStart < target) {
            target = itemStart
        } else if (itemEnd > target + list.width) {
            target = itemEnd - list.width
        }

        target = clampX(target)
        list.wheelTargetX = target
        list.contentX = target
    }

    function activateCurrent() {
        if (wallpapers.count <= 0 || list.selectedIndex < 0)
            return

        var path = wallpapers.get(list.selectedIndex, "filePath")
        if (!path || String(path).length === 0) {
            console.warn("HyprQuickpaper: caminho do wallpaper vazio para o índice", list.selectedIndex)
            return
        }

        selectedWallpaperPath = String(path)

        // Run detached so the Wofi monitor selector remains open
        // even after the wallpaper panel is hidden.
        Quickshell.execDetached({
            command: [
                "bash",
                Quickshell.shellPath("hyprquickpaper/commands.sh"),
                selectedWallpaperPath
            ],
            workingDirectory: Quickshell.shellPath("hyprquickpaper")
        })

        closePicker()
    }

    function showPicker() {
        pickerOpen = true
        if (wallpapers.count > 0 && list.selectedIndex < 0)
            list.selectedIndex = 0

        Qt.callLater(function() {
            keyHandler.forceActiveFocus()
            wheelTargetReset()
            if (list.selectedIndex >= 0)
                ensureVisibleAnimated(list.selectedIndex)
        })
    }

    function hidePicker() {
        pickerOpen = false
        list.stopScrollAnimation()
    }

    function closePicker() {
        hidePicker()
    }

    function wheelTargetReset() {
        list.wheelTargetX = list.contentX
    }

    Component.onCompleted: {
        Quickshell.execDetached({
            command: [
                "bash",
                Quickshell.shellPath("hyprquickpaper/cache.sh"),
                Quickshell.shellPath("hyprquickpaper")
            ],
            workingDirectory: Quickshell.shellPath("hyprquickpaper")
        })
    }

    IpcHandler {
        target: "hyprquickpaper"

        function toggle() {
            if (root.pickerOpen)
                root.hidePicker()
            else
                root.showPicker()
        }

        function show() {
            root.showPicker()
        }

        function hide() {
            root.hidePicker()
        }
    }

    FileView {
        id: configFile
        path: Quickshell.shellPath("hyprquickpaper/config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: config
            property string wallpaper_path: ""
            property string cache_path: ""
            property int number_of_pictures: 5
            property string border_color: "#89b4fa"
        }
    }

    FolderListModel {
        id: wallpapers
        folder: root.folderUrl(config.wallpaper_path)
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        sortReversed: false
        nameFilters: [
            "*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif",
            "*.PNG", "*.JPG", "*.JPEG", "*.WEBP", "*.BMP", "*.GIF"
        ]

        onCountChanged: {
            if (count <= 0) {
                list.selectedIndex = -1
                list.previousSelectedIndex = -1
                list.contentX = 0
                list.wheelTargetX = 0
            } else if (list.selectedIndex < 0 || list.selectedIndex >= count) {
                list.selectedIndex = 0
                list.previousSelectedIndex = 0
                root.ensureVisibleAnimated(0)
            }
        }
    }

    Rectangle {
        id: dimBackground
        anchors.fill: parent
        color: "transparent"
        visible: root.pickerOpen
        z: 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: root.closePicker()
            onWheel: function(wheel) {
                wheel.accepted = true
            }
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        z: 1
        focus: root.pickerOpen

        Keys.onPressed: function(event) {
            if (!root.pickerOpen)
                return

            if (event.key === Qt.Key_Escape) {
                root.closePicker()
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                root.keyboardSelect(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.keyboardSelect(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.keyboardSelect(-Math.max(1, Number(config.number_of_pictures) || 5))
                event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.keyboardSelect(Math.max(1, Number(config.number_of_pictures) || 5))
                event.accepted = true
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                       || event.key === Qt.Key_Enter) {
                root.activateCurrent()
                event.accepted = true
            }
        }
    }

    HoverHandler {
        id: mouseMovementHandler
        property point lastPosition: point.position

        onPointChanged: {
            if (point.position.x === lastPosition.x && point.position.y === lastPosition.y)
                return

            lastPosition = point.position
            root.mouseMode = true
            list.mouseEnabled = true
            list.keyboardMode = false
        }
    }

    Item {
        id: main
        anchors.fill: parent
        z: 2
        visible: root.pickerOpen
        property int imageHeight: root.imageHeight
        property int inactiveImageHeight: root.inactiveImageHeight

        ListView {
            id: list
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: main.imageHeight
            z: 1
            focus: root.pickerOpen
            model: wallpapers
            orientation: ListView.Horizontal
            spacing: 0
            clip: true
            cacheBuffer: width * 4
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            highlightMoveDuration: 0

            property int selectedIndex: -1
            property int previousSelectedIndex: -1
            property bool keyboardMode: false
            property bool mouseEnabled: false
            property real tileWidth: {
                var visibleCount = Math.max(1, Number(config.number_of_pictures) || 5)
                return Math.max(1, width / visibleCount - 10)
            }
            property real wheelTargetX: 0

            function selectIndex(index) {
                root.selectIndex(index)
            }

            function stopScrollAnimation() {
                contentXSmoothing.stop()
                wheelTargetX = contentX
            }

            onWidthChanged: {
                wheelTargetX = root.clampX(wheelTargetX)
                contentX = wheelTargetX
            }

            // Follow target changes without restarting a fixed animation
            // on every wheel event. This keeps the scrolling speed continuous.
            Behavior on contentX {
                SmoothedAnimation {
                    id: contentXSmoothing
                    velocity: 750
                    maximumEasingTime: -1
                    onFinished: list.wheelTargetX = list.contentX
                }
            }

            Timer {
                id: cacheRetryTimer
                interval: 2000
                repeat: true
                running: root.pickerOpen
                onTriggered: {
                    for (var i = 0; i < list.count; i++) {
                        var item = list.itemAtIndex(i)
                        if (item)
                            item.retryImage()
                    }
                }
            }

            delegate: Item {
                id: delegateItem
                required property int index

                property bool active: index === list.selectedIndex
                property string wallpaperUrl: root.originalFileUrl(index)
                property string wallpaperPath: String(wallpapers.get(index, "filePath") || "")
                property string wallpaperFileName: String(wallpapers.get(index, "fileName") || "")
                property string thumbnailUrl: root.cachedFileUrl(wallpaperFileName)
                property real entranceOffset: 25
                property bool triedOriginalImage: false

                function retryImage() {
                    if (img.status !== Image.Error)
                        return false

                    if (!triedOriginalImage && wallpaperUrl.length > 0) {
                        triedOriginalImage = true
                        img.source = wallpaperUrl
                        return true
                    }

                    var sourcePath = triedOriginalImage ? wallpaperUrl : thumbnailUrl
                    img.source = ""
                    img.source = sourcePath
                    return true
                }

                // Restart the animation every time the picker opens,
                // not only when the delegate is first created.
                function playEntrance() {
                    entranceTimer.stop()
                    entranceAnimation.stop()
                    opacity = 0
                    entranceOffset = 35

                    if (index < 15) {
                        entranceTimer.start()
                    } else {
                        opacity = 1
                        entranceOffset = 0
                    }
                }

                width: list.tileWidth
                height: main.imageHeight
                z: {
                    if (index === list.selectedIndex)
                        return 10
                    if (index === list.previousSelectedIndex)
                        return 9
                    return 0
                }
                opacity: 0

                Item {
                    id: wallpaperItem
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    width: delegateItem.active ? list.tileWidth * 1.50 + 40 : list.tileWidth
                    height: delegateItem.active ? main.imageHeight : main.inactiveImageHeight
                    transform: Translate {
                        y: delegateItem.entranceOffset
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: 1000
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 1000
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: alt
                        visible: img.status === Image.Error
                        text: "Caching"
                        color: config.border_color
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        transform: Shear {
                            xFactor: -0.25
                        }
                    }

                    Image {
                        id: img
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        mipmap: true
                        source: delegateItem.thumbnailUrl.length > 0
                            ? delegateItem.thumbnailUrl
                            : delegateItem.wallpaperUrl
                        sourceSize.width: list.tileWidth * 1.50 + 40
                        sourceSize.height: main.imageHeight
                        transform: Shear {
                            xFactor: -0.25
                        }

                        onStatusChanged: {
                            if (status !== Image.Error)
                                return

                            if (!delegateItem.triedOriginalImage && delegateItem.wallpaperUrl.length > 0) {
                                delegateItem.triedOriginalImage = true
                                source = delegateItem.wallpaperUrl
                                return
                            }

                            console.warn("HyprQuickpaper: falha ao carregar imagem:",
                                         delegateItem.wallpaperFileName,
                                         "thumbnail:", delegateItem.thumbnailUrl,
                                         "original:", delegateItem.wallpaperUrl)
                        }
                    }

                    Rectangle {
                        id: border
                        anchors.fill: parent
                        z: 10
                        color: "transparent"
                        border.width: 2
                        border.color: config.border_color || "#89b4fa"
                        radius: 4
                        opacity: delegateItem.active ? 1 : 0
                        transform: Shear {
                            xFactor: -0.25
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 500
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                MouseArea {
                    id: hitArea
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    width: wallpaperItem.width
                    height: wallpaperItem.height
                    z: 20
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    transform: Shear {
                        xFactor: -0.25
                    }

                    Timer {
                        id: hoverTimer
                        interval: 30
                        repeat: false
                        onTriggered: {
                            if (!list.keyboardMode)
                                root.selectIndex(index)
                        }
                    }

                    onEntered: {
                        root.mouseMode = true
                        if (!list.keyboardMode && list.mouseEnabled)
                            hoverTimer.start()
                    }

                    onExited: hoverTimer.stop()

                    onClicked: {
                        hoverTimer.stop()
                        list.keyboardMode = false
                        root.selectIndex(index)
                        root.activateCurrent()
                    }

                    onWheel: function(wheel) {
                        hoverTimer.stop()
                        root.mouseMode = true
                        list.keyboardMode = false

                        var delta = wheel.angleDelta.y !== 0
                            ? wheel.angleDelta.y
                            : wheel.angleDelta.x

                        list.wheelTargetX = root.clampX(list.wheelTargetX - delta * 0.8)
                        list.contentX = list.wheelTargetX
                        wheel.accepted = true
                    }
                }

                Component.onCompleted: {
                    if (root.pickerOpen) {
                        playEntrance()
                    } else {
                        delegateItem.opacity = 1
                        delegateItem.entranceOffset = 0
                    }
                }

                Timer {
                    id: entranceTimer
                    interval: index * 30
                    repeat: false
                    onTriggered: entranceAnimation.start()
                }

                ParallelAnimation {
                    id: entranceAnimation

                    NumberAnimation {
                        target: delegateItem
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 220
                        easing.type: Easing.OutExpo
                    }

                    NumberAnimation {
                        target: delegateItem
                        property: "entranceOffset"
                        from: 35
                        to: 0
                        duration: 220
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: wallpapers.count === 0
            text: config.wallpaper_path.length === 0
                ? "Configure wallpaper_path em hyprquickpaper/config.json"
                : "Nenhum papel de parede encontrado"
            color: "white"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            width: Math.min(parent.width - 80, 600)
        }
    }

    onPickerOpenChanged: {
        if (pickerOpen) {
            if (wallpapers.count > 0 && list.selectedIndex < 0)
                list.selectedIndex = 0

            Qt.callLater(function() {
                keyHandler.forceActiveFocus()
                wheelTargetReset()
                if (list.selectedIndex >= 0)
                    ensureVisibleAnimated(list.selectedIndex)

                // Restart the fade + slide animation for already-loaded delegates.
                for (var i = 0; i < wallpapers.count; i++) {
                    var item = list.itemAtIndex(i)
                    if (item)
                        item.playEntrance()
                }
            })
        } else {
            cacheRetryTimer.stop()
            list.stopScrollAnimation()
        }
    }
}
