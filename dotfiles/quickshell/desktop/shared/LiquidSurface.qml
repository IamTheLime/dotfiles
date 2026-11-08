import QtQuick

ShaderEffect {
    property vector2d surfaceSize: Qt.vector2d(width, height)
    property vector4d leftBox: Qt.vector4d(0, 0, width, height)
    property vector4d middleBox: Qt.vector4d(0, 0, 0, 0)
    property vector4d rightBox: Qt.vector4d(0, 0, 0, 0)
    property vector4d tint: Qt.vector4d(0.125, 0.141, 0.173, 0.44)
    property real joined: 0
    property real phase: 1
    property real singleShape: 0
    property real cornerRadius: 14
    property real edgeFeather: 0
    property real edgeHighlight: 1
    property real settling: 0
    fragmentShader: Qt.resolvedUrl("shaders/liquid.frag.qsb")
}
