import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.12
import QGroundControl 1.0

// Responsive settings popup. Keep the HUD, compass and video geometry untouched.
Item {
    id: root
    anchors.fill: parent
    property var vm: QGroundControl.videoManager
    property bool active: vm.dehazeRunMode !== "OFF"

    // Popup is attached to the window overlay, rather than the video Item.
    // It stays above QGC instruments and remains usable on smaller tablets.
    Popup {
        id: settingsPopup
        parent: Overlay.overlay
        visible: vm.dehazePanelOpen && root.active
        modal: true
        dim: false
        focus: true
        z: 10000
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 12

        width: Math.min(450, Math.max(260, parent ? parent.width - 24 : 450))
        height: Math.min(menuBody.implicitHeight + topHeading.height + 38,
                         Math.max(180, parent ? parent.height - 36 : 500))
        x: parent ? Math.max(12, (parent.width - width) / 2) : 12
        y: parent ? Math.max(12, (parent.height - height) / 2) : 12

        background: Rectangle {
            color: "#F0191D22"
            radius: 10
            border.width: 1
            border.color: "#809DA6B0"
        }

        onClosed: {
            if (vm.dehazePanelOpen)
                vm.dehazePanelOpen = false
        }

        contentItem: Column {
            spacing: 8
            Row {
                id: topHeading
                width: parent.width
                height: 38
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DEHAZING"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                }
                Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 36
                    text: "✕"
                    onClicked: vm.dehazePanelOpen = false
                }
            }
            Flickable {
                id: scrollingMenu
                width: parent.width
                height: parent.height - topHeading.height - parent.spacing
                contentWidth: width
                contentHeight: menuBody.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                ColumnLayout {
                    id: menuBody
                    width: scrollingMenu.width
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: ["AUTO", "MANUAL", "OFF"]
                            Button {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                text: modelData
                                font.pixelSize: 13
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
                        spacing: 4
                        Repeater {
                            model: ["LOW", "MEDIUM", "HIGH"]
                            Button {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                text: modelData
                                font.pixelSize: 13
                                highlighted: vm.dehazeStrength === modelData
                                enabled: root.active
                                onClicked: vm.dehazeStrength = modelData
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: scrollingMenu.width >= 360 ? 3 : 2
                        rowSpacing: 4
                        columnSpacing: 4
                        Repeater {
                            model: ["ADAPTIVE", "FAST DCP", "LIVE DCP",
                                    "CLASSIC", "DCP BALANCED", "DCP STRONG",
                                    "CAP", "CLAHE", "RETINEX"]
                            Button {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                font.pixelSize: 12
                                text: modelData
                                highlighted: vm.dehazeAlgorithm === modelData
                                enabled: vm.dehazeRunMode === "MANUAL"
                                onClicked: vm.dehazeAlgorithm = modelData
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                        color: "#35D06F"
                        text: vm.dehazeRunMode + " · " + vm.dehazeStrength + " · " + vm.dehazeAlgorithm
                    }
                }
            }
        }
    }
}
