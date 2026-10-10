pragma Singleton
import QtQuick

QtObject {
    id: root

    // Futuristic monochrome design system.
    readonly property int radius: 8
    readonly property real tiltStrength: 5
    readonly property string fontFamily: "JetBrains Mono"
    property string iconFont: "JetBrainsMono Nerd Font"

    readonly property int animFast: 100
    readonly property int animMed: 180
    readonly property int animSlow: 300

    readonly property real imageOpacity: 0.86

    // Deep black surfaces with subtle separation.
    readonly property color bg: "#030303"
    readonly property color bgPanel: "#080808"
    readonly property color bgCard: "#101010"

    // High-contrast typography.
    readonly property color text: "#ffffff"
    readonly property color textDim: "#b8b8b8"
    readonly property color textFaint: "#707070"

    // Monochrome highlights.
    readonly property color accent: "#ffffff"
    readonly property color accent2: "#a6a6a6"
    readonly property color border: "#292929"
    readonly property color borderAccent: "#f2f2f2"

    readonly property color danger: "#ffffff"
    readonly property color ok: "#ffffff"
    readonly property color trackBg: "#181818"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}