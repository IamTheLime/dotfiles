import "theme"
import QtQuick
import QtQuick.Controls
Slider {
    id: slider
    from: 0; to: 1; stepSize: 0.01
    implicitHeight: 32
    background: Rectangle {
        x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth; height: 7; radius: 4; color: Theme.sliderTrack
        Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 4; color: Theme.sliderFill }
    }
    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: 18; height: 18; radius: 9; color: Theme.sliderHandle
        scale: slider.pressed ? 1.2 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
    }
}
