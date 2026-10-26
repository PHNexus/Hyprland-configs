import "../"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property real sectionSpacing: 8

    function editConfig(path) {
        var resolvedPath = path.replace(/^~/, Quickshell.env("HOME"));
        var runtimeDir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        var socket = runtimeDir + "/settings-nvim-single.sock";
        var lockFile = runtimeDir + "/settings-nvim-single.lock";
        var logFile = runtimeDir + "/settings-nvim-single.log";
        var title = "settings-nvim-single";
        Quickshell.execDetached(["sh", "-c", `
            file="$1"
            title="$2"
            socket="$3"
            lockFile="$4"
            logFile="$5"

            exec >>"$logFile" 2>&1
            echo "=== $(date): $file ==="

            for dependency in nvim kitty flock hyprctl jq; do
                if ! command -v "$dependency" >/dev/null 2>&1; then
                    echo "ERROR: Required command not found: $dependency"
                    settings hide
                    exit 127
                fi
            done

            exec 9>"$lockFile" || exit 1
            flock -x 9 || exit 1

            server_found() {
                nvim --server "$socket" --remote-expr '1' >/dev/null 2>&1
            }

            if server_found; then
                if nvim --server "$socket" --remote "$file"; then
                    echo "Remote request succeeded."
                else
                    result=$?
                    echo "ERROR: Remote request failed with exit code: $result"
                    flock -u 9
                    exec 9>&-
                    settings hide
                    exit "$result"
                fi
            else
                rm -f "$socket"

                kitty --title "$title" nvim --listen "$socket" "$file" 9>&- &

                ready=0
                for i in $(seq 1 100); do
                    if server_found; then
                        ready=1
                        echo "Neovim server started."
                        break
                    fi
                    sleep 0.1
                done

                if [ "$ready" -ne 1 ]; then
                    echo "ERROR: Neovim server did not start."
                    flock -u 9
                    exec 9>&-
                    settings hide
                    exit 1
                fi
            fi

            flock -u 9
            exec 9>&-

            for i in $(seq 1 50); do
                found=$(hyprctl -j clients 2>/dev/null | jq -r --arg title "$title" 'any(.[]; .class == "kitty" and .title == $title)')

                if [ "$found" = "true" ]; then
                    hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = "title:'"$title"'" })'
                    break
                fi
                sleep 0.1
            done

            settings hide
            `, "settings-nvim-single", resolvedPath, title, socket, lockFile, logFile]);
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
        contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content

            width: flick.width
            spacing: 16

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "CONFIGS"
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 19
                    font.weight: Font.Normal
                }

                Text {
                    text: "Edit your Hyprland & Wofi configuration files"
                    color: Theme.textFaint
                    font.family: "Noto Sans"
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
                spacing: 8

                Row {
                    spacing: 8
                    leftPadding: 2
                    bottomPadding: 2

                    Text {
                        text: "󰧨"
                        color: Theme.accent
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "HYPRLAND"
                        color: Theme.text
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
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
                    spacing: page.sectionSpacing
                    topPadding: 4

                    ConfigButton {
                        label: "RULES"
                        path: "~/.config/hypr/window_rules.lua"
                        icon: "󰖲"
                    }

                    ConfigButton {
                        label: "ENVIRONMENT"
                        path: "~/.config/hypr/environment.lua"
                        icon: "󰖟"
                    }

                    ConfigButton {
                        label: "LOCK SCREEN"
                        path: "~/.config/hypr/hyprlock.conf"
                        icon: "󰌾"
                    }

                }

            }

            Column {
                width: parent.width
                spacing: 8

                Row {
                    spacing: 8
                    leftPadding: 2
                    bottomPadding: 2

                    Text {
                        text: "󰍉"
                        color: Theme.accent
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "WOFI"
                        color: Theme.text
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
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
                    spacing: page.sectionSpacing
                    topPadding: 4

                    ConfigButton {
                        label: "CONFIG"
                        path: "~/.config/wofi/config"
                        icon: "󰒓"
                    }

                    ConfigButton {
                        label: "STYLE"
                        path: "~/.config/wofi/style.css"
                        icon: "󰏘"
                    }

                }

            }

        }

        ScrollBar.vertical: ScrollBar {
            visible: false
        }

    }

    component ConfigButton: Rectangle {
        id: card

        required property string label
        required property string path
        required property string icon

        width: parent.width
        height: 52
        radius: 10
        color: hover.hovered ? Theme.alpha(Theme.accent, 0.05) : Theme.alpha(Theme.text, 0.015)
        border.width: 1
        border.color: hover.hovered ? Theme.accent : Theme.border

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: page.editConfig(card.path)
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Rectangle {
                width: 32
                height: 32
                radius: 8
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.border
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: card.icon
                    color: hover.hovered ? Theme.accent : Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                }

            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: card.label
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    text: card.path.split("/").pop()
                    color: Theme.textFaint
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                }

            }

        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "󰏫"
            color: hover.hovered ? Theme.accent : Theme.textFaint
            font.family: Theme.iconFont
            font.pixelSize: 15
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
