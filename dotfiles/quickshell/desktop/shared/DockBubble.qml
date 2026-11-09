import QtQuick
import QtQml.Models
import Quickshell
import "theme"

Item {
    id: bubble
    required property real progress
    required property real pinnedWidth
    required property real runningWidth
    property real gap: 12
    property bool rising: true
    readonly property real motion: Math.sin(Math.PI * progress) * (1 - smooth(0.78, 1, progress))
    readonly property real wobble: Theme.dockWobblePixels * motion
    readonly property real wavePhase: progress * 9.4
    readonly property real lift: smooth(0, 0.32, progress)
    readonly property real spread: smooth(0.32, 0.82, progress)
    readonly property real diameter: 14 + 54 * lift
    readonly property real bodyY: height - 7 - 69 * lift - 18 * Math.sin(Math.PI * lift)
    readonly property real contentWidth: pinnedWidth + (runningWidth > 0 ? gap + runningWidth : 0)
    readonly property real startX: (width - contentWidth) / 2
    readonly property real leftWidth: diameter + (pinnedWidth - diameter) * spread
    readonly property real rightWidth: diameter + (runningWidth - diameter) * spread
    readonly property real leftCenter: width / 2 + (startX + pinnedWidth / 2 - width / 2) * spread
    readonly property real rightCenter: width / 2 + (startX + pinnedWidth + gap + runningWidth / 2 - width / 2) * spread
    readonly property vector4d leftBox: Qt.vector4d(leftCenter - leftWidth / 2, bodyY, leftWidth, diameter)
    readonly property vector4d rightBox: Qt.vector4d(rightCenter - rightWidth / 2, bodyY, rightWidth, diameter)
    readonly property vector4d wholeBox: Qt.vector4d(leftBox.x, bodyY, rightBox.x + rightBox.z - leftBox.x, diameter)
    readonly property real softness: 0.1 + 18 * (1 - split)
    readonly property real split: smooth(0.76, 1, progress)
    readonly property vector4d tail: Qt.vector4d(width / 2, bodyY + diameter / 2,
        bodyY + diameter / 2 + Math.max(0, height - 3 - bodyY - diameter / 2) * (1 - smooth(0.65, 1, lift)),
        10 * Math.sin(Math.PI * lift))
    opacity: smooth(0, 0.08, progress)

    function smooth(a, b, value) {
        const t = Math.max(0, Math.min(1, (value - a) / (b - a)));
        return t * t * (3 - 2 * t);
    }
    function capsule(x, y, box) {
        const r = Math.min(box.z, box.w) / 2;
        const qx = Math.abs(x - box.x - box.z / 2) - box.z / 2 + r;
        const qy = Math.abs(y - box.y - box.w / 2) - box.w / 2 + r;
        return Math.min(Math.max(qx, qy), 0) + Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) - r;
    }
    function merge(a, b, k) {
        const h = Math.max(0, Math.min(1, 0.5 + 0.5 * (b - a) / k));
        return b + (a - b) * h - k * h * (1 - h);
    }
    function distance(x, y) {
        const across = (x - width / 2) / Math.max(diameter, rightBox.x + rightBox.z - leftBox.x);
        x += wobble * 0.55 * Math.sin(wavePhase) * (y - bodyY - diameter / 2) / diameter;
        y += wobble * (0.65 * Math.sin(across * Math.PI * 2 + wavePhase)
            + 0.35 * Math.sin(across * Math.PI * 4 - wavePhase * 0.7));
        let d = capsule(x, y, leftBox);
        if (runningWidth > 0) {
            const whole = capsule(x, y, wholeBox);
            const separated = merge(d, capsule(x, y, rightBox), softness);
            d = whole + (separated - whole) * split;
        }
        if (tail.w > 0.01) {
            const t = Math.max(0, Math.min(1, (y - tail.y) / Math.max(0.01, tail.z - tail.y)));
            const droplet = Math.hypot(x - tail.x, y - tail.y - (tail.z - tail.y) * t) - tail.w * (1 - 0.8 * t);
            d = merge(d, droplet, 12 * (1 - lift));
        }
        return d;
    }
    function span(y, side) {
        if (side === 1 && runningWidth <= 0) return Qt.point(0, 0);
        const split = (leftBox.x + leftBox.z + rightBox.x) / 2;
        const start = side === 0 ? 0 : split;
        const end = side === 0 && runningWidth > 0 ? split : width;
        let seed = side === 0 ? leftCenter : rightCenter;
        const tailSeed = Math.max(start, Math.min(end, width / 2));
        if (distance(tailSeed, y) < distance(seed, y)) seed = tailSeed;
        if (distance(seed, y) > 0) return Qt.point(0, 0);
        let lo = start, hi = seed;
        for (let i = 0; i < 10; ++i) {
            const m = (lo + hi) / 2;
            if (distance(m, y) > 0) lo = m; else hi = m;
        }
        const left = hi;
        lo = seed; hi = end;
        for (let i = 0; i < 10; ++i) {
            const m = (lo + hi) / 2;
            if (distance(m, y) > 0) hi = m; else lo = m;
        }
        return Qt.point(left, lo);
    }
    property var blurSpans: []
    function updateBlur() {
        const spans = [];
        const top = bodyY - wobble * 2 - 2;
        const bottom = Math.max(bodyY + diameter, tail.z + tail.w) + wobble * 2 + 2;
        for (let row = 0; row < Math.ceil(height); ++row) {
            if (row < top || row > bottom) spans.push(Qt.point(0, 0), Qt.point(0, 0));
            else spans.push(span(row + 0.5, 0), span(row + 0.5, 1));
        }
        blurSpans = spans;
    }
    onProgressChanged: Qt.callLater(updateBlur)
    onWidthChanged: Qt.callLater(updateBlur)
    onHeightChanged: Qt.callLater(updateBlur)
    onPinnedWidthChanged: Qt.callLater(updateBlur)
    onRunningWidthChanged: Qt.callLater(updateBlur)
    onGapChanged: Qt.callLater(updateBlur)
    Component.onCompleted: Qt.callLater(updateBlur)
    readonly property Region blurRegion: progress >= 0.999 ? settledBlur : motionBlur
    Region {
        id: settledBlur
        Region {
            x: bubble.leftBox.x; y: bubble.leftBox.y
            width: bubble.leftBox.z; height: bubble.leftBox.w
            radius: bubble.diameter / 2
        }
        Region {
            x: bubble.rightBox.x; y: bubble.rightBox.y
            width: bubble.runningWidth > 0 ? bubble.rightBox.z : 0
            height: bubble.rightBox.w
            radius: bubble.diameter / 2
        }
    }
    Region {
        id: motionBlur
        property Instantiator strips: Instantiator {
            model: Math.ceil(bubble.height) * 2
            delegate: Region {
                required property int index
                readonly property point interval: bubble.blurSpans[index] || Qt.point(0, 0)
                x: Math.round(interval.x)
                y: Math.floor(index / 2)
                width: Math.max(0, Math.round(interval.y) - x)
                height: 1
            }
            onObjectAdded: (index, object) => motionBlur.regions.push(object)
            onObjectRemoved: (index, object) => { motionBlur.regions = motionBlur.regions.filter(region => region !== object); }
        }
    }
    ShaderEffect {
        anchors.fill: parent
        property vector2d surfaceSize: Qt.vector2d(width, height)
        property vector4d leftBox: bubble.leftBox
        property vector4d rightBox: bubble.rightBox
        property vector4d tail: bubble.tail
        property real softness: bubble.softness
        property real split: bubble.split
        property real tailSoftness: 12 * (1 - bubble.lift)
        property real hasRunning: bubble.runningWidth > 0 ? 1 : 0
        property real wobble: bubble.wobble
        property real wavePhase: bubble.wavePhase
        property vector2d streak: Qt.vector2d(
            Theme.dockMotionBlurPixels * bubble.motion * bubble.spread * (bubble.rising ? 1 : -1),
            Theme.dockMotionBlurPixels * bubble.motion * (1 - bubble.spread * 0.65) * (bubble.rising ? -1 : 1))
        property vector4d tint: Qt.vector4d(Theme.dockTint.r, Theme.dockTint.g, Theme.dockTint.b, Theme.dockOpacity)
        fragmentShader: Qt.resolvedUrl("shaders/dock-bubble.frag.qsb")
    }
}
