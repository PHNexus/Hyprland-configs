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
    property real sliderMarginRight: 10
    property real sectionSpacing: 6

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
            spacing: 14

            Text {
                text: "CONFIGS"
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

            Text {
                text: "HYPRLAND"
                color: Theme.text
                font.family: "Noto Sans"
                font.pixelSize: 16
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                width: parent.width
                spacing: page.sectionSpacing

                ConfigButton {
                    label: "RULES"
                    path: "~/.config/hypr/window_rules.lua"
                }

                ConfigButton {
                    label: "INPUT"
                    path: "~/.config/hypr/input.lua"
                }

                ConfigButton {
                    label: "GENERAL"
                    path: "~/.config/hypr/general.lua"
                }

                ConfigButton {
                    label: "ENVIRONMENT"
                    path: "~/.config/hypr/environment.lua"
                }

                ConfigButton {
                    label: "ANIMATIONS"
                    path: "~/.config/hypr/animations.lua"
                }

                ConfigButton {
                    label: "LOCK SCREEN"
                    path: "~/.config/hypr/hyprlock.conf"
                }

            }

            Text {
                text: "WOFI"
                color: Theme.text
                font.family: "Noto Sans"
                font.pixelSize: 16
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                width: parent.width
                spacing: page.sectionSpacing

                ConfigButton {
                    label: "CONFIG"
                    path: "~/.config/wofi/config"
                }

                ConfigButton {
                    label: "STYLE"
                    path: "~/.config/wofi/style.css"
                }

            }

        }

        ScrollBar.vertical: ScrollBar {
            visible: false
        }

    }

    component ConfigButton: Rectangle {
        required property string label
        required property string path

        width: parent.width
        height: 42
        radius: Theme.radius
        color: "#00000000"
        border.width: 1
        border.color: Theme.border

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: Theme.textDim
            font.family: "Noto Sans"
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 2
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "\uf120"
                color: Theme.textDim
                font.family: Theme.iconFont
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "EDIT " + path.split("/").pop().toUpperCase()
                color: Theme.textDim
                font.family: "Noto Sans"
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }

        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                parent.color = Theme.alpha(Theme.accent, 0.08);
                parent.border.color = Theme.accent;
            }
            onExited: {
                parent.color = "#00000000";
                parent.border.color = Theme.border;
            }
            onClicked: page.editConfig(path)
        }

    }

}
