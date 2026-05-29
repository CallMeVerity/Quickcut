import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import ezcut

Window {
    id: root
    width: 960
    height: 640
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: "E-Z Cut 0.1.3"
    color: "#0e0e0e"

    property int inPointMs: 0
    property int outPointMs: player.duration
    property var removeSegments: []
    property bool removeAudio: false
    property bool hasVideo: player.source.toString() !== ""
    property int frameDuration: processor.frameDurationMs()

    property var _undoStack: []
    property var _redoStack: []
    property bool _applyingUndo: false

    function _snapshot() {
        return {
            inPointMs: root.inPointMs,
            outPointMs: root.outPointMs,
            removeSegments: root.removeSegments.map(function(s) { return {start: s.start, end: s.end, mode: s.mode || "cut"} }),
            removeAudio: root.removeAudio
        }
    }

    function _restoreState(state) {
        root._applyingUndo = true
        root.inPointMs = state.inPointMs
        root.outPointMs = state.outPointMs
        root.removeSegments = state.removeSegments
        root.removeAudio = state.removeAudio || false
        root._applyingUndo = false
    }

    function pushUndo() {
        if (root._applyingUndo) return
        root._undoStack = root._undoStack.concat([root._snapshot()])
        if (root._undoStack.length > 100) root._undoStack = root._undoStack.slice(-100)
        root._redoStack = []
    }

    function undo() {
        if (root._undoStack.length === 0) return
        var prev = root._undoStack[root._undoStack.length - 1]
        root._undoStack = root._undoStack.slice(0, -1)
        root._redoStack = root._redoStack.concat([root._snapshot()])
        root._restoreState(prev)
    }

    function redo() {
        if (root._redoStack.length === 0) return
        var next = root._redoStack[root._redoStack.length - 1]
        root._redoStack = root._redoStack.slice(0, -1)
        root._undoStack = root._undoStack.concat([root._snapshot()])
        root._restoreState(next)
    }

    function addRemoveSegment(startMs, endMs, mode) {
        if (startMs >= endMs) return
        startMs = Math.max(startMs, root.inPointMs)
        endMs = Math.min(endMs, root.outPointMs)
        if (startMs >= endMs) return
        mode = mode || "cut"
        var segs = root.removeSegments.slice()
        segs.push({"start": startMs, "end": endMs, "mode": mode})
        segs.sort((a, b) => a.start - b.start)
        var merged = []
        for (var i = 0; i < segs.length; i++) {
            if (merged.length > 0 && segs[i].mode === merged[merged.length - 1].mode && segs[i].start <= merged[merged.length - 1].end) {
                merged[merged.length - 1].end = Math.max(merged[merged.length - 1].end, segs[i].end)
            } else {
                merged.push({"start": segs[i].start, "end": segs[i].end, "mode": segs[i].mode})
            }
        }
        root.removeSegments = merged
    }

    function computeKeepSegments() {
        var start = root.inPointMs
        var end = root.outPointMs
        if (start >= end) return []
        var keeps = [{"start": start, "end": end}]
        for (var i = 0; i < root.removeSegments.length; i++) {
            var rem = root.removeSegments[i]
            if ((rem.mode || "cut") !== "cut") continue
            var newKeeps = []
            for (var j = 0; j < keeps.length; j++) {
                var keep = keeps[j]
                if (rem.end <= keep.start || rem.start >= keep.end) {
                    newKeeps.push(keep)
                } else if (rem.start <= keep.start && rem.end >= keep.end) {
                } else if (rem.start <= keep.start) {
                    if (rem.end < keep.end) {
                        newKeeps.push({"start": rem.end, "end": keep.end})
                    }
                } else {
                    newKeeps.push({"start": keep.start, "end": rem.start})
                    if (rem.end < keep.end) {
                        newKeeps.push({"start": rem.end, "end": keep.end})
                    }
                }
            }
            keeps = newKeeps
        }
        return keeps
    }

    function computeMuteSegments() {
        var mutes = []
        for (var i = 0; i < root.removeSegments.length; i++) {
            var seg = root.removeSegments[i]
            if ((seg.mode || "cut") === "mute")
                mutes.push({"start": seg.start, "end": seg.end})
        }
        return mutes
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.BackButton) root.undo()
            else if (mouse.button === Qt.ForwardButton) root.redo()
            mouse.accepted = true
        }
    }

    VideoProcessor {
        id: processor
        onFpsChanged: root.frameDuration = frameDurationMs()
    }

    MediaPlayer {
        id: player
        videoOutput: videoOut
        audioOutput: AudioOutput {}

        property string _loadedSource: ""

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia) {
                var src = source.toString()
                if (src !== "" && src !== _loadedSource) {
                    root.inPointMs = 0
                    root.outPointMs = player.duration
                    root.removeSegments = []
                    root.removeAudio = false
                    _loadedSource = src
                    player.pause()
                    player.position = 0
                }
            }
        }
    }

    Timer {
        id: seekTimer
        interval: 50
        onTriggered: player.position = seekTimer._targetMs
        property int _targetMs: 0
    }
    function seekTo(ms) {
        if (player.playbackState === MediaPlayer.PlayingState)
            player.pause()
        seekTimer._targetMs = Math.max(0, Math.min(ms, player.duration))
        if (!seekTimer.running)
            seekTimer.start()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#000000"

            VideoOutput {
                id: videoOut
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                Component.onCompleted: {
                    if (videoSink)
                        videoSink.hardwareAccelerationEnabled = false
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: !root.hasVideo

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "qrc:/res/ezcut.png"
                    sourceSize.width: 96
                    sourceSize.height: 96
                    width: 96
                    height: 96
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.25
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        saturation: -1.0
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Open a video to begin"
                    color: "#2a2a2a"
                    font.pixelSize: 14
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (!root.hasVideo) return
                    if (player.playbackState === MediaPlayer.PlayingState)
                        player.pause()
                    else
                        player.play()
                }
            }

            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: (drop) => {
                    if (drop.urls.length > 0) {
                        var url = drop.urls[0].toString()
                        if (url.startsWith("file:///"))
                            url = url.substring(7)
                        else if (url.startsWith("file://"))
                            url = url.substring(6)
                        var ext = url.split(".").pop().toLowerCase()
                        if (["mp4", "mkv", "avi", "mov", "webm", "ts", "flv", "wmv", "m4v", "mpg", "mpeg", "3gp"].indexOf(ext) >= 0) {
                            root.inPointMs = 0
                            root.removeSegments = []
                            root.removeAudio = false
                            player.source = "file://" + url
                            processor.sourceFile = url
                        }
                    }
                }
            }
        }

        Timeline {
            Layout.fillWidth: true
            Layout.preferredHeight: root.hasVideo ? 64 : 0
            visible: root.hasVideo
            duration: player.duration
            position: player.position
            inPoint: root.inPointMs
            outPoint: root.outPointMs
            removeSegments: root.removeSegments
            waveformSource: processor.waveformPath
            onSeek: (ms) => root.seekTo(ms)
            onInPointModified: (ms) => root.inPointMs = ms
            onOutPointModified: (ms) => root.outPointMs = ms
            onRemoveSegmentAdded: (startMs, endMs) => {
                root.addRemoveSegment(startMs, endMs)
            }
            onRemoveSegmentRemoved: (index) => {
                root.pushUndo()
                var segs = root.removeSegments.slice()
                segs.splice(index, 1)
                root.removeSegments = segs
            }
            onRemoveSegmentModeChanged: (index, mode) => {
                root.pushUndo()
                var segs = root.removeSegments.slice()
                segs[index] = {"start": segs[index].start, "end": segs[index].end, "mode": mode}
                root.removeSegments = segs
            }
            onEditBegin: root.pushUndo()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "#161616"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: "#222222"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 4

                IconButton {
                    iconName: "open"
                    tooltip: "Open  (Ctrl+O)"
                    onClicked: openBrowser.open()
                }

                Separator {}

                IconButton {
                    iconName: "step-back"
                    tooltip: "Frame back  (Left)"
                    enabled: root.hasVideo
                    onClicked: player.position = Math.max(0, player.position - root.frameDuration)
                }

                IconButton {
                    iconName: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play"
                    tooltip: "Play / Pause  (Space)"
                    enabled: root.hasVideo
                    onClicked: {
                        if (player.playbackState === MediaPlayer.PlayingState)
                            player.pause()
                        else
                            player.play()
                    }
                }

                IconButton {
                    iconName: "step-forward"
                    tooltip: "Frame forward  (Right)"
                    enabled: root.hasVideo
                    onClicked: player.position = Math.min(player.duration, player.position + root.frameDuration)
                }

                Separator {}

                IconButton {
                    iconName: "mark-in"
                    tooltip: "Set in point  (I)"
                    enabled: root.hasVideo
                    onClicked: { root.pushUndo(); root.inPointMs = player.position }
                }

                IconButton {
                    iconName: "mark-out"
                    tooltip: "Set out point  (O)"
                    enabled: root.hasVideo
                    onClicked: { root.pushUndo(); root.outPointMs = player.position }
                }

                IconButton {
                    iconName: "mark-remove"
                    tooltip: root.removeSegments.length > 0 ? "Remove selection  (R / Shift+drag), " + root.removeSegments.length + " segment" + (root.removeSegments.length > 1 ? "s" : "") + " marked" : "Remove selection  (R / Shift+drag)"
                    enabled: root.hasVideo
                    onClicked: { root.pushUndo(); root.addRemoveSegment(root.inPointMs, root.outPointMs) }
                }

                IconButton {
                    iconName: "no-audio"
                    tooltip: root.removeAudio ? "Audio removed  (M)" : "Remove audio  (M)"
                    enabled: root.hasVideo
                    accent: root.removeAudio
                    onClicked: { root.pushUndo(); root.removeAudio = !root.removeAudio }
                }

                Separator {}

                TimeDisplay {
                    label: "IN"
                    timeMs: root.inPointMs
                    editable: root.hasVideo
                    onEdited: (ms) => { root.pushUndo(); root.inPointMs = Math.max(0, Math.min(ms, root.outPointMs)) }
                }

                TimeDisplay {
                    label: "NOW"
                    timeMs: player.position
                    highlight: true
                    editable: root.hasVideo
                    onEdited: (ms) => player.position = Math.max(0, Math.min(ms, player.duration))
                }

                TimeDisplay {
                    label: "OUT"
                    timeMs: root.outPointMs
                    editable: root.hasVideo
                    onEdited: (ms) => { root.pushUndo(); root.outPointMs = Math.min(player.duration, Math.max(ms, root.inPointMs)) }
                }

                Separator {}

                TimeDisplay {
                    label: "LEN"
                    timeMs: {
                        var total = root.outPointMs - root.inPointMs
                        for (var i = 0; i < root.removeSegments.length; i++) {
                            var rem = root.removeSegments[i]
                            if ((rem.mode || "cut") === "cut")
                                total -= (rem.end - rem.start)
                        }
                        return Math.max(0, total)
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: processor.status
                    color: processor.status === "Done" ? "#1d4ed8" : "#666666"
                    font.pixelSize: 11
                    visible: processor.status !== ""
                }

                Text {
                    visible: processor.fps > 0
                    text: processor.fps.toFixed(2) + " fps"
                    color: "#444444"
                    font.pixelSize: 10
                }

                IconButton {
                    iconName: "cut"
                    tooltip: processor.isVfr ? "Export cut (Ctrl+S) VFR: re-encode" : "Export cut (Ctrl+S)"
                    enabled: root.hasVideo && !processor.processing
                    accent: true
                    onClicked: saveBrowser.open()
                }
            }
        }
    }

    FileBrowser {
        id: openBrowser
        anchors.fill: parent
        mode: "open"
        onAccepted: {
            root.removeSegments = []
            root.removeAudio = false
            player.source = "file://" + selectedFile
            processor.sourceFile = selectedFile
            saveBrowser._sourceExt = selectedFile.split('.').pop().toLowerCase()
        }
    }

    FileBrowser {
        id: saveBrowser
        anchors.fill: parent
        mode: "save"
        onAccepted: {
            var keeps = root.computeKeepSegments()
            if (keeps.length === 0) return
            var mutes = root.computeMuteSegments()
            var noCuts = root.removeSegments.filter(function(s) { return (s.mode || "cut") === "cut" }).length === 0
            if (keeps.length === 1 && noCuts && mutes.length === 0 && !root.removeAudio) {
                processor.cut(keeps[0].start, keeps[0].end, selectedFile, false, [])
            } else {
                processor.cutSegments(keeps, selectedFile, root.removeAudio, mutes)
            }
        }
    }

    component Separator : Rectangle {
        Layout.fillHeight: true
        Layout.topMargin: 14
        Layout.bottomMargin: 14
        width: 1
        color: "#252525"
    }

    Shortcut { sequence: "Space"; onActivated: { if (player.playbackState === MediaPlayer.PlayingState) player.pause(); else player.play() } }
    Shortcut { sequence: "I"; onActivated: if (root.hasVideo) { root.pushUndo(); root.inPointMs = player.position } }
    Shortcut { sequence: "O"; onActivated: if (root.hasVideo) { root.pushUndo(); root.outPointMs = player.position } }
    Shortcut { sequence: "R"; onActivated: if (root.hasVideo) { root.pushUndo(); root.addRemoveSegment(root.inPointMs, root.outPointMs) } }
    Shortcut { sequence: "Ctrl+R"; onActivated: if (root.removeSegments.length > 0) { root.pushUndo(); root.removeSegments = [] } }
    Shortcut { sequence: "M"; onActivated: if (root.hasVideo) { root.pushUndo(); root.removeAudio = !root.removeAudio } }
    Shortcut { sequence: "Ctrl+Z"; onActivated: root.undo() }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: root.redo() }
    Shortcut { sequence: "Ctrl+Y"; onActivated: root.redo() }
    Shortcut { sequence: "Left"; onActivated: root.seekTo(Math.max(0, player.position - root.frameDuration)) }
    Shortcut { sequence: "Right"; onActivated: root.seekTo(Math.min(player.duration, player.position + root.frameDuration)) }
    Shortcut { sequence: "Shift+Left"; onActivated: root.seekTo(Math.max(0, player.position - 1)) }
    Shortcut { sequence: "Shift+Right"; onActivated: root.seekTo(Math.min(player.duration, player.position + 1)) }
    Shortcut { sequence: "Ctrl+Left"; onActivated: root.seekTo(Math.max(0, player.position - 1000)) }
    Shortcut { sequence: "Ctrl+Right"; onActivated: root.seekTo(Math.min(player.duration, player.position + 1000)) }
    Shortcut { sequences: ["Ctrl+O"]; onActivated: openBrowser.open() }
    Shortcut { sequences: ["Ctrl+S"]; onActivated: if (root.hasVideo && !processor.processing) saveBrowser.open() }
}
