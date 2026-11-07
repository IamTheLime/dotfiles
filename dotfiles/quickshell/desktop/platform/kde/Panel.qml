import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
    required property var spec
    screen: spec.screen
    visible: spec.visible
    implicitWidth: spec.implicitWidth
    implicitHeight: spec.implicitHeight
    color: spec.color
    mask: spec.mask
    anchors.top: spec.edge === "top"
    anchors.bottom: spec.edge === "bottom"
    anchors.left: spec.edge === "top"
    anchors.right: spec.edge === "top"
    exclusionMode: spec.edge === "bottom" ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: spec.exclusiveZone
    WlrLayershell.namespace: "dotfiles-" + spec.role
    WlrLayershell.layer: WlrLayer.Overlay
    BackgroundEffect.blurRegion: spec.blurRegion
}
