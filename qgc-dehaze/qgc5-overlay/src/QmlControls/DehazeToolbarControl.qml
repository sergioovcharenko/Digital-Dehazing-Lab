import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.ScreenTools

Row {
    id: root
    spacing: 4
    height: parent ? parent.height : ScreenTools.defaultFontPixelHeight * 2
    visible: QGroundControl.multiVehicleManager.activeVehicle !== null &&
             !QGroundControl.multiVehicleManager.activeVehicle.communicationLost

    readonly property var vm: QGroundControl.videoManager
    readonly property bool active: vm.dehazeRunMode !== "OFF"

    Rectangle {
        height: root.height
        width: Math.max(86, label.implicitWidth + 20)
        radius: 6
        color: root.active ? "#5535D06F" : "#334A4A4A"
        border.width: 1
        border.color: root.active ? "#35D06F" : "#A0A0A0"

        Text {
            id: label
            anchors.centerIn: parent
            text: "DEHAZING"
            color: root.active ? "#35D06F" : "white"
            font.bold: true
            font.pixelSize: Math.max(11, ScreenTools.defaultFontPixelHeight * 0.62)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (vm.dehazeRunMode === "OFF") {
                    vm.dehazeRunMode = "AUTO"
                    vm.dehazePanelOpen = true
                } else {
                    vm.dehazeRunMode = "OFF"
                    vm.dehazePanelOpen = false
                }
            }
        }
    }

    Rectangle {
        visible: root.active
        height: root.height
        width: root.height
        radius: 6
        color: vm.dehazePanelOpen ? "#5535D06F" : "#334A4A4A"
        border.width: 1
        border.color: vm.dehazePanelOpen ? "#35D06F" : "#A0A0A0"

        Text {
            anchors.centerIn: parent
            text: "⚙"
            color: "white"
            font.pixelSize: Math.max(15, ScreenTools.defaultFontPixelHeight * 0.8)
        }
        MouseArea {
            anchors.fill: parent
            onClicked: vm.dehazePanelOpen = !vm.dehazePanelOpen
        }
    }
}
