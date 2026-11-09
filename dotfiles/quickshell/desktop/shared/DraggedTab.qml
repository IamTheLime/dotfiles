import "theme"
import QtQuick

Item {
    id: ghost
    required property bool active
    required property string label
    required property string side
    width: 240
    height: 86
    visible: opacity > 0.001
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.75
    property real phase: 0
    Behavior on opacity { NumberAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    NumberAnimation on phase {
        from: 0; to: Math.PI * 2
        duration: 1800
        loops: Animation.Infinite
        running: ghost.active
    }
    onPhaseChanged: blob.requestPaint()
    Canvas {
        id: blob
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const points = [];
            for (let i = 0; i < 12; i++) {
                const angle = i * Math.PI / 6;
                const pulse = 1 + 0.10 * Math.sin(ghost.phase * 2 + angle * 3)
                    + 0.05 * Math.cos(ghost.phase - angle * 2);
                points.push({x: width / 2 + Math.cos(angle) * 104 * pulse,
                    y: height / 2 + Math.sin(angle) * 34 * pulse});
            }
            ctx.beginPath();
            ctx.moveTo((points[11].x + points[0].x) / 2, (points[11].y + points[0].y) / 2);
            for (let i = 0; i < points.length; i++) {
                const point = points[i];
                const next = points[(i + 1) % points.length];
                ctx.quadraticCurveTo(point.x, point.y, (point.x + next.x) / 2, (point.y + next.y) / 2);
            }
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 8, width, height);
            fill.addColorStop(0, Theme.dragStart);
            fill.addColorStop(1, Theme.dragEnd);
            ctx.fillStyle = fill;
            ctx.fill();
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: 3
        UiText {
            width: 170
            text: ghost.label
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: 12
            font.weight: Theme.headingWeight
            color: Theme.dragText
        }
        UiText {
            width: 170
            text: ghost.side
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 11
            color: Theme.dragText
        }
    }
}
