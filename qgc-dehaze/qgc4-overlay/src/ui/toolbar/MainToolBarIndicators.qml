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
import QGroundControl.Controls      1.0

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

    function hasRcRssiIndicator() {
        if (!_activeVehicle) return false;
        var indicators = _activeVehicle.toolIndicators;
        for (var i = 0; i < indicators.length; i++) {
            if (String(indicators[i]).indexOf("RCRSSIIndicator.qml") >= 0) return true;
        }
        return false;
    }

    Repeater {
        id:     appRepeater
        model:  QGroundControl.corePlugin.toolBarIndicators
        Loader {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            source:             modelData
            visible:            item && item.showIndicator &&
                                String(modelData).indexOf("GPSRTKIndicator.qml") < 0
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

        Row {
            id: indicatorSlot
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: 4
            property var item: indicatorLoader.item

            Loader {
                id: indicatorLoader
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                source: modelData
                // Hide only the crossed-out icons; preserve their internal services.
                visible: item && item.showIndicator &&
                    ["GPSIndicator.qml", "TelemetryRSSIIndicator.qml",
                     "BatteryIndicator.qml", "RemoteIDIndicator.qml",
                     "GimbalIndicator.qml"].every(function(n) {
                        return String(modelData).indexOf(n) < 0;
                    })
            }

            // Immediately right of the existing RC RSSI indicator.
            DehazeToolbarControl {
                visible: String(modelData).indexOf("RCRSSIIndicator.qml") >= 0
            }
        }
    }

    // Before vehicle connection, or for firmware without an RC RSSI indicator,
    // the DEHAZING button is still always visible.
    DehazeToolbarControl {
        visible: !indicatorRow.hasRcRssiIndicator()
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
