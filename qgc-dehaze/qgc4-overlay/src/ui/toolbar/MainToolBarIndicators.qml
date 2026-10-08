/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.12

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0

//-------------------------------------------------------------------------
//-- Toolbar Indicators
Row {
    id:                 indicatorRow
    anchors.top:        parent.top
    anchors.bottom:     parent.bottom
    anchors.margins:    _toolIndicatorMargins
    spacing:            ScreenTools.defaultFontPixelWidth * 1.5

    property var  _activeVehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property real _toolIndicatorMargins:    ScreenTools.defaultFontPixelHeight * 0.66

    function dropMessageIndicatorTool() {
        toolIndicatorsRepeater.dropMessageIndicatorTool();
    }

    Repeater {
        id:     appRepeater
        model:  QGroundControl.corePlugin.toolBarIndicators
        Loader {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            source:             modelData
            visible:            item.showIndicator
        }
    }

    Repeater {
        id:     toolIndicatorsRepeater
        model:  _activeVehicle ? _activeVehicle.toolIndicators : []

        function dropMessageIndicatorTool() {
            for (var i=0; i<count; i++) {
                var thisTool = itemAt(i);
                if (thisTool.item.dropMessageIndicator) {
                    thisTool.item.dropMessageIndicator();
                }
            }
        }

        Loader {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            source:             modelData
            visible:            item.showIndicator
        }
    }

    Row {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: ScreenTools.defaultFontPixelWidth * 0.5
        visible: _activeVehicle

        Rectangle {
            height: parent.height
            width: ScreenTools.defaultFontPixelWidth * 13
            radius: ScreenTools.defaultFontPixelWidth * 0.6
            color: QGroundControl.videoManager.dehazeRunMode !== "OFF" ? "#5535D06F" : "#334A4A4A"
            border.width: 1
            border.color: QGroundControl.videoManager.dehazeRunMode !== "OFF" ? "#35D06F" : "#A0A0A0"

            Text {
                anchors.centerIn: parent
                text: "DEHAZING"
                color: QGroundControl.videoManager.dehazeRunMode !== "OFF" ? "#35D06F" : "white"
                font.bold: true
                font.pixelSize: ScreenTools.smallFontPointSize * 1.45
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (QGroundControl.videoManager.dehazeRunMode === "OFF") {
                        QGroundControl.videoManager.dehazeRunMode = "AUTO"
                        QGroundControl.videoManager.dehazePanelOpen = true
                    } else {
                        QGroundControl.videoManager.dehazeRunMode = "OFF"
                        QGroundControl.videoManager.dehazePanelOpen = false
                    }
                }
            }
        }

        Rectangle {
            visible: QGroundControl.videoManager.dehazeRunMode !== "OFF"
            height: parent.height
            width: parent.height
            radius: ScreenTools.defaultFontPixelWidth * 0.6
            color: QGroundControl.videoManager.dehazePanelOpen ? "#5535D06F" : "#334A4A4A"
            border.width: 1
            border.color: QGroundControl.videoManager.dehazePanelOpen ? "#35D06F" : "#A0A0A0"
            Text { anchors.centerIn: parent; text: "⚙"; color: "white"; font.pixelSize: ScreenTools.defaultFontPointSize * 1.6 }
            MouseArea {
                anchors.fill: parent
                onClicked: QGroundControl.videoManager.dehazePanelOpen = !QGroundControl.videoManager.dehazePanelOpen
            }
        }
    }

    Repeater {
        model: _activeVehicle ? _activeVehicle.modeIndicators : []
        Loader {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            source:             modelData
            visible:            item.showIndicator
        }
    }
}
