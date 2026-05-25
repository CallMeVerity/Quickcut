import QtQuick

Item {
    id: timeline

    property int duration: 0
    property int position: 0
    property int inPoint: 0
    property int outPoint: duration
    property var removeSegments: []
    property string waveformSource: ""

    signal seek(int ms)
    signal inPointModified(int ms)
    signal outPointModified(int ms)
    signal removeSegmentAdded(int startMs, int endMs)
    signal removeSegmentRemoved(int index)
    signal removeSegmentModeChanged(int index, string mode)
    signal editBegin()

    readonly property real msPerPixel: duration > 0 ? duration / track.width : 1

    function posToX(ms) {
        return ms / msPerPixel
    }

    function xToMs(x) {
        return Math.round(x * msPerPixel)
    }

    Rectangle {
        anchors.fill: parent
        color: "#141414"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: "#222222"
        }

        Item {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "#0e0e0e"
                border.color: "#252525"
                border.width: 1
            }

            Image {
                id: waveformImg
                anchors.fill: parent
                anchors.margins: 1
                fillMode: Image.Stretch
                opacity: 0.6
                visible: timeline.waveformSource !== ""
                source: visible ? "file://" + timeline.waveformSource : ""
                cache: false
                asynchronous: true
            }

            Rectangle {
                x: Math.max(0, timeline.posToX(timeline.inPoint))
                width: Math.min(parent.width, timeline.posToX(timeline.outPoint)) - x
                height: parent.height
                radius: 2
                color: "#151d4ed8"
                border.color: "#401d4ed8"
                border.width: 1
            }

            Repeater {
                model: timeline.removeSegments
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    property bool isMute: (modelData.mode || "cut") === "mute"
                    property real startX: Math.max(timeline.posToX(timeline.inPoint), timeline.posToX(modelData.start))
                    property real endX: Math.min(timeline.posToX(timeline.outPoint), timeline.posToX(modelData.end))
                    x: startX
                    width: Math.max(1, endX - startX)
                    height: parent.height
                    color: isMute ? "#40ff9933" : "#40ff3333"
                    border.color: isMute ? "#80ff9933" : "#80ff3333"
                    border.width: 1
                    radius: 1

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 2
                        width: 14
                        height: 14
                        radius: 2
                        color: removeXMouse.containsMouse ? "#ff5555" : "#80222222"
                        z: 2

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "#ffffff"
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: removeXMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: timeline.removeSegmentRemoved(index)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: (mouse) => {
                            var pos = mapToItem(track, mouse.x, mouse.y)
                            segmentMenu.segmentIndex = index
                            segmentMenu.segmentMode = modelData.mode || "cut"
                            segmentMenu.x = Math.min(pos.x, track.width - segmentMenu.width - 4)
                            segmentMenu.y = Math.min(pos.y, track.height - segmentMenu.height - 4)
                            segmentMenu.visible = true
                        }
                    }
                }
            }

            Rectangle {
                id: removePreview
                visible: false
                height: parent.height
                color: "#30ff3333"
                border.color: "#60ff3333"
                border.width: 1
                radius: 1
                z: 5
            }

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    drawTicks(ctx)
                }

                property int _dur: timeline.duration
                on_DurChanged: requestPaint()

                function drawTicks(ctx) {
                    if (timeline.duration <= 0) return
                    var w = width, h = height
                    var mspp = timeline.msPerPixel

                    var intervals = [100, 200, 500, 1000, 2000, 5000, 10000, 30000, 60000, 300000, 600000]
                    var interval = intervals[intervals.length - 1]
                    for (var i = 0; i < intervals.length; i++) {
                        if (intervals[i] / mspp >= 40) { interval = intervals[i]; break }
                    }

                    var startMs = 0
                    ctx.strokeStyle = "#333333"
                    ctx.fillStyle = "#555555"
                    ctx.font = "9px monospace"
                    ctx.lineWidth = 1

                    for (var ms = startMs; ms <= timeline.duration; ms += interval) {
                        var x = timeline.posToX(ms)
                        if (x < 0 || x > w) continue
                        ctx.beginPath()
                        ctx.moveTo(x, h - 12)
                        ctx.lineTo(x, h - 4)
                        ctx.stroke()
                    }

                    var labelInterval = interval
                    while (labelInterval / mspp < 80) labelInterval *= 2
                    startMs = 0
                    for (var lms = startMs; lms <= timeline.duration; lms += labelInterval) {
                        var lx = timeline.posToX(lms)
                        if (lx < 0 || lx > w) continue
                        ctx.fillText(formatMs(lms), lx + 2, h - 2)
                    }
                }

                function formatMs(ms) {
                    var h = Math.floor(ms / 3600000)
                    var m = Math.floor((ms % 3600000) / 60000)
                    var s = Math.floor((ms % 60000) / 1000)
                    var ml = ms % 1000

                    var pad2 = (n) => n < 10 ? "0" + n : "" + n
                    var pad3 = (n) => n < 10 ? "00" + n : n < 100 ? "0" + n : "" + n

                    if (h > 0) return h + ":" + pad2(m) + ":" + pad2(s)
                    if (m > 0) return m + ":" + pad2(s) + "." + pad3(ml)
                    return s + "." + pad3(ml)
                }
            }

            Rectangle {
                id: inHandle
                x: Math.max(-4, timeline.posToX(timeline.inPoint) - 4)
                width: 8
                height: parent.height + 4
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: inArea.containsMouse ? "#1d4ed8" : "#2563eb"

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater { model: 3; Rectangle { width: 3; height: 1; color: "#0a0a0a"; anchors.horizontalCenter: parent.horizontalCenter } }
                }

                MouseArea {
                    id: inArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor

                    property bool _dragging: false
                    property real _dragStartX: 0

                    onPressed: (mouse) => {
                        _dragging = true
                        _dragStartX = mapToItem(track, mouse.x, mouse.y).x
                        timeline.editBegin()
                    }
                    onPositionChanged: (mouse) => {
                        if (_dragging) {
                            var trackX = mapToItem(track, mouse.x, mouse.y).x
                            var ms = timeline.xToMs(trackX)
                            ms = Math.max(0, Math.min(ms, timeline.outPoint - 1))
                            timeline.inPointModified(ms)
                            timeline.seek(ms)
                        }
                    }
                    onReleased: (mouse) => { _dragging = false }
                }
            }

            Rectangle {
                id: outHandle
                x: Math.min(parent.width - 4, timeline.posToX(timeline.outPoint) - 4)
                width: 8
                height: parent.height + 4
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: outArea.containsMouse ? "#1d4ed8" : "#2563eb"

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater { model: 3; Rectangle { width: 3; height: 1; color: "#0a0a0a"; anchors.horizontalCenter: parent.horizontalCenter } }
                }

                MouseArea {
                    id: outArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor

                    property bool _dragging: false
                    property real _dragStartX: 0

                    onPressed: (mouse) => {
                        _dragging = true
                        _dragStartX = mapToItem(track, mouse.x, mouse.y).x
                        timeline.editBegin()
                    }
                    onPositionChanged: (mouse) => {
                        if (_dragging) {
                            var trackX = mapToItem(track, mouse.x, mouse.y).x
                            var ms = timeline.xToMs(trackX)
                            ms = Math.min(timeline.duration, Math.max(ms, timeline.inPoint + 1))
                            timeline.outPointModified(ms)
                            timeline.seek(ms)
                        }
                    }
                    onReleased: (mouse) => { _dragging = false }
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: segmentMenu.visible
                z: 98
                onClicked: segmentMenu.visible = false
            }

            Rectangle {
                id: segmentMenu
                visible: false
                width: 150
                height: menuCol.height + 8
                color: "#1e1e1e"
                border.color: "#333333"
                border.width: 1
                radius: 4
                z: 100

                property int segmentIndex: -1
                property string segmentMode: "cut"

                Column {
                    id: menuCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    spacing: 1

                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: 2
                        color: modeItemMouse.containsMouse ? "#2a2a2a" : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: segmentMenu.segmentMode === "cut" ? "Mute audio only" : "Cut segment"
                            color: "#cccccc"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: modeItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var newMode = segmentMenu.segmentMode === "cut" ? "mute" : "cut"
                                timeline.removeSegmentModeChanged(segmentMenu.segmentIndex, newMode)
                                segmentMenu.visible = false
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#2a2a2a"
                    }

                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: 2
                        color: removeItemMouse.containsMouse ? "#2a2a2a" : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Remove"
                            color: "#cccccc"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: removeItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                timeline.removeSegmentRemoved(segmentMenu.segmentIndex)
                                segmentMenu.visible = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: playhead
                x: timeline.posToX(timeline.position) - 1
                width: 2
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
                radius: 1
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                property bool scrubbing: false
                property bool removingSegment: false
                property int removeStartMs: 0

                onPressed: (mouse) => {
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        removingSegment = true
                        timeline.editBegin()
                        var ms = timeline.xToMs(mouse.x)
                        removeStartMs = Math.max(timeline.inPoint, Math.min(ms, timeline.outPoint))
                        var sx = timeline.posToX(removeStartMs)
                        removePreview.x = sx
                        removePreview.width = 1
                        removePreview.visible = true
                    } else {
                        scrubbing = true
                        seekTo(mouse.x)
                    }
                }
                onPositionChanged: (mouse) => {
                    if (removingSegment) {
                        var ms = timeline.xToMs(mouse.x)
                        ms = Math.max(timeline.inPoint, Math.min(ms, timeline.outPoint))
                        timeline.seek(ms)
                        var sx = timeline.posToX(removeStartMs)
                        var ex = timeline.posToX(ms)
                        if (ex < sx) {
                            removePreview.x = ex
                            removePreview.width = sx - ex
                        } else {
                            removePreview.x = sx
                            removePreview.width = ex - sx
                        }
                    } else if (scrubbing) {
                        seekTo(mouse.x)
                    }
                }
                onReleased: (mouse) => {
                    if (removingSegment) {
                        removingSegment = false
                        removePreview.visible = false
                        var ms = timeline.xToMs(mouse.x)
                        ms = Math.max(timeline.inPoint, Math.min(ms, timeline.outPoint))
                        var startMs = Math.min(removeStartMs, ms)
                        var endMs = Math.max(removeStartMs, ms)
                        if (endMs - startMs > 0) {
                            timeline.removeSegmentAdded(startMs, endMs)
                        }
                    } else {
                        scrubbing = false
                    }
                }
                function seekTo(mx) {
                    var ms = timeline.xToMs(mx)
                    ms = Math.max(0, Math.min(ms, timeline.duration))
                    timeline.seek(ms)
                }
            }
        }

    }
}
