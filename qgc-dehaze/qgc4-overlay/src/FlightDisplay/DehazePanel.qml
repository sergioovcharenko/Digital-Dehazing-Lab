import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.12
import QGroundControl 1.0

Item {
    id: root
    anchors.fill: parent
    z: 900
    property var vm: QGroundControl.videoManager
    property bool active: vm.dehazeRunMode !== "OFF"

    Rectangle {
        visible: QGroundControl.multiVehicleManager.activeVehicle !== null
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        width: 220
        height: 58
        radius: 8
        color: "#B0181B1F"
        border.width: 1
        border.color: root.active ? "#35D06F" : "#AAAAAA"
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.active ? (vm.dehazeAlgorithm + " · " + vm.dehazeStrength) : "DEHAZING · OFF"
                color: root.active ? "#35D06F" : "white"
                font.bold: true
                font.pixelSize: 14
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.active ? "GPU · OFFLINE · QGC 4.4" : "VIDEO BYPASS"
                color: "#DDDDDD"
                font.pixelSize: 12
            }
        }
    }

    Rectangle {
        visible: vm.dehazePanelOpen && QGroundControl.multiVehicleManager.activeVehicle !== null
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12
        width: Math.min(parent.width * 0.62, 560)
        height: menuContent.implicitHeight + 24
        radius: 10
        color: "#DD191D22"
        border.width: 1
        border.color: "#66FFFFFF"

        ColumnLayout {
            id: menuContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: ["AUTO","MANUAL","OFF"]
                    Button {
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
                color: root.active ? "#35D06F" : "#DDDDDD"
                font.bold: true
                font.pixelSize: 12
                text: root.active ? ("DEHAZING · " + vm.dehazeRunMode + " · " + vm.dehazeStrength + " · " + vm.dehazeAlgorithm) : "DEHAZING OFF"
            }
        }
    }
}
