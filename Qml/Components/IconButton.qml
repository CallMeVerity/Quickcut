import QtQuick

Rectangle {
    id: btn
    width: 32
    height: 32
    radius: 6
    color: {
        if (!enabled) return "transparent"
        if (mouseArea.pressed) return accent ? "#1e3a8a" : "#10ffffff"
        if (mouseArea.containsMouse) return accent ? "#1d4ed8" : "#0dffffff"
        return accent ? "#1e40af" : "transparent"
    }
    border.color: {
        if (!enabled) return "transparent"
        if (accent) return "#1d4ed8"
        if (mouseArea.containsMouse) return "#444444"
        return "transparent"
    }
    border.width: accent ? 1 : 1
    opacity: enabled ? 1.0 : 0.3

    property string iconName: ""
    property string tooltip: ""
    property bool accent: false
    signal clicked()

    Behavior on color { ColorAnimation { duration: 80 } }
    Behavior on border.color { ColorAnimation { duration: 80 } }

    Canvas {
        id: canvas
        anchors.centerIn: parent
        width: 16
        height: 16

        property color iconColor: btn.accent && !mouseArea.containsMouse ? "#60a5fa"
                                : btn.accent && mouseArea.containsMouse ? "#ffffff"
                                : "#b0b0b0"

        onIconColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections { target: btn; function onIconNameChanged() { canvas.requestPaint() } }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = iconColor
            ctx.fillStyle = iconColor
            ctx.lineWidth = 1.5
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            var w = width, h = height

            if (btn.iconName === "open") {
                ctx.beginPath()
                ctx.moveTo(1, 5)
                ctx.lineTo(1, 3)
                ctx.lineTo(4, 3)
                ctx.lineTo(5, 5)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(0, 5)
                ctx.lineTo(15, 5)
                ctx.lineTo(15, 13)
                ctx.lineTo(0, 13)
                ctx.closePath()
                ctx.fill()
            }
            else if (btn.iconName === "play") {
                ctx.beginPath()
                ctx.moveTo(4, 2)
                ctx.lineTo(13, 8)
                ctx.lineTo(4, 14)
                ctx.closePath()
                ctx.fill()
            }
            else if (btn.iconName === "pause") {
                ctx.fillRect(3, 2, 3.5, 12)
                ctx.fillRect(9.5, 2, 3.5, 12)
            }
            else if (btn.iconName === "step-back") {
                ctx.beginPath()
                ctx.moveTo(10, 2)
                ctx.lineTo(5, 8)
                ctx.lineTo(10, 14)
                ctx.closePath()
                ctx.fill()
                ctx.fillRect(3, 2, 1.5, 12)
            }
            else if (btn.iconName === "step-forward") {
                ctx.beginPath()
                ctx.moveTo(6, 2)
                ctx.lineTo(11, 8)
                ctx.lineTo(6, 14)
                ctx.closePath()
                ctx.fill()
                ctx.fillRect(11.5, 2, 1.5, 12)
            }
            else if (btn.iconName === "mark-in") {
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(9, 1)
                ctx.lineTo(4, 1)
                ctx.lineTo(4, 15)
                ctx.lineTo(9, 15)
                ctx.stroke()
            }
            else if (btn.iconName === "mark-out") {
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(7, 1)
                ctx.lineTo(12, 1)
                ctx.lineTo(12, 15)
                ctx.lineTo(7, 15)
                ctx.stroke()
            }
            else if (btn.iconName === "cut") {
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.arc(5, 11, 3, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(11, 11, 3, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(7, 9)
                ctx.lineTo(11, 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(9, 9)
                ctx.lineTo(5, 2)
                ctx.stroke()
            }
            else if (btn.iconName === "mark-remove") {
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(3, 2)
                ctx.lineTo(1, 2)
                ctx.lineTo(1, 14)
                ctx.lineTo(3, 14)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(13, 2)
                ctx.lineTo(15, 2)
                ctx.lineTo(15, 14)
                ctx.lineTo(13, 14)
                ctx.stroke()
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(5, 5)
                ctx.lineTo(11, 11)
                ctx.moveTo(11, 5)
                ctx.lineTo(5, 11)
                ctx.stroke()
            }
            else if (btn.iconName === "no-audio") {
                ctx.beginPath()
                ctx.moveTo(1, 6)
                ctx.lineTo(4, 6)
                ctx.lineTo(8, 3)
                ctx.lineTo(8, 13)
                ctx.lineTo(4, 10)
                ctx.lineTo(1, 10)
                ctx.closePath()
                ctx.fill()
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(10, 5)
                ctx.lineTo(14, 11)
                ctx.moveTo(14, 5)
                ctx.lineTo(10, 11)
                ctx.stroke()
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: btn.clicked()
    }

    Rectangle {
        id: tooltipBg
        visible: mouseArea.containsMouse && btn.tooltip !== "" && !mouseArea.pressed
        y: -(height + 6)
        width: tooltipText.width + 16
        height: 24
        radius: 4
        color: "#1e1e1e"
        border.color: "#333333"

        x: {
            var centered = (btn.width - width) / 2
            if (!btn.window) return centered
            var leftEdge = btn.mapToItem(btn.window.contentItem, centered, 0).x
            var rightEdge = leftEdge + width
            var margin = 6
            if (leftEdge < margin)
                centered += (margin - leftEdge)
            else if (rightEdge > btn.window.width - margin)
                centered -= (rightEdge - btn.window.width + margin)
            return centered
        }

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: btn.tooltip
            color: "#aaaaaa"
            font.pixelSize: 11
        }
    }
}
