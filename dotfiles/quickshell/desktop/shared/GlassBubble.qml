import QtQuick
import QtQml.Models
import Quickshell
import "theme"

Item {
    id: surface
    anchors.fill: parent
    anchors.margins: 4
    property real neckWidth: 36
    property real neckCenter: width / 2
    property real neckHeight: 34
    Behavior on neckWidth {
        enabled: surface.visible
        NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 0.35 }
    }
    readonly property real targetNeckX: Math.max(neckWidth / 2 + 4, Math.min(width - neckWidth / 2 - 4, neckCenter - x))
    property real neckX: 0
    property real tailX: 0
    function settleNeck() { neckX = targetNeckX; tailX = targetNeckX; }
    Component.onCompleted: settleNeck()
    onVisibleChanged: if (!visible) settleNeck()
    onTargetNeckXChanged: if (!visible) settleNeck()
    // Follow the live target per frame: OLED drift must not restart the slide.
    FrameAnimation {
        running: surface.visible && (Math.abs(surface.neckX - surface.targetNeckX) > 0.01
            || Math.abs(surface.tailX - surface.targetNeckX) > 0.01)
        onTriggered: {
            const dt = Math.min(frameTime, 0.05);
            surface.neckX += (surface.targetNeckX - surface.neckX) * (1 - Math.exp(-dt / 0.04));
            surface.tailX += (surface.targetNeckX - surface.tailX) * (1 - Math.exp(-dt / 0.08));
        }
    }
    readonly property real tailOffset: Math.max(-24, Math.min(24, tailX - neckX))
    readonly property real inset: Theme.rimWidth / 2
    readonly property real half: neckWidth / 2
    readonly property real leftRadius: Math.min(26 - inset, Math.max(0, (neckX - half - inset) / 2))
    readonly property real rightRadius: Math.min(26 - inset, Math.max(0, (width - inset - neckX - half) / 2))
    readonly property real leftShoulder: Math.max(inset + leftRadius, neckX - half - 16 + Math.min(0, tailOffset))
    readonly property real rightShoulder: Math.min(width - inset - rightRadius, neckX + half + 16 + Math.max(0, tailOffset))
    function cubic(a, b, c, d, t) {
        const u = 1 - t;
        return u*u*u*a + 3*u*u*t*b + 3*u*t*t*c + t*t*t*d;
    }
    function shoulderSpan(y) {
        const top = surface.neckHeight + inset;
        let low = 0, high = 1;
        for (let i = 0; i < 12; ++i) {
            const t = (low + high) / 2;
            if (cubic(top, top, top - 8, inset + 18, t) > y) low = t;
            else high = t;
        }
        const t = (low + high) / 2;
        return {
            left: cubic(leftShoulder, Math.max(leftShoulder, neckX - half + Math.min(0, tailOffset)), neckX - half, neckX - half, t),
            right: cubic(rightShoulder, Math.min(rightShoulder, neckX + half + Math.max(0, tailOffset)), neckX + half, neckX + half, t)
        };
    }
    Item {
        id: glassBody
        anchors.fill: parent
        anchors.topMargin: surface.neckHeight
    }
    Item {
        id: glassNeck
        x: surface.neckX - width / 2; y: 0
        width: surface.neckWidth; height: surface.neckHeight + Theme.rimWidth / 2
    }
    Canvas {
        id: glassPaint
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: surface; function onNeckXChanged() { glassPaint.requestPaint(); } function onNeckWidthChanged() { glassPaint.requestPaint(); } function onTailOffsetChanged() { glassPaint.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const inset = Theme.rimWidth / 2;
            const top = surface.neckHeight + inset;
            const r = 26 - inset;
            const right = width - inset;
            const bottom = height - inset;
            const neck = surface.neckX;
            const half = surface.neckWidth / 2;
            const leftTail = Math.min(0, surface.tailOffset);
            const rightTail = Math.max(0, surface.tailOffset);
            const leftRadius = surface.leftRadius;
            const rightRadius = surface.rightRadius;
            const leftShoulder = surface.leftShoulder;
            const rightShoulder = surface.rightShoulder;
            const tint = ctx.createLinearGradient(0, 0, 0, height);
            tint.addColorStop(0, Theme.rimTop);
            tint.addColorStop(0.45, Theme.rimMiddle);
            tint.addColorStop(1, Theme.rimBottom);
            ctx.beginPath();
            ctx.moveTo(inset + leftRadius, top);
            ctx.lineTo(leftShoulder, top);
            ctx.bezierCurveTo(Math.max(leftShoulder, neck - half + leftTail), top, neck - half, top - 8, neck - half, inset + 18);
            ctx.arcTo(neck - half, inset, neck - half + 18, inset, 18);
            ctx.lineTo(neck + half - 18, inset);
            ctx.arcTo(neck + half, inset, neck + half, inset + 18, 18);
            ctx.bezierCurveTo(neck + half, top - 8, Math.min(rightShoulder, neck + half + rightTail), top, rightShoulder, top);
            ctx.lineTo(right - rightRadius, top);
            ctx.arcTo(right, top, right, top + rightRadius, rightRadius);
            ctx.lineTo(right, bottom - r);
            ctx.arcTo(right, bottom, right - r, bottom, r);
            ctx.lineTo(inset + r, bottom);
            ctx.arcTo(inset, bottom, inset, bottom - r, r);
            ctx.lineTo(inset, top + leftRadius);
            ctx.arcTo(inset, top, inset + leftRadius, top, leftRadius);
            ctx.closePath();
            ctx.fillStyle = Theme.glass;
            ctx.fill();
            ctx.lineWidth = Theme.rimWidth;
            ctx.strokeStyle = tint;
            ctx.stroke();
        }
    }
    readonly property Region blurRegion: Region { id: nativeBlur
        item: glassBody; radius: 26
        topLeftRadius: surface.leftRadius + Theme.rimWidth / 2
        topRightRadius: surface.rightRadius + Theme.rimWidth / 2
        Region { item: glassNeck; radius: 18; bottomLeftRadius: 0; bottomRightRadius: 0 }
        property Instantiator shoulders: Instantiator {
            model: 16
            delegate: Region {
                required property int index
                readonly property var span: surface.shoulderSpan(19 + index + 0.5)
                x: Math.floor(surface.x + span.left)
                y: surface.y + 19 + index
                width: Math.ceil(surface.x + span.right) - x
                height: 1
            }
            onObjectAdded: (index, object) => nativeBlur.regions.push(object)
        }
    }
}
