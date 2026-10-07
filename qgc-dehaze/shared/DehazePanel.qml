import QtQuick 2.12
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.12

Item {
    id: root
    property bool connected: false
    property string runMode: "OFF"
    property string strength: "MEDIUM"
    property string algorithm: "ADAPTIVE"
    property real fps: 0
    property real procMs: 0
    property real latencyMs: 0
    property real dropPct: 0
    property bool settingsOpen: false

    signal modeSelected(string value)
    signal strengthSelected(string value)
    signal algorithmSelected(string value)

    readonly property bool active: connected && runMode !== "OFF"
    readonly property color stateColor: !active ? "#EDEDED"
        : (fps >= 27 && procMs <= 28 && dropPct <= 1 ? "#35D06F"
        : (fps >= 20 && procMs <= 45 && dropPct <= 5 ? "#F2C94C" : "#EB5757"))

    Rectangle {
        id: badge
        visible: root.connected
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        radius: 8
        color: "#99000000"
        border.color: root.stateColor
        border.width: 2
        width: 190
        height: 58
        z: 999

        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.active ? root.algorithm + " · " + root.strength : "DEHAZING · OFF"
                color: root.stateColor
                font.bold: true
                font.pixelSize: 14
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.active ? root.fps.toFixed(1) + " FPS · " + root.procMs.toFixed(0) + " ms" : "—"
                color: root.stateColor
                font.pixelSize: 13
            }
        }
    }

    Rectangle {
        id: panel
        visible: root.connected && root.settingsOpen
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        width: Math.min(parent.width * 0.56, 520)
        height: content.implicitHeight + 24
        radius: 12
        color: "#C91B1F24"
        border.color: "#66FFFFFF"
        border.width: 1
        z: 1000

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: ["AUTO", "MANUAL", "OFF"]
                    delegate: Button {
                        text: modelData
                        Layout.fillWidth: true
                        highlighted: root.runMode === modelData
                        onClicked: root.modeSelected(modelData)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: ["LOW", "MEDIUM", "HIGH"]
                    delegate: Button {
                        text: modelData
                        Layout.fillWidth: true
                        highlighted: root.strength === modelData
                        enabled: root.runMode !== "OFF"
                        onClicked: root.strengthSelected(modelData)
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 420 ? 3 : 2
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: ["ADAPTIVE","FAST DCP","LIVE DCP","CLASSIC","DCP BALANCED","DCP STRONG","CAP","CLAHE","RETINEX"]
                    delegate: Button {
                        text: modelData
                        Layout.fillWidth: true
                        highlighted: root.algorithm === modelData
                        enabled: root.runMode === "MANUAL"
                        onClicked: root.algorithmSelected(modelData)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                color: "#DDFFFFFF"
                wrapMode: Text.WordWrap
                text: root.active
                    ? ("FPS " + root.fps.toFixed(1) + " · PROC " + root.procMs.toFixed(1) + " ms · LAT " + root.latencyMs.toFixed(0) + " ms · DROP " + root.dropPct.toFixed(1) + "%")
                    : "DEHAZING OFF"
                font.pixelSize: 12
            }
        }
    }
}
