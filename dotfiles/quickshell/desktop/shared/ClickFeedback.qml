import "theme"
import QtQuick

Item {
    id: feedback
    required property Item target

    function play() {
        bounce.restart();
        rippleAnimation.restart();
    }

    Rectangle {
        id: ripple
        anchors.fill: parent
        radius: width / 2
        color: Theme.accent
        opacity: 0
    }

    SequentialAnimation {
        id: bounce
        NumberAnimation {
            target: feedback.target
            property: "scale"
            to: 0.88
            duration: 65
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: feedback.target
            property: "scale"
            to: 1.12
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: feedback.target
            property: "scale"
            to: 1
            duration: 180
            easing.type: Easing.OutBack
        }
    }

    ParallelAnimation {
        id: rippleAnimation
        NumberAnimation {
            target: ripple
            property: "scale"
            from: 0.25
            to: 1
            duration: 380
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: ripple
            property: "opacity"
            from: 0.22
            to: 0
            duration: 380
            easing.type: Easing.OutQuad
        }
    }
}
