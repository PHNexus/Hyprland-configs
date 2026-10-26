import "../"
import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: page

    property var drives: []
    property var filesystems: []
    property var cleanupInfo: ({
        "yay": 0,
        "pacman": 0,
        "journal": 0,
        "trash": 0,
        "flatpak": 0,
        "cliphist": 0,
        "thumbs": 0
    })
    property var driveUsageData: ({
    })
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property string pendingAction: ""
    property string pendingTitle: ""
    property string pendingMessage: ""
    property string lastAction: ""
    readonly property var sizeUnits: ({
        "B": 1,
        "K": 1024,
        "KB": 1024,
        "KIB": 1024,
        "M": 1.04858e+06,
        "MB": 1.04858e+06,
        "MIB": 1.04858e+06,
        "G": 1.07374e+09,
        "GB": 1.07374e+09,
        "GIB": 1.07374e+09,
        "T": 1.09951e+12,
        "TB": 1.09951e+12,
        "TIB": 1.09951e+12
    })

    function formatBytes(b) {
        if (!isFinite(b) || b < 0)
            return "0 B";

        var units = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        var v = b;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            ++i;
        }
        return (i ? v.toFixed(1) : Math.round(v)) + " " + units[i];
    }

    function formatCount(n) {
        var v = Math.round(n) || 0;
        return v + (v === 1 ? " item" : " items");
    }

    function parseSize(v) {
        if (!v)
            return 0;

        var m = String(v).trim().match(/^([0-9.]+)\s*([A-Za-z]*)$/);
        if (!m)
            return 0;

        var n = parseFloat(m[1]);
        if (isNaN(n))
            return 0;

        return n * (m[2] ? (sizeUnits[m[2].toUpperCase()] || 1) : 1);
    }

    function usageColor(p) {
        return p >= 90 ? "#ffffff" : p >= 75 ? "#e0e0e0" : "#c0c0c0";
    }

    function usageWidth(p) {
        return Math.min(1, Math.max(0, p / 100));
    }

    function ignoredMount(m) {
        var mount = String(m || "").trim();
        var lower = mount.toLowerCase();
        var hiddenMounts = ["/boot", "/efi", "/proc", "/sys", "/dev", "/run/lock"];
        if (lower === "swap" || lower === "[swap]")
            return true;

        for (var i = 0; i < hiddenMounts.length; ++i) {
            var entry = hiddenMounts[i];
            if (lower === entry || lower.indexOf(entry + "/") === 0)
                return true;

        }
        if (lower === "/run" || (lower.indexOf("/run/") === 0 && lower.indexOf("/run/media/") !== 0))
            return true;

        return false;
    }

    function ignoredFilesystem(f) {
        var filesystem = String(f || "").trim().toLowerCase();
        var hiddenSources = ["tmpfs", "devtmpfs", "overlay", "zram", "swap", "squashfs", "efivarfs", "proc", "sysfs", "cgroup", "tracefs", "securityfs", "fusectl", "mqueue", "pstore", "configfs", "debugfs", "ramfs"];
        if (hiddenSources.some(function(x) {
            return filesystem.indexOf(x) === 0;
        }))
            return true;

        return /^\/dev\/(zram|loop|ram|fd)\d+/i.test(filesystem) || filesystem.indexOf("/zram") !== -1 || filesystem.indexOf("/swap") !== -1 || filesystem === "[swap]";
    }

    function parseDfLine(line) {
        var f = String(line || "").trim().split(/\s+/);
        if (f.length < 6 || !f[0])
            return null;

        var d = {
            "filesystem": f[0],
            "total": parseInt(f[1], 10),
            "used": parseInt(f[2], 10),
            "available": parseInt(f[3], 10),
            "percent": parseInt(String(f[4]).replace("%", ""), 10),
            "mount": f.slice(5).join(" ")
        };
        if ([d.total, d.used, d.available, d.percent].some(function(n) {
            return !isFinite(n);
        }))
            return null;

        if (ignoredMount(d.mount) || ignoredFilesystem(d.filesystem))
            return null;

        return d;
    }

    function collectDeviceNames(device, names) {
        if (!device)
            return names;

        var name = String(device.name || "");
        if (name.length > 0 && names.indexOf(name) === -1)
            names.push(name);

        var children = device.children || [];
        for (var i = 0; i < children.length; ++i) collectDeviceNames(children[i], names)
        return names;
    }

    function parseDriveData(data) {
        var disks = [];
        try {
            var raw = String(data || "").trim();
            if (!raw.length)
                return disks;

            var obj = JSON.parse(raw);
            if (!obj.blockdevices)
                return disks;

            for (var i = 0; i < obj.blockdevices.length; ++i) {
                var d = obj.blockdevices[i];
                var name = String(d.name || "").trim();
                var lowerName = name.toLowerCase();
                var type = String(d.type || "").toLowerCase();
                var size = parseInt(d.size, 10) || 0;
                var virtualDevice = /^(zram|loop|ram|fd)\d+$/.test(lowerName);
                if (type === "disk" && name.length > 0 && size > 0 && !virtualDevice)
                    disks.push({
                    "name": name,
                    "model": String(d.model || "").trim(),
                    "size": size,
                    "type": String(d.type || ""),
                    "tran": String(d.tran || ""),
                    "deviceNames": collectDeviceNames(d, [])
                });

            }
        } catch (e) {
            console.warn("[Storage] lsblk JSON error:", e);
        }
        return disks;
    }

    function updateDriveUsage() {
        var usage = ({
        });
        for (var i = 0; i < drives.length; ++i) {
            var drive = drives[i];
            var names = drive.deviceNames || [drive.name];
            var used = 0;
            var found = false;
            var countedSources = [];
            for (var j = 0; j < filesystems.length; ++j) {
                var fs = filesystems[j];
                var source = String(fs.filesystem || "");
                if (source.indexOf("/dev/") !== 0)
                    continue;

                var sourceName = source.slice(5);
                var matched = names.indexOf(sourceName) !== -1;
                if (!matched) {
                    for (var k = 0; k < names.length; ++k) {
                        var base = String(names[k] || "");
                        if (base.length > 0 && sourceName.indexOf(base) === 0) {
                            matched = true;
                            break;
                        }
                    }
                }
                if (matched && countedSources.indexOf(source) === -1) {
                    used += Math.max(0, Number(fs.used) || 0);
                    countedSources.push(source);
                    found = true;
                }
            }
            if (found && drive.name)
                usage[drive.name] = used;

        }
        page.driveUsageData = usage;
    }

    function refreshAll() {
        if (!pDrives.running)
            pDrives.running = true;

        if (!pStorage.running)
            pStorage.running = true;

        if (!pCleanup.running)
            pCleanup.running = true;

    }

    function confirmAction(title, message, command) {
        pendingTitle = title;
        pendingMessage = message;
        pendingAction = command;
        confirmPopup.visible = true;
    }

    function runCommand(command) {
        if (commandProcess.running) {
            console.warn("[Storage] Another command is still running.");
            return ;
        }
        lastAction = command;
        commandProcess.command = ["sh", "-c", command];
        commandProcess.running = true;
    }

    Component.onCompleted: page.refreshAll()

    Process {
        id: pDrives

        command: ["sh", "-c", "lsblk -J -b -o NAME,MODEL,SIZE,TYPE,TRAN,MOUNTPOINTS,FSTYPE 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                page.drives = page.parseDriveData(text);
                page.updateDriveUsage();
            }
        }

        stderr: StdioCollector {
        }

    }

    Process {
        id: pStorage

        command: ["sh", "-c", "df -P -B1 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                var fs = [];
                var output = String(text || "").trim();
                var lines = output.length ? output.split("\n") : [];
                for (var i = 1; i < lines.length; ++i) {
                    var item = page.parseDfLine(lines[i]);
                    if (item)
                        fs.push(item);

                }
                page.filesystems = fs;
                page.updateDriveUsage();
            }
        }

        stderr: StdioCollector {
        }

    }

    Process {
        id: pCleanup

        command: ["sh", "-c", "p() { printf '%s %s\\n' \"$1\" \"${2:-0}\"; }; " + "p YAY \"$(du -sb \"$HOME/.cache/yay\" 2>/dev/null | awk '{print $1}')\"; " + "p PACMAN \"$(du -sb /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')\"; " + "p JOURNAL \"$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+ ?[BKMGT]' | tail -1 | tr -d ' ')\"; " + "p TRASH \"$(du -sb \"$HOME/.local/share/Trash\" 2>/dev/null | awk '{print $1}')\"; " + "p FLATPAK \"$(flatpak uninstall --unused --assumeno 2>/dev/null | grep -oE '[0-9.]+ ?(kB|MB|GB|TB)' | tail -1 | tr -d ' ')\"; " + "p CLIPHIST \"$(cliphist list 2>/dev/null | wc -l)\"; " + "p THUMBS \"$(du -sb \"$HOME/.cache/quickshell/thumbs\" 2>/dev/null | awk '{print $1}')\""]

        stdout: StdioCollector {
            onStreamFinished: {
                var info = {
                    "yay": 0,
                    "pacman": 0,
                    "journal": 0,
                    "trash": 0,
                    "flatpak": 0,
                    "cliphist": 0,
                    "thumbs": 0
                };
                var output = String(text || "").trim();
                var lines = output.length ? output.split("\n") : [];
                for (var i = 0; i < lines.length; ++i) {
                    var p = lines[i].trim().split(/\s+/);
                    var k = p[0] ? p[0].toLowerCase() : "";
                    if (p.length > 1 && info[k] !== undefined)
                        info[k] = page.parseSize(p.slice(1).join(" "));

                }
                page.cleanupInfo = info;
            }
        }

        stderr: StdioCollector {
        }

    }

    Process {
        id: commandProcess

        onRunningChanged: {
            if (!running)
                refreshTimer.restart();

        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.log("[Storage] " + text.trim());

            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.warn("[Storage] " + text.trim());

            }
        }

    }

    Timer {
        id: refreshTimer

        interval: 500
        repeat: false
        onTriggered: page.refreshAll()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: page.refreshAll()
    }

    Rectangle {
        id: confirmPopup

        visible: false
        anchors.centerIn: parent
        z: 100
        width: Math.min(parent.width - 30, 420)
        height: 200
        radius: 12
        color: Theme.bg
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.15)

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Row {
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: Theme.alpha(Theme.text, 0.05)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: "󰀦"
                        color: Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                    }

                }

                Text {
                    text: page.pendingTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

            Text {
                width: parent.width
                text: page.pendingMessage
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Item {
                width: 1
                height: 4
            }

            Row {
                width: parent.width
                spacing: 10

                ToolButton {
                    width: (parent.width - 10) / 2
                    label: "CANCEL"
                    onClicked: confirmPopup.visible = false
                }

                ToolButton {
                    width: (parent.width - 10) / 2
                    label: "CONFIRM"
                    accent: true
                    onClicked: {
                        confirmPopup.visible = false;
                        page.runCommand(page.pendingAction);
                    }
                }

            }

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
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list

            width: flick.width
            spacing: 14

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "STORAGE"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                }

                Text {
                    text: "Disk usage and system cleanup"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "DRIVES"
                        color: Theme.textDim
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }

                    Text {
                        text: "· " + page.drives.length
                        color: Theme.textFaint
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }

                }

                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: page.drives

                        delegate: DriveCard {
                            width: list.width
                        }

                    }

                    Text {
                        visible: page.drives.length === 0
                        text: pDrives.running ? "SCANNING FOR DRIVES..." : "NO PHYSICAL DRIVES DETECTED"
                        color: Theme.textFaint
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        leftPadding: 4
                    }

                }

            }

            Column {
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width
                    height: 20
                    spacing: 8

                    Text {
                        text: "󰃢"
                        color: Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "CLEANUP"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [{
                            "key": "trash",
                            "label": "TRASH",
                            "icon": "󰆴",
                            "action": "EMPTY",
                            "title": "EMPTY TRASH?",
                            "message": "Permanently deletes the contents of your trash.",
                            "command": "mkdir -p \"$HOME/.local/share/Trash/files\" \"$HOME/.local/share/Trash/info\" && find \"$HOME/.local/share/Trash/files\" \"$HOME/.local/share/Trash/info\" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
                        }, {
                            "key": "cliphist",
                            "label": "CLIPHIST",
                            "icon": "󰅇",
                            "action": "WIPE",
                            "title": "WIPE CLIPBOARD HISTORY?",
                            "message": "Clears the clipboard history.",
                            "command": "cliphist wipe"
                        }, {
                            "key": "thumbs",
                            "label": "WALLPAPER PICKER",
                            "icon": "󰋩",
                            "action": "CLEAR",
                            "title": "CLEAR THUMBNAIL CACHE?",
                            "message": "Clears the Quickshell thumbnail cache.",
                            "command": "mkdir -p \"$HOME/.cache/quickshell/thumbs\" && find \"$HOME/.cache/quickshell/thumbs\" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
                        }, {
                            "key": "yay",
                            "label": "YAY CACHE",
                            "icon": "󰏗",
                            "action": "CLEAN",
                            "title": "CLEAR YAY CACHE?",
                            "message": "Deletes the contents of the Yay cache.",
                            "command": "mkdir -p \"$HOME/.cache/yay\" && find \"$HOME/.cache/yay\" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
                        }, {
                            "key": "pacman",
                            "label": "PACMAN CACHE",
                            "icon": "󰏖",
                            "action": "CLEAN ALL",
                            "title": "DELETE ALL PACMAN CACHE?",
                            "message": "Permanently deletes all cached package files and download directories. Installed packages are not uninstalled, but cached packages cannot be reinstalled offline.",
                            "command": "pkexec find /var/cache/pacman/pkg -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
                        }, {
                            "key": "journal",
                            "label": "JOURNAL",
                            "icon": "󰆍",
                            "action": "2 DAYS",
                            "title": "VACUUM JOURNAL?",
                            "message": "Keeps journal entries from the last 2 days and removes older archived entries.",
                            "command": "pkexec journalctl --vacuum-time=2d"
                        }, {
                            "key": "flatpak",
                            "label": "FLATPAK UNUSED",
                            "icon": "󰏆",
                            "action": "CLEAN",
                            "title": "REMOVE UNUSED FLATPAKS?",
                            "message": "Removes unused Flatpak runtimes and packages.",
                            "command": "flatpak uninstall --unused --assumeyes"
                        }]

                        delegate: CleanupButton {
                            required property var modelData

                            width: list.width
                            label: modelData.label
                            icon: modelData.icon
                            value: modelData.key === "cliphist" ? page.formatCount(page.cleanupInfo.cliphist) : page.formatBytes(page.cleanupInfo[modelData.key])
                            actionText: modelData.action
                            onClicked: page.confirmAction(modelData.title, modelData.message, modelData.command)
                        }

                    }

                }

            }

        }

    }

    component DriveCard: Rectangle {
        id: driveRoot

        required property var modelData
        property var usageData: page.driveUsageData[modelData.name] !== undefined ? page.driveUsageData[modelData.name] : null
        property bool hasUsage: usageData !== null && modelData.size > 0
        property real usedPct: hasUsage ? Math.min(100, Math.max(0, usageData / modelData.size * 100)) : 0
        property string driveName: String(modelData.model || "").trim().length > 0 ? String(modelData.model).trim() : String(modelData.name || "Storage drive")
        property string driveType: String(modelData.name || "").toLowerCase().indexOf("nvme") === 0 ? "NVMe" : (String(modelData.tran || "").trim().length > 0 ? String(modelData.tran).toUpperCase() : (/^sd[a-z]+$/i.test(String(modelData.name || "")) ? "SATA / SCSI" : "LOCAL DRIVE"))

        height: 104
        radius: 10
        color: driveHover.hovered ? Theme.alpha(Theme.text, 0.04) : Theme.alpha(Theme.text, 0.015)
        border.width: 1
        border.color: driveHover.hovered ? Theme.alpha(Theme.text, 0.22) : Theme.alpha(Theme.text, 0.1)
        clip: true

        HoverHandler {
            id: driveHover
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Row {
                id: driveHeader

                width: parent.width
                height: 36
                spacing: 10

                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.alpha(Theme.text, 0.05)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: "󰋊"
                        color: driveRoot.hasUsage ? page.usageColor(driveRoot.usedPct) : Theme.textDim
                        font.family: Theme.iconFont
                        font.pixelSize: 17
                    }

                }

                Column {
                    width: Math.max(40, driveHeader.width - 36 - driveHeader.spacing * 2 - driveCapacity.width)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: driveRoot.driveName
                        color: Theme.text
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: driveRoot.driveType + "  ·  /dev/" + String(driveRoot.modelData.name || "")
                        color: Theme.textDim
                        elide: Text.ElideRight
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }

                }

                Column {
                    id: driveCapacity

                    width: 110
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: page.formatBytes(driveRoot.modelData.size).replace(".0 ", " ")
                        color: Theme.text
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: driveRoot.hasUsage ? Math.round(driveRoot.usedPct) + "% USED" : "TOTAL CAPACITY"
                        color: Theme.textDim
                        horizontalAlignment: Text.AlignRight
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }

                }

            }

            Rectangle {
                id: capacityTrack

                width: parent.width
                height: 5
                radius: 3
                color: Theme.alpha(Theme.text, 0.08)
                clip: true

                Rectangle {
                    width: driveRoot.hasUsage ? capacityTrack.width * page.usageWidth(driveRoot.usedPct) : 0
                    height: parent.height
                    radius: 3
                    color: Theme.text

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animMed
                        }

                    }

                }

            }

            Row {
                width: parent.width
                height: 28
                spacing: 8

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    radius: 6
                    color: Theme.alpha(Theme.text, 0.02)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.08)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: "USED"
                            color: Theme.textFaint
                            font.family: Theme.monoFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: parent.width - 45
                            text: driveRoot.hasUsage ? page.formatBytes(driveRoot.usageData).replace(".0 ", " ") : "—"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    radius: 6
                    color: Theme.alpha(Theme.text, 0.02)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.08)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: "FREE"
                            color: Theme.textFaint
                            font.family: Theme.monoFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: parent.width - 45
                            text: driveRoot.hasUsage ? page.formatBytes(Math.max(0, driveRoot.modelData.size - driveRoot.usageData)).replace(".0 ", " ") : "—"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

            }

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

    component CleanupButton: Rectangle {
        id: cleanupRoot

        required property string label
        required property string icon
        required property string value
        required property string actionText

        signal clicked()

        height: 52
        radius: 10
        color: cleanupHover.hovered ? Theme.alpha(Theme.text, 0.04) : Theme.alpha(Theme.text, 0.015)
        border.width: 1
        border.color: cleanupHover.hovered ? Theme.alpha(Theme.text, 0.22) : Theme.alpha(Theme.text, 0.1)
        clip: true

        HoverHandler {
            id: cleanupHover

            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: cleanupRoot.clicked()
        }

        Row {
            id: cleanupInfoRow

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: cleanupActions.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 36
            spacing: 10

            Rectangle {
                width: 36
                height: 36
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.alpha(Theme.text, 0.05)
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.1)

                Text {
                    anchors.centerIn: parent
                    text: cleanupRoot.icon
                    color: cleanupHover.hovered ? Theme.text : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                }

            }

            Column {
                width: Math.max(40, cleanupInfoRow.width - 36 - cleanupInfoRow.spacing)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: cleanupRoot.label
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: "Available to clean"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

            }

        }

        Column {
            id: cleanupActions

            width: 100
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: cleanupRoot.value
                color: Theme.text
                horizontalAlignment: Text.AlignRight
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideLeft
            }

            Row {
                width: parent.width
                spacing: 4
                layoutDirection: Qt.RightToLeft

                Text {
                    text: "󰅂"
                    color: cleanupHover.hovered ? Theme.text : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                }

                Text {
                    text: cleanupRoot.actionText
                    color: cleanupHover.hovered ? Theme.text : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.2
                }

            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 140
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }

        }

    }

    component ToolButton: Rectangle {
        id: btn

        property string label: ""
        property bool accent: false

        signal clicked()

        height: 38
        radius: 8
        color: accent ? (btnHover.hovered ? "#ffffff" : "#e0e0e0") : (btnHover.hovered ? Theme.alpha(Theme.text, 0.1) : "transparent")
        border.width: 1
        border.color: accent ? "#ffffff" : (btnHover.hovered ? Theme.alpha(Theme.text, 0.3) : Theme.alpha(Theme.text, 0.15))

        HoverHandler {
            id: btnHover
        }

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.accent ? "#151515" : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
        }

        MouseArea {
            anchors.fill: parent
            onClicked: btn.clicked()
        }

        Behavior on color {
            ColorAnimation {
                duration: 140
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }

        }

    }

}
