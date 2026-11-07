import "theme"
import QtQuick

Canvas {
    id: bond
    property bool joined: false
    property color tint: Theme.accent
    property real merge: joined ? 1 : 0
    Behavior on merge { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
    onMergeChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const p = Math.max(0, Math.min(1.08, merge));
        const r = Math.min(7, height * 0.3);
        const cy = height / 2;
        const left = width / 2 - r - 3 + p * 3;
        const right = width / 2 + r + 3 - p * 3;
        const neck = r * p * 0.8;
        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.22 + p * 0.18);
        ctx.strokeStyle = tint;
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.arc(left, cy, r, Math.PI / 2, Math.PI * 1.5);
        ctx.bezierCurveTo(left + r, cy - r, width / 2 - 2, cy - neck, width / 2, cy - neck);
        ctx.bezierCurveTo(width / 2 + 2, cy - neck, right - r, cy - r, right, cy - r);
        ctx.arc(right, cy, r, -Math.PI / 2, Math.PI / 2);
        ctx.bezierCurveTo(right - r, cy + r, width / 2 + 2, cy + neck, width / 2, cy + neck);
        ctx.bezierCurveTo(width / 2 - 2, cy + neck, left + r, cy + r, left, cy + r);
        ctx.closePath(); ctx.fill(); ctx.stroke();
        if (p < 0.15) {
            ctx.clearRect(width / 2 - (1 - p) * 2, 0, (1 - p) * 4, height);
        }
    }
}
