import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.DockApp

// Application dock: the running Hyprland applications plus a persistent list of 
// pinned ones, on the largest monitor at the bottom edge.
PanelWindow {
    id: root

    // --- WAYLAND CONFIGURATION ---
    WlrLayershell.layer: WlrLayer.Top

    // The dock claims its strip of the screen so windows tile above it instead
    // of running underneath.
    exclusionMode: root.reservesSpace
        ? ExclusionMode.Normal
        : ExclusionMode.Ignore

    // Automatically picks the largest monitor (by resolution area).
    // Matches Hyprland monitors to Quickshell screens by name.
    // Falls back to the first screen if nothing matches.
    screen: {
        const screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return null

        const monitors = Hyprland.monitors.values
        if (!monitors || monitors.length === 0)
            return screens[0]

        // Find the largest monitor by area
        let largest = null
        let largestArea = 0
        for (let i = 0; i < monitors.length; i++) {
            const m = monitors[i]
            const area = (m.width || 0) * (m.height || 0)
            if (area > largestArea) {
                largestArea = area
                largest = m
            }
        }

        if (!largest)
            return screens[0]

        // Match the largest monitor to a Quickshell screen by name
        for (let s = 0; s < screens.length; s++)
            if (screens[s].name === largest.name)
                return screens[s]

        return screens[0]
    }

    // --- USER SETTINGS ---
    readonly property var settings: DockSettings.settings

    // --- PINNING ---
    readonly property var pinnedApps: settings.apps.pinned

    function isPinned(key: string): bool {
        const pinned = root.pinnedApps
        for (let i = 0; i < pinned.length; i++)
            if (root.entryKey(pinned[i]) === key)
                return true
        return false
    }

    function pinApp(key: string): void {
        if (!key || root.isPinned(key))
            return
        DockSettings.persistPinned(root.pinnedApps.concat([key]))
    }

    function unpinApp(key: string): void {
        if (!key)
            return
        DockSettings.persistPinned(
            root.pinnedApps.filter(id => root.entryKey(id) !== key))
    }

    // --- APP MODEL ---
    function lookupEntry(appId: string): var {
        if (!appId)
            return null
        const direct = DesktopEntries.heuristicLookup(appId)
        if (direct)
            return direct
        const wanted = appId.toLowerCase()
        const apps = DesktopEntries.applications.values
        for (let i = 0; i < apps.length; i++) {
            const command = apps[i].command
            if (!command || command.length === 0)
                continue
            if (`${command[0]}`.split("/").pop().toLowerCase() === wanted)
                return apps[i]
        }
        return null
    }

    function entryKey(appId: string): string {
        if (!appId)
            return ""
        const entry = root.lookupEntry(appId)
        return entry ? entry.id : appId.toLowerCase()
    }

    function iconFor(entry: var, appId: string): string {
        const raw = `${entry?.icon ?? ""}`.trim()
            .replace(/^image:\/\/icon\//, "").split("?")[0].trim()
        const name = raw.length > 0 ? raw : (appId ? appId : "")
        return Quickshell.iconPath(
            name.length > 0 ? name : "application-x-executable",
            "application-x-executable")
    }

    readonly property var dockEntries: {
        DesktopEntries.applications.values
        const toplevels = ToplevelManager.toplevels.values
        let byKey = ({})
        let order = []

        function makeItem(key, appId, pinned) {
            const desktopEntry = root.lookupEntry(appId)
            const name = desktopEntry && desktopEntry.name.length > 0
                ? desktopEntry.name : appId
            return { "key": key, "appId": appId, "desktopEntry": desktopEntry,
                     "name": name, "iconSource": root.iconFor(desktopEntry, appId),
                     "windows": [], "pinned": pinned }
        }

        const pinned = root.pinnedApps
        for (let i = 0; i < pinned.length; i++) {
            const key = root.entryKey(pinned[i])
            if (key === "" || byKey[key] !== undefined)
                continue
            byKey[key] = makeItem(key, pinned[i], true)
            order.push(key)
        }

        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i]
            const key = root.entryKey(toplevel.appId)
            if (key === "")
                continue
            if (byKey[key] === undefined) {
                byKey[key] = makeItem(key, toplevel.appId, false)
                order.push(key)
            }
            byKey[key].windows.push(toplevel)
        }

        return order.map(key => byKey[key])
    }

    // --- VISIBILITY ---
    property bool autohide: settings.dock.autohide

    readonly property bool reservesSpace: settings.dock.reserveSpace && !autohide
    exclusiveZone: reservesSpace ? dockHeight + settings.dock.marginBottom : 0

    // --- CONTEXT MENU ---
    property var menuItem: null
    readonly property bool menuOpen: contextMenu.visible

    function openMenuFor(item, actions): void {
        root.menuItem = item
        contextMenu.actions = actions
        contextMenu.visible = true
    }

    function closeMenu(): void {
        contextMenu.visible = false
        root.menuItem = null
    }

    HyprlandFocusGrab {
        windows: [root]
        active: contextMenu.visible
        onCleared: root.closeMenu()
    }

    readonly property bool revealed: !autohide || root.pointerHeld
        || root.menuOpen

    property bool pointerHeld: false

    Timer {
        id: hideDelay
        interval: root.settings.dock.hideDelay
        onTriggered: root.pointerHeld = false
    }

    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }

    readonly property int dockHeight: settings.dock.iconSize
        + 2 * settings.pill.padding + 10
    readonly property int menuReserve: 3 * 32 + 2 * 2 + 16 + 8
    implicitHeight: dockHeight + settings.dock.marginBottom + 30 + menuReserve

    readonly property int hotZoneHeight: root.revealed
        ? settings.dock.marginBottom + 3
        : 3

    mask: Region {
        Region {
            x: 0
            y: 0
            width: root.menuOpen ? root.width : 0
            height: root.menuOpen ? root.height : 0
        }
        Region {
            x: Math.round(pill.x)
            y: Math.round(pill.y)
            width: root.menuOpen ? 0 : Math.round(pill.width)
            height: root.menuOpen ? 0 : Math.round(pill.height)
        }
        Region {
            x: 0
            y: root.height - root.hotZoneHeight
            width: (root.autohide && !root.menuOpen) ? root.width : 0
            height: (root.autohide && !root.menuOpen) ? root.hotZoneHeight : 0
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.menuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.closeMenu()
    }

    HoverHandler {
        id: dockHover
        onHoveredChanged: {
            if (dockHover.hovered) {
                hideDelay.stop()
                root.pointerHeld = true
            } else {
                hideDelay.restart()
            }
        }
    }

    // ==========================================
    // DOCK PILL
    // ==========================================
    Item {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        width: dockRow.implicitWidth + 2 * root.settings.pill.padding
        height: root.dockHeight

        property real revealOffset: root.revealed
            ? root.settings.dock.marginBottom
            : -(height - 3)

        Behavior on revealOffset {
            NumberAnimation {
                duration: root.settings.pill.animationDuration
                easing.type: Easing.OutQuint
            }
        }

        y: parent.height - height - revealOffset

        Behavior on width {
            NumberAnimation {
                duration: root.settings.pill.animationDuration
                easing.type: Easing.OutQuint
            }
        }

        RectangularShadow {
            anchors.fill: pillBg
            radius: pillBg.radius
            blur: 15
            color: Qt.rgba(DockTheme.shadow.r, DockTheme.shadow.g, DockTheme.shadow.b, 0.4)
        }

        // Gradient BORDER layer (outer)
        Rectangle {
            id: pillBg
            anchors.fill: parent
            radius: root.settings.pill.radius
            opacity: root.settings.opacity.normal

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: root.settings.border.colorTop !== ""
                        ? root.settings.border.colorTop
                        : DockTheme.primary
                }
                GradientStop {
                    position: 1.0
                    color: root.settings.border.colorBottom !== ""
                        ? root.settings.border.colorBottom
                        : DockTheme.on_primary
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: root.settings.border.width
                radius: parent.radius - anchors.margins
                color: DockTheme.background
            }
        }

        RowLayout {
            id: dockRow
            anchors.centerIn: parent
            spacing: root.settings.dock.spacing

            DockLauncherButton {
                visible: DockSettings.launcherButton
                command: root.settings.dock.launcherCommand
                iconSize: root.settings.dock.iconSize
                dockWindow: root
                Layout.alignment: Qt.AlignVCenter

                onReloadRequested: {
                    DockSettings.reloadSettings()
                    DockTheme.reload()
                }
                onSettingsRequested: DockSettings.dialogOpen = true
                onEditConfigRequested: DockSettings.editConfig()
            }

            Rectangle {
                visible: DockSettings.launcherButton
                Layout.alignment: Qt.AlignVCenter
                Layout.bottomMargin: 4
                implicitWidth: 1
                implicitHeight: Math.round(root.settings.dock.iconSize * 0.75)
                color: DockTheme.primary
            }

            Repeater {
                model: root.dockEntries

                delegate: DockItem {
                    id: dockItem
                    required property var modelData

                    entry: modelData
                    iconSize: root.settings.dock.iconSize
                    dockWindow: root
                    Layout.alignment: Qt.AlignVCenter

                    onPinRequested: key => root.pinApp(key)
                    onUnpinRequested: key => root.unpinApp(key)
                }
            }
        }
    }

    // ==========================================
    // CONTEXT MENU
    // ==========================================
    DockMenu {
        id: contextMenu

        x: {
            if (!root.menuItem)
                return 0
            const center = pill.x + dockRow.x + root.menuItem.x
                + root.menuItem.width / 2
            return Math.max(8, Math.min(root.width - width - 8, center - width / 2))
        }
        y: pill.y - height - 8

        onCloseRequested: root.closeMenu()
    }
}