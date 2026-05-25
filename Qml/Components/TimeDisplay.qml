import QtQuick
import QtQuick.Layouts

Item {
    id: td
    width: row.width
    height: 36

    property string label: ""
    property int timeMs: 0
    property bool highlight: false
    property bool editable: false
    signal edited(int ms)

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            text: td.label
            color: "#555555"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
        }

        Rectangle {
            width: timeText.width + 12
            height: 22
            radius: 3
            color: td.editable && editArea.containsMouse ? "#1a1a1a" : "transparent"
            border.color: td.editable && editArea.containsMouse ? "#333333" : "transparent"

            Text {
                id: timeText
                anchors.centerIn: parent
                text: formatMs(td.timeMs)
                color: td.highlight ? "#1d4ed8" : "#c0c0c0"
                font.pixelSize: 12
                font.family: "monospace"
                font.weight: Font.Medium
                visible: !editInput.visible
            }

            TextInput {
                id: editInput
                anchors.centerIn: parent
                visible: false
                color: "#1d4ed8"
                font.pixelSize: 12
                font.family: "monospace"
                font.weight: Font.Medium
                selectByMouse: true
                selectionColor: "#401d4ed8"
                selectedTextColor: "#ffffff"
                horizontalAlignment: TextInput.AlignHCenter
                inputMethodHints: Qt.ImhDigitsOnly

                onAccepted: {
                    var ms = parseMs(text)
                    if (ms >= 0) td.edited(ms)
                    visible = false
                    focus = false
                }
                onActiveFocusChanged: {
                    if (!activeFocus) visible = false
                }
                Keys.onEscapePressed: { visible = false; focus = false }
            }

            MouseArea {
                id: editArea
                anchors.fill: parent
                hoverEnabled: td.editable
                visible: td.editable
                cursorShape: Qt.IBeamCursor
                onDoubleClicked: {
                    editInput.text = formatMs(td.timeMs)
                    editInput.visible = true
                    editInput.forceActiveFocus()
                    editInput.selectAll()
                }
            }
        }
    }

    function formatMs(ms) {
        if (ms < 0) ms = 0
        var h = Math.floor(ms / 3600000)
        var m = Math.floor((ms % 3600000) / 60000)
        var s = Math.floor((ms % 60000) / 1000)
        var millis = ms % 1000

        var pad2 = (n) => n < 10 ? "0" + n : "" + n
        var pad3 = (n) => n < 10 ? "00" + n : n < 100 ? "0" + n : "" + n

        if (h > 0) return h + ":" + pad2(m) + ":" + pad2(s) + "." + pad3(millis)
        return pad2(m) + ":" + pad2(s) + "." + pad3(millis)
    }

    function parseMs(str) {
        str = str.trim()
        var parts = str.split(".")
        var msPart = parts.length > 1 ? parseInt(parts[1].padEnd(3, "0").substring(0, 3)) : 0
        var timeParts = parts[0].split(":")
        var total = 0
        if (timeParts.length === 3) {
            total = parseInt(timeParts[0]) * 3600000 + parseInt(timeParts[1]) * 60000 + parseInt(timeParts[2]) * 1000
        } else if (timeParts.length === 2) {
            total = parseInt(timeParts[0]) * 60000 + parseInt(timeParts[1]) * 1000
        } else {
            total = parseInt(timeParts[0]) * 1000
        }
        return isNaN(total + msPart) ? -1 : total + msPart
    }
}
