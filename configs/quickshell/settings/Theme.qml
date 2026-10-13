import QtQuick
pragma Singleton

QtObject {
    id: root

    // GEOMETRY

    readonly property int radius: 16
    readonly property int radiusLg: 20
    readonly property int radiusSm: 10
    readonly property int radiusXs: 6

    // TYPOGRAPHY

    readonly property string fontFamily: "Inter"
    readonly property string displayFont: "Inter"
    readonly property string monoFont: "JetBrains Mono"
    property string iconFont: "JetBrainsMono Nerd Font"

    // MOTION
  
    readonly property int animMed: 200
    readonly property int animSlow: 320

    // SURFACES 
    // Card 

    readonly property color glass:         "#CC141418"
    readonly property color bg:            "#c0141418"
    readonly property color bgPanel:       "#14ffffff"
    readonly property color bgCard:        "#1affffff"
    readonly property color bgElev:        "#24ffffff"
    readonly property color bgHover:       "#2affffff"
    readonly property color bgActive:      "#33ffffff"

    // TEXT

    readonly property color text:          "#fafafa"
    readonly property color textSoft:      "#e0e0e0"
    readonly property color textDim:       "#8a8a8a"
    readonly property color textFaint:     "#565656"
    readonly property color textGhost:     "#303030"

    // ACCENT

    readonly property color accent:        "#ffffff"
    readonly property color accentSoft:    "#d4d4d4"
    readonly property color accentGlow:    "#ffffff"

    // BORDERS

    readonly property color ringOuter:     "#0fffffff"
    readonly property color ringInner:     "#05ffffff"
    readonly property color border:        "#0dffffff"
    readonly property color borderStrong:  "#1affffff"
    readonly property color borderAccent:  "#33ffffff"

    // STATES

    readonly property color danger:        "#ff5555"
    readonly property color ok:            "#4ade80"
    readonly property color trackBg:       "#10ffffff"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function tint(hex, a) {
        var c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}