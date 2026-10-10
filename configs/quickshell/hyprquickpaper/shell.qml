/*
 * HyprQuickPaper — Scrolling and Hover Regression Notes
 *
 * Background, diagnostic excerpts, and the fixes documented here:
 *   docs/debugging/README.md
 *
 * Diagnostic log excerpts captured while investigating the issues:
 *   docs/debugging/logs/scroll-origin-before-fix.log
 *   docs/debugging/logs/hover-input-before-fix.log
 *   docs/debugging/logs/wheel-hover-before-fix.log
 *
 * Fix summary:
 *   1. Use ListView.originX as the minimum horizontal scroll position,
 *      and calculate the maximum relative to that origin.
 *   2. Do not ignore real pointer movement solely because HoverHandler.active
 *      is false; restore mouse mode and re-check the hovered delegate.
 *   3. Keep wheel scrolling in mouse mode instead of disabling hover input.
 *   4. During wheel animation, ignore MouseArea.onEntered transitions caused
 *      by delegates moving beneath a stationary pointer. Cancel pending hover
 *      timers at wheel start; let actual pointer movement re-evaluate hover.
 *
 * Animation settings intentionally preserved in this configuration:
 *   - Keyboard scrolling: 1000 ms
 *   - Wheel scrolling: 750 ms
 *   - Wallpaper size and border opacity transitions: 500 ms
 *
 * These changes were tested in one customized Quickshell setup. Other versions
 * may need adaptation. Diagnostic excerpts are evidence, not full session logs.
 */

import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main

    property bool pickerOpen: false
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
    exclusionMode: "Ignore"
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: pickerOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    function showPicker() {
        if (pickerOpen)
            return

        list.stopAnimations()
        list.mouseEnabled = false
        list.keyboardMode = true
        mouseMovementHandler.lastPosition = mouseMovementHandler.point.position
        pickerOpen = true
        Qt.callLater(function() {
            if (!main.pickerOpen)
                return
            list.forceActiveFocus()
            list.wheelTargetX = list.clampX(list.contentX)
            cacheRetryTimer.start()
        })
    }

    function hidePicker() {
        pickerOpen = false
        list.stopAnimations()
        list.mouseEnabled = false
        list.keyboardMode = true
        cacheRetryTimer.stop()
    }

    Component.onCompleted: {
        Quickshell.execDetached([
            "bash",
            Quickshell.shellPath("cache.sh"),
            Quickshell.shellDir
        ])
    }

    Component.onDestruction: {
        cacheRetryTimer.stop()
        list.stopAnimations()
    }

    IpcHandler {
        target: "hyprquickpaper"

        function toggle() {
            if (main.pickerOpen)
                main.hidePicker()
            else
                main.showPicker()
        }

        function show() {
            main.showPicker()
        }

        function hide() {
            main.hidePicker()
        }
    }

    FileView {
        id: configFile

        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs

            property string wallpaper_path: ""
            property string cache_path: ""
            property int number_of_pictures: 5
            property string border_color: "#89b4fa"
        }
    }

    FolderListModel {
        id: folderModel

        folder: "file://" + configs.wallpaper_path

        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
        sortField: FolderListModel.Name
    }

    MouseArea {
        id: backgroundArea

        anchors.fill: parent
        z: 0

        onClicked: main.hidePicker()
    }

    HoverHandler {
        id: mouseMovementHandler

        property point lastPosition: point.position

        onActiveChanged: {
            if (!active) {
                list.mouseEnabled = false
                list.keyboardMode = true
            } else {
                lastPosition = point.position
                list.mouseEnabled = false
                list.keyboardMode = true
            }
        }

        onPointChanged: {
            // Pointer position changes are observable even while HoverHandler.active is false.
            // Do not discard those movement events, or mouse mode can remain disabled indefinitely.
            if (
                point.position.x === lastPosition.x &&
                point.position.y === lastPosition.y
            ) {
                return
            }

            lastPosition = point.position
            list.mouseEnabled = true
            list.keyboardMode = false

            // The pointer may already be inside a MouseArea, so onEntered may not fire again.
            Qt.callLater(function() {
                list.activateHoveredDelegate()
            })
        }
    }

    ListView {
        id: list

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        height: main.imageHeight
        z: 1
        focus: main.pickerOpen

        model: folderModel
        orientation: ListView.Horizontal
        spacing: 0
        clip: true
        cacheBuffer: width * 2

        property int selectedIndex: 0
        property int previousSelectedIndex: 0
        property bool keyboardMode: false
        property bool mouseEnabled: false

        property real tileWidth: configs.number_of_pictures > 0
            ? Math.max(1, width / configs.number_of_pictures - 10)
            : 0

        property real wheelTargetX: contentX

        function traceScroll(cause) {
            console.warn(
                "[QKP_TRACE]", cause,
                "contentX=" + Number(contentX).toFixed(2),
                "targetX=" + Number(wheelTargetX).toFixed(2),
                "originX=" + Number(originX).toFixed(2),
                "contentWidth=" + Number(contentWidth).toFixed(2),
                "viewWidth=" + Number(width).toFixed(2),
                "selectedIndex=" + selectedIndex,
                "keyboardAnimation=" + keyboardScrollAnimation.running,
                "wheelAnimation=" + wheelAnimation.running,
                "mouseEnabled=" + mouseEnabled,
                "keyboardMode=" + keyboardMode
            )
        }

        onContentXChanged: traceScroll("contentXChanged")
        onOriginXChanged: traceScroll("originXChanged")
        onContentWidthChanged: traceScroll("contentWidthChanged")
        onCountChanged: traceScroll("countChanged")
        onSelectedIndexChanged: traceScroll("selectedIndexChanged")

        function stopAnimations() {
            keyboardScrollAnimation.stop()
            wheelAnimation.stop()
            wheelTargetX = clampX(contentX)
        }

        function activateHoveredDelegate() {
            if (keyboardMode || !mouseEnabled)
                return

            for (let i = 0; i < count; i++) {
                const item = itemAtIndex(i)
                if (item && item.pointerHovered) {
                    item.scheduleHover()
                    return
                }
            }
        }

        function selectIndex(index) {
            if (count <= 0)
                return

            index = Math.max(0, Math.min(index, count - 1))

            if (index === selectedIndex)
                return

            previousSelectedIndex = selectedIndex
            selectedIndex = index
        }

        function keyboardSelect(index) {
            traceScroll("keyboardSelect index=" + index)
            keyboardMode = true
            mouseEnabled = false
            mouseMovementHandler.lastPosition = mouseMovementHandler.point.position
            wheelAnimation.stop()
            wheelTargetX = clampX(contentX)
            selectIndex(index)
            ensureVisibleAnimated(selectedIndex)
        }

        function activateCurrent() {
            if (folderModel.count <= 0 || selectedIndex < 0 || selectedIndex >= folderModel.count)
                return

            const path = folderModel.get(selectedIndex, "filePath")
            if (!path || String(path).length === 0) {
                console.warn("HyprQuickpaper: empty wallpaper path for index", selectedIndex)
                return
            }

            Quickshell.execDetached([
                "bash",
                Quickshell.shellPath("commands.sh"),
                String(path)
            ])

            main.hidePicker()
        }

        function clampX(x) {
            const minX = originX
            const maxX = minX + Math.max(0, contentWidth - width)
            const value = Number(x)
            return Math.max(
                minX,
                Math.min(isFinite(value) ? value : minX, maxX)
            )
        }

        function ensureVisibleAnimated(i) {
            const item = list.itemAtIndex(i)
            if (!item)
                return

            wheelAnimation.stop()
            keyboardScrollAnimation.stop()
            wheelTargetX = clampX(contentX)

            if (i === 0) {
                keyboardScrollAnimation.stop()
                if (Math.abs(contentX - originX) > 0.5) {
                    keyboardScrollAnimation.from = contentX
                    keyboardScrollAnimation.to = originX
                    keyboardScrollAnimation.start()
                }
                return
            }

            const expandedWidth = list.tileWidth * 1.50 + 40
            const extraWidth = Math.max(0, expandedWidth - list.tileWidth)
            const itemStart = item.x - extraWidth / 2
            const itemEnd = item.x + item.width + extraWidth / 2

            let target = contentX
            if (itemStart < contentX) {
                target = itemStart
            } else if (itemEnd > contentX + width) {
                target = itemEnd - width
            }

            target = clampX(target)
            if (target !== contentX) {
                keyboardScrollAnimation.stop()
                keyboardScrollAnimation.from = contentX
                keyboardScrollAnimation.to = target
                keyboardScrollAnimation.start()
            }
        }

        NumberAnimation {
            id: keyboardScrollAnimation
            target: list
            property: "contentX"
            duration: 1000
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: wheelAnimation
            target: list
            property: "contentX"
            duration: 750
            easing.type: Easing.OutCubic
        }

        Timer {
            id: cacheRetryTimer
            interval: 2000
            repeat: true
            running: main.pickerOpen

            onTriggered: {
                for (let i = 0; i < list.count; i++) {
                    const item = list.itemAtIndex(i)
                    if (item)
                        item.retryImage()
                }
            }
        }

        delegate: Item {
            id: delegateItem
            required property int index

            property bool active: index === list.selectedIndex
            property bool pointerHovered: hitArea.containsMouse
            property real entranceOffset: 25

            function scheduleHover() {
                if (!list.keyboardMode && list.mouseEnabled)
                    hoverTimer.start()
            }

            function cancelHover() {
                hoverTimer.stop()
            }

            function retryImage() {
                if (img.status !== Image.Error)
                    return false

                const source = img.source
                img.source = ""
                img.source = source
                return true
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

                width: active ? list.tileWidth * 1.50 + 40 : list.tileWidth
                height: active ? main.imageHeight : main.inactiveImageHeight

                transform: Translate {
                    y: delegateItem.entranceOffset
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    id: alt
                    visible: img.status === Image.Error
                    text: "Caching"
                    color: configs.border_color
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

                    source: "file://" + configs.cache_path + folderModel.get(index, "fileName")
                    sourceSize.width: list.tileWidth * 1.50 + 40
                    sourceSize.height: main.imageHeight

                    transform: Shear {
                        xFactor: -0.25
                    }
                }

                Rectangle {
                    id: border
                    anchors.fill: parent
                    z: 10
                    color: "transparent"
                    border.width: 2
                    border.color: configs.border_color
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

                // Keep the hit area within the fixed delegate slot.
                // The selected image grows visually, but its hit area must not overlap neighbors.
                width: list.tileWidth
                height: wallpaperItem.height
                z: 20
                hoverEnabled: true

                transform: Shear {
                    xFactor: -0.25
                }

                Timer {
                    id: hoverTimer
                    interval: 30
                    repeat: false

                    onTriggered: {
                        list.traceScroll("hoverTimer triggered index=" + index)

                        if (list.keyboardMode || !list.mouseEnabled)
                            return

                        // Delay hover only while keyboard navigation is still repositioning the list.
                        // Wheel scrolling may continue while the hovered wallpaper expands.
                        if (keyboardScrollAnimation.running) {
                            start()
                            return
                        }

                        list.selectIndex(index)
                    }
                }

                onEntered: {
                    list.traceScroll("MouseArea entered index=" + index)

                    // Scrolling moves delegates beneath a stationary pointer.
                    // Ignore those synthetic hover transitions while the wheel animates.
                    // Real pointer movement is handled by HoverHandler and activateHoveredDelegate().
                    if (wheelAnimation.running)
                        return

                    if (!list.keyboardMode && list.mouseEnabled)
                        hoverTimer.start()
                }

                onExited: hoverTimer.stop()

                onClicked: {
                    hoverTimer.stop()
                    list.keyboardMode = false
                    list.selectIndex(index)
                    list.activateCurrent()
                }

                onWheel: function(wheel) {
                    keyboardScrollAnimation.stop()
                    // Wheel input is mouse interaction; keep hover enabled during wheel animation.
                    list.keyboardMode = false
                    list.mouseEnabled = true

                    // Cancel pending hover timers before scrolling starts. Otherwise a timer
                    // started by a previous delegate entry can change selection mid-scroll.
                    for (let i = 0; i < list.count; i++) {
                        const item = list.itemAtIndex(i)
                        if (item)
                            item.cancelHover()
                    }

                    if (!wheelAnimation.running)
                        list.wheelTargetX = list.clampX(list.contentX)

                    const delta = wheel.angleDelta.y !== 0
                        ? wheel.angleDelta.y
                        : wheel.angleDelta.x

                    list.traceScroll("wheel event delta=" + delta)
                    list.wheelTargetX = list.clampX(
                        list.wheelTargetX - delta * 0.8
                    )

                    wheelAnimation.stop()
                    wheelAnimation.from = list.contentX
                    wheelAnimation.to = list.wheelTargetX
                    wheelAnimation.start()
                    wheel.accepted = true
                }
            }

            Component.onCompleted: {
                if (index < 15) {
                    entranceTimer.start()
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

        Keys.onPressed: function(event) {
            const step = 1

            if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                keyboardSelect(selectedIndex + step)
            } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                keyboardSelect(selectedIndex - step)
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                keyboardSelect(selectedIndex + 5)
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                keyboardSelect(selectedIndex - 5)
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                activateCurrent()
            } else if (event.key === Qt.Key_Escape) {
                main.hidePicker()
            } else {
                return
            }

            event.accepted = true
        }
    }

    onPickerOpenChanged: {
        list.traceScroll("pickerOpenChanged open=" + pickerOpen)
        list.mouseEnabled = false
        list.keyboardMode = true
        mouseMovementHandler.lastPosition = mouseMovementHandler.point.position

        if (pickerOpen) {
            cacheRetryTimer.start()
            Qt.callLater(function() {
                if (main.pickerOpen)
                    list.forceActiveFocus()
            })
        } else {
            cacheRetryTimer.stop()
            list.stopAnimations()
        }
    }
}
