import "theme"
import QtQuick
Canvas {
    property real formation: 1
    property color tint: Theme.accent
    onFormationChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const p = Math.max(0, Math.min(1, formation));
        const neck = (1 - p) * height * 0.49;
        const mid = width / 2;
        const r = 3 + (1 - p) * 10;
        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, Theme.splitOpacity);
        ctx.beginPath(); ctx.moveTo(r, 0);
        ctx.lineTo(mid - 24, 0);
        ctx.bezierCurveTo(mid - 10, neck, mid + 10, neck, mid + 24, 0);
        ctx.lineTo(width - r, 0); ctx.quadraticCurveTo(width, 0, width, r);
        ctx.lineTo(width, height - r); ctx.quadraticCurveTo(width, height, width - r, height);
        ctx.lineTo(mid + 24, height);
        ctx.bezierCurveTo(mid + 10, height - neck, mid - 10, height - neck, mid - 24, height);
        ctx.lineTo(r, height); ctx.quadraticCurveTo(0, height, 0, height - r);
        ctx.lineTo(0, r); ctx.quadraticCurveTo(0, 0, r, 0);
        ctx.closePath(); ctx.fill();
    }
}
