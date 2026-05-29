pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ezcut

Rectangle {
    id: browser
    visible: false
    color: "#aa000000"
    z: 1000

    property string mode: "open"
    property var nameFilters: ["mp4", "mkv", "avi", "mov", "webm", "ts", "flv", "wmv", "m4v", "mpg", "mpeg", "3gp"]
    property string selectedFile: ""
    property string _saveName: ""
    property string _sourceExt: ""
    property bool _searching: false
    property var pathSuggestions: []
    property int pathSuggestionIndex: -1

    signal accepted()
    signal rejected()

    DirLister {
        id: lister
        extensions: browser.mode === "open" ? browser.nameFilters : []
        onPathChanged: {
            pathEdit.text = path
            lister.filter = ""
            searchInput.text = ""
            browser._searching = false
            browser.pathSuggestions = []
            browser.pathSuggestionIndex = -1
        }
    }

    function open() {
        selectedFile = ""
        _saveName = ""
        _searching = false
        searchInput.text = ""
        lister.filter = ""
        lister.path = lister.homePath()
        visible = true
        fileView.forceActiveFocus()
    }

    function close() { visible = false }

    onVisibleChanged: {
        if (!visible) fileView.currentIndex = -1
    }

    Keys.onEscapePressed: {
        if (_searching) {
            _searching = false
            searchInput.text = ""
            lister.filter = ""
            fileView.forceActiveFocus()
        } else {
            rejected(); close()
        }
    }

    MouseArea { anchors.fill: parent; onClicked: { rejected(); close() } }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 680)
        height: Math.min(parent.height - 60, 480)
        radius: 10
        color: "#1a1a1a"
        border.color: "#2a2a2a"

        MouseArea {
            anchors.fill: parent
            onClicked: fileView.forceActiveFocus()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: browser.mode === "open" ? "Open Video" : "Save As"
                    color: "#e0e0e0"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: lister.path.split("/").pop()
                    color: "#555555"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 22; height: 22; radius: 11
                    color: closeMouse.containsMouse ? "#333333" : "transparent"

                    Canvas {
                        anchors.centerIn: parent
                        width: 8; height: 8
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = closeMouse.containsMouse ? "#e0e0e0" : "#666666"
                            ctx.lineWidth = 1.5
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(0, 0); ctx.lineTo(8, 8)
                            ctx.moveTo(8, 0); ctx.lineTo(0, 8)
                            ctx.stroke()
                        }
                        property bool _hov: closeMouse.containsMouse
                        on_HovChanged: requestPaint()
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { browser.rejected(); browser.close() }
                    }
                }
            }

            Rectangle {
                id: pathBar
                Layout.fillWidth: true
                height: 30
                radius: 4
                color: "#0e0e0e"
                border.color: pathEdit.activeFocus ? "#601d4ed8" : "#252525"

                Behavior on border.color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 4

                    PathBarButton {
                        iconType: "up"
                        onClicked: lister.path = lister.parentPath()
                    }

                    PathBarButton {
                        iconType: "home"
                        onClicked: lister.path = lister.homePath()
                    }

                    Rectangle { width: 1; height: 16; color: "#252525" }

                    TextInput {
                        id: pathEdit
                        Layout.fillWidth: true
                        color: "#b0b0b0"
                        font.pixelSize: 12
                        font.family: "monospace"
                        clip: true
                        selectByMouse: true
                        selectionColor: "#401d4ed8"
                        selectedTextColor: "#ffffff"
                        verticalAlignment: TextInput.AlignVCenter

                        property string _navigateTo: ""

                        onTextChanged: {
                            if (activeFocus && text.length > 0) {
                                browser.pathSuggestions = lister.completePath(text)
                                browser.pathSuggestionIndex = 0
                            } else {
                                browser.pathSuggestions = []
                                browser.pathSuggestionIndex = -1
                            }
                        }
                        onAccepted: {
                            if (browser.pathSuggestions.length > 0) {
                                _navigateTo = browser.pathSuggestions[browser.pathSuggestionIndex]
                                browser.pathSuggestions = []
                                browser.pathSuggestionIndex = -1
                            } else {
                                _navigateTo = text
                            }
                            lister.path = _navigateTo
                            fileView.forceActiveFocus()
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Tab && browser.pathSuggestions.length > 0) {
                                text = browser.pathSuggestions[0]
                                browser.pathSuggestions = []
                                browser.pathSuggestionIndex = -1
                                lister.path = text
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down && browser.pathSuggestions.length > 0) {
                                browser.pathSuggestionIndex = Math.min(browser.pathSuggestionIndex + 1, browser.pathSuggestions.length - 1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up && browser.pathSuggestions.length > 0) {
                                browser.pathSuggestionIndex = Math.max(browser.pathSuggestionIndex - 1, -1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                browser.pathSuggestions = []
                                browser.pathSuggestionIndex = -1
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                z: 100
                height: browser.pathSuggestions.length > 0 ? Math.min(browser.pathSuggestions.length, 6) * 24 + 4 : 0
                radius: 4
                color: "#121212"
                border.color: "#401d4ed8"
                visible: browser.pathSuggestions.length > 0 && pathEdit.activeFocus
                clip: true

                Behavior on height { NumberAnimation { duration: 80 } }

                ListView {
                    id: suggList
                    anchors.fill: parent
                    anchors.margins: 2
                    model: browser.pathSuggestions
                    currentIndex: browser.pathSuggestionIndex

                    delegate: Rectangle {
                        id: suggItem
                        width: suggList.width
                        height: 24
                        radius: 2
                        required property int index
                        required property string modelData
                        color: index === suggList.currentIndex ? "#301d4ed8" : (suggMouse.containsMouse ? "#151d4ed8" : "transparent")

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Canvas {
                                width: 10; height: 10
                                anchors.verticalCenter: parent.verticalCenter
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.fillStyle = "#60a5fa"
                                    ctx.beginPath()
                                    ctx.moveTo(0, 2)
                                    ctx.lineTo(3, 2)
                                    ctx.lineTo(4, 4)
                                    ctx.lineTo(10, 4)
                                    ctx.lineTo(10, 9)
                                    ctx.lineTo(0, 9)
                                    ctx.closePath()
                                    ctx.fill()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: suggItem.modelData.split("/").pop()
                                color: "#c0c0c0"
                                font.pixelSize: 12
                                font.family: "monospace"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    var dir = suggItem.modelData.substring(0, suggItem.modelData.lastIndexOf("/"))
                                    dir.length > 0 ? "  " + dir.replace(lister.path, "") : ""
                                }
                                color: "#444444"
                                font.pixelSize: 10
                                font.family: "monospace"
                                elide: Text.ElideMiddle
                            }
                        }

                        MouseArea {
                            id: suggMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pathEdit.text = suggItem.modelData
                                browser.pathSuggestions = []
                                browser.pathSuggestionIndex = -1
                                lister.path = suggItem.modelData
                                fileView.forceActiveFocus()
                            }
                            onEntered: browser.pathSuggestionIndex = suggItem.index
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 4
                color: "#0e0e0e"
                border.color: searchInput.activeFocus ? "#601d4ed8" : "#252525"
                visible: browser._searching

                Behavior on border.color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Canvas {
                        width: 12; height: 12
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = "#666666"
                            ctx.lineWidth = 1.5
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.arc(5, 5, 4, 0, Math.PI * 2)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(8, 8)
                            ctx.lineTo(11, 11)
                            ctx.stroke()
                        }
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: "#c0c0c0"
                        font.pixelSize: 12
                        clip: true
                        selectByMouse: true
                        selectionColor: "#401d4ed8"
                        selectedTextColor: "#ffffff"
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: {
                            lister.filter = text
                            fileView.currentIndex = -1
                        }
                        Keys.onEscapePressed: {
                            browser._searching = false
                            text = ""
                            lister.filter = ""
                            fileView.forceActiveFocus()
                        }
                        Keys.onReturnPressed: {
                            if (fileView.count > 0) {
                                fileView.currentIndex = 0
                                fileView.forceActiveFocus()
                            }
                        }
                        Keys.onDownPressed: {
                            if (fileView.count > 0) {
                                fileView.currentIndex = 0
                                fileView.forceActiveFocus()
                            }
                        }
                    }

                    Text {
                        text: lister.entries.length + " items"
                        color: "#444444"
                        font.pixelSize: 10
                    }

                    Rectangle {
                        width: 16; height: 16; radius: 8
                        color: clearMouse.containsMouse ? "#333333" : "transparent"
                        visible: searchInput.text.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "#888888"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = ""
                                lister.filter = ""
                                browser._searching = false
                                fileView.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: "#0e0e0e"
                border.color: fileView.activeFocus ? "#301d4ed8" : "#252525"

                Behavior on border.color { ColorAnimation { duration: 100 } }

                ListView {
                    id: fileView
                    anchors.fill: parent
                    anchors.margins: 2
                    model: lister.entries
                    currentIndex: -1
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    focus: true
                    keyNavigationEnabled: true

                    Keys.onReturnPressed: {
                        if (currentIndex >= 0 && currentIndex < lister.entries.length) {
                            var item = lister.entries[currentIndex]
                            if (item.isDir) {
                                lister.path = item.path
                                currentIndex = -1
                            } else {
                                browser.selectedFile = item.path
                                if (browser.mode === "open") {
                                    browser.accepted()
                                    browser.close()
                                }
                            }
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Backspace) {
                            lister.path = lister.parentPath()
                            event.accepted = true
                        } else if (event.text.length === 1 && event.text.match(/[a-zA-Z0-9._\-]/)) {
                            browser._searching = true
                            searchInput.forceActiveFocus()
                            searchInput.text = event.text
                            event.accepted = true
                        }
                    }

                    delegate: Rectangle {
                        id: fileItem
                        width: fileView.width
                        height: 28
                        radius: 2

                        required property int index
                        required property var modelData
                        color: {
                            if (fileView.currentIndex === index) return "#201d4ed8"
                            if (rowMouse.containsMouse) return "#08ffffff"
                            return "transparent"
                        }

                        Behavior on color { ColorAnimation { duration: 60 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Canvas {
                                width: 12; height: 12
                                property bool isDir: fileItem.modelData.isDir
                                onIsDirChanged: requestPaint()
                                Component.onCompleted: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    if (isDir) {
                                        ctx.fillStyle = "#60a5fa"
                                        ctx.beginPath()
                                        ctx.moveTo(0, 2)
                                        ctx.lineTo(4, 2)
                                        ctx.lineTo(5, 4)
                                        ctx.lineTo(12, 4)
                                        ctx.lineTo(12, 11)
                                        ctx.lineTo(0, 11)
                                        ctx.closePath()
                                        ctx.fill()
                                    } else {
                                        ctx.strokeStyle = "#666666"
                                        ctx.lineWidth = 1
                                        ctx.beginPath()
                                        ctx.moveTo(1, 0)
                                        ctx.lineTo(1, 12)
                                        ctx.lineTo(11, 12)
                                        ctx.lineTo(11, 3)
                                        ctx.lineTo(8, 0)
                                        ctx.closePath()
                                        ctx.stroke()
                                        ctx.beginPath()
                                        ctx.moveTo(8, 0)
                                        ctx.lineTo(8, 3)
                                        ctx.lineTo(11, 3)
                                        ctx.stroke()
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: fileItem.modelData.name
                                color: fileItem.modelData.isDir ? "#d0d0d0" : "#999999"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: !fileItem.modelData.isDir
                                text: browser.formatSize(fileItem.modelData.size)
                                color: "#444444"
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                fileView.forceActiveFocus()
                                fileView.currentIndex = index
                                if (!fileItem.modelData.isDir) {
                                    browser.selectedFile = fileItem.modelData.path
                                    if (browser.mode === "save")
                                        browser._saveName = fileItem.modelData.name
                                }
                            }
                            onDoubleClicked: {
                                if (fileItem.modelData.isDir) {
                                    lister.path = fileItem.modelData.path
                                    fileView.currentIndex = -1
                                } else {
                                    browser.selectedFile = fileItem.modelData.path
                                    if (browser.mode === "open") {
                                        browser.accepted()
                                        browser.close()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: fileView.count === 0
                        text: lister.filter !== "" ? "No matches" : "Empty"
                        color: "#444444"
                        font.pixelSize: 12
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: browser.mode === "save"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text { text: "Name:"; color: "#666666"; font.pixelSize: 12 }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 4
                        color: "#0e0e0e"
                        border.color: saveInput.activeFocus ? "#601d4ed8" : "#252525"

                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        TextInput {
                            id: saveInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#c0c0c0"
                            font.pixelSize: 12
                            selectByMouse: true
                            selectionColor: "#401d4ed8"
                            selectedTextColor: "#ffffff"
                            text: browser._saveName
                            onTextChanged: browser._saveName = text
                            onAccepted: doConfirm()
                        }
                    }

                    Text {
                        text: "." + browser._sourceExt
                        color: "#1d4ed8"
                        font.pixelSize: 12
                        font.family: "monospace"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: browser.selectedFile !== "" ? browser.selectedFile.split("/").pop() : ""
                    color: "#555555"
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }

                BrowserButton {
                    label: "Cancel"
                    onClicked: { browser.rejected(); browser.close() }
                }

                BrowserButton {
                    label: browser.mode === "open" ? "Open" : "Save"
                    accent: true
                    enabled: browser.mode === "open" ? browser.selectedFile !== ""
                           : browser._saveName.length > 0
                    onClicked: doConfirm()
                }
            }
        }
    }

    function doConfirm() {
        if (browser.mode === "save" && browser._saveName.length > 0) {
            var name = browser._saveName
            var ext = "." + browser._sourceExt
            if (name.toLowerCase().endsWith(ext)) {
                name = name.substring(0, name.length - ext.length)
            }
            browser.selectedFile = lister.joinPath(lister.path, name + ext)
        }
        if (browser.selectedFile !== "") {
            browser.accepted()
            browser.close()
        }
    }

    function formatSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(0) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(2) + " GB"
    }

    component PathBarButton : Rectangle {
        property string iconType: ""
        signal clicked()
        width: 22; height: 22; radius: 3
        color: pbMouse.containsMouse ? "#2a2a2a" : "transparent"

        Canvas {
            anchors.centerIn: parent
            width: 10; height: 10
            property string _type: parent.iconType
            property bool _hov: pbMouse.containsMouse
            on_TypeChanged: requestPaint()
            on_HovChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = _hov ? "#b0b0b0" : "#777777"
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                if (_type === "up") {
                    ctx.beginPath()
                    ctx.moveTo(2, 6); ctx.lineTo(5, 2); ctx.lineTo(8, 6)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(5, 3); ctx.lineTo(5, 10)
                    ctx.stroke()
                } else if (_type === "home") {
                    ctx.beginPath()
                    ctx.moveTo(1, 5); ctx.lineTo(5, 1); ctx.lineTo(9, 5)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(2, 5); ctx.lineTo(2, 9); ctx.lineTo(8, 9); ctx.lineTo(8, 5)
                    ctx.stroke()
                }
            }
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component BrowserButton : Rectangle {
        property string label: ""
        property bool accent: false
        signal clicked()

        width: btnLabel.width + 24
        height: 28
        radius: 5
        color: {
            if (!enabled) return "#161616"
            if (bma.pressed) return accent ? "#1e3a8a" : "#2a2a2a"
            if (bma.containsMouse) return accent ? "#1d4ed8" : "#252525"
            return accent ? "#1e40af" : "#1e1e1e"
        }
        border.color: accent ? "#1d4ed8" : "#2a2a2a"
        opacity: enabled ? 1 : 0.4

        Text {
            id: btnLabel
            anchors.centerIn: parent
            text: parent.label
            color: parent.accent ? "#ffffff" : "#b0b0b0"
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: bma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: parent.clicked()
        }
    }
}
