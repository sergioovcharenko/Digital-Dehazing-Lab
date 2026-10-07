import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl

Item {
    id: root
    anchors.fill: parent
    z: 900

    readonly property var vm: QGroundControl.videoManager
    readonly property bool active: vm.dehazeRunMode !== "OFF"

    function statusColor() {
        if (!active) return "#F2F2F2"
        if (vm.dehazeFps >= 27.0 && vm.dehazeFrameMs <= 37.0) return "#35D06F"
        if (vm.dehazeFps >= 20.0 && vm.dehazeFrameMs <= 50.0) return "#F2C94C"
        return "#EB5757"
    }

    Rectangle {
        id: perfBadge
        visible: QGroundControl.multiVehicleManager.activeVehicle !== null
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        width: 206
        height: 62
        radius: 9
        color: "#A016191D"
        border.width: 2
        border.color: root.statusColor()

        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.active ? (vm.dehazeAlgorithm + " · " + vm.dehazeStrength) : "DEHAZING · OFF"
                color: root.statusColor()
                font.bold: true
                font.pixelSize: 14
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.active ? (vm.dehazeFps.toFixed(1) + " FPS · " + vm.dehazeFrameMs.toFixed(0) + " ms") : "—"
                color: root.statusColor()
                font.pixelSize: 13
            }
        }
    }

    Rectangle {
        visible: vm.dehazePanelOpen && QGroundControl.multiVehicleManager.activeVehicle !== null
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12
        width: Math.min(parent.width * 0.58, 560)
        height: menuContent.implicitHeight + 24
        radius: 12
        color: "#D0191D22"
        border.width: 1
        border.color: "#66FFFFFF"

        ColumnLayout {
            id: menuContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: ["AUTO","MANUAL","OFF"]
                    Button {
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData
                        highlighted: vm.dehazeRunMode === modelData
                        onClicked: {
                            vm.dehazeRunMode = modelData
                            if (modelData === "OFF") vm.dehazePanelOpen = false
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: ["LOW","MEDIUM","HIGH"]
                    Button {
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData
                        highlighted: vm.dehazeStrength === modelData
                        enabled: vm.dehazeRunMode !== "OFF"
                        onClicked: vm.dehazeStrength = modelData
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 430 ? 3 : 2
                rowSpacing: 6
                columnSpacing: 6
                Repeater {
                    model: ["ADAPTIVE","FAST DCP","LIVE DCP","CLASSIC","DCP BALANCED","DCP STRONG","CAP","CLAHE","RETINEX"]
                    Button {
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData
                        highlighted: vm.dehazeAlgorithm === modelData
                        enabled: vm.dehazeRunMode === "MANUAL"
                        onClicked: vm.dehazeAlgorithm = modelData
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                color: root.statusColor()
                font.bold: true
                font.pixelSize: 12
                text: root.active
                    ? (vm.dehazeFps.toFixed(1) + " FPS · FRAME " + vm.dehazeFrameMs.toFixed(1) + " ms · OFFLINE GPU")
                    : "DEHAZING OFF"
            }
        }
    }
}
