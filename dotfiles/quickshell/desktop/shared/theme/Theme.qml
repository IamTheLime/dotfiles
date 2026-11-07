pragma Singleton
import QtQuick

QtObject {
    // Shared Tokyo Night palette. Edit these colours to recolour shared components.
    readonly property color background: "#1a1b26"
    readonly property color surface: "#24283b"
    readonly property color elevated: "#292e42"
    readonly property color hovered: "#3b4261"
    readonly property color foreground: "#c0caf5"
    readonly property color muted: "#a9b1d6"
    readonly property color accent: "#7aa2f7"
    readonly property color accentHover: "#89b4fa"
    readonly property color error: "#f7768e"
    readonly property color white: "#ffffff"

    // Glass colour and opacity are independent; native blur remains enabled.
    readonly property color glassTint: background
    readonly property real glassOpacity: 0.58
    readonly property real cardOpacity: 0.70
    readonly property real accentOpacity: 0.28
    readonly property real accentHoverOpacity: 0.40
    readonly property real rimTopOpacity: 0.30
    readonly property real rimMiddleOpacity: 0.15
    readonly property real rimBottomOpacity: 0.07
    readonly property real rimWidth: 2

    // Top bar uses the same palette with lighter glass and shaded tray icons.
    readonly property color topBarTint: glassTint
    readonly property real topBarOpacity: 0.44
    readonly property color topBarText: foreground
    readonly property color topBarIcon: foreground
    readonly property real trayIconSaturation: 0.20
    readonly property color topBarGlass: alpha(topBarTint, topBarOpacity)

    // Dock, grouped windows, and shared popup roles.
    readonly property color dockTint: glassTint
    readonly property real dockOpacity: 0.15
    readonly property color groupFrame: background
    readonly property color groupBorder: elevated
    readonly property color divider: elevated
    readonly property color dividerHover: muted
    readonly property color tabBackground: surface
    readonly property color tabUnderline: accent
    readonly property color selection: hovered
    readonly property color closeText: foreground
    readonly property color closeSoft: "#493048"
    readonly property color closeEdge: "#994258"
    readonly property color closeHover: error
    readonly property color closePressed: "#ff899d"
    readonly property color dragStart: accentHover
    readonly property color dragEnd: accent
    readonly property color dragText: background
    readonly property real splitOpacity: 0.05
    readonly property var splitPalette: ["#7aa2f7", "#bb9af7", "#9ece6a", "#e0af68", "#f7768e", "#ff9e64"]

    readonly property color glass: alpha(glassTint, glassOpacity)
    readonly property color card: alpha(surface, cardOpacity)
    readonly property color text: foreground
    readonly property color secondaryText: muted
    readonly property color icon: white
    readonly property color button: elevated
    readonly property color buttonHover: hovered
    readonly property color buttonActive: alpha(accent, accentOpacity)
    readonly property color buttonActiveHover: alpha(accentHover, accentHoverOpacity)
    readonly property color focus: accent
    readonly property color sliderTrack: hovered
    readonly property color sliderFill: accent
    readonly property color sliderHandle: foreground
    readonly property color scrollbar: alpha(muted, 0.55)
    readonly property color artworkBackground: elevated
    readonly property color rimTop: alpha(foreground, rimTopOpacity)
    readonly property color rimMiddle: alpha(foreground, rimMiddleOpacity)
    readonly property color rimBottom: alpha(foreground, rimBottomOpacity)

    function alpha(colour: color, opacity: real): color {
        return Qt.rgba(colour.r, colour.g, colour.b, opacity);
    }
}
