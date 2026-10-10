import QtQuick 2.12
import QtQuick.Layouts 1.12
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.ScreenTools 1.0
import QGroundControl.Palette 1.0

Rectangle {
    id: tele
    property bool bottomMode: true
    property var v: QGroundControl.multiVehicleManager.activeVehicle
    property var bat: v && v.batteries && v.batteries.count ? v.batteries.get(0) : null
    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    function fact(i) {
        if (!v) return null;
        switch (i) {
        case 0: return v.altitudeRelative;
        case 1: return v.distanceToHome;
        case 2: return v.groundSpeed;
        case 3: return v.getFact("flightTime");
        case 4: return v.temperature ? v.temperature.temperature1 : null;
        case 5: return v.flightDistance;
        case 6: return bat ? bat.voltage : null;
        case 7: return bat ? bat.current : null;
        case 8: return v.efi ? v.efi.engineLoad : null;
        }
        return null;
    }
    function label(i) {
        var f = fact(i);
        if (f && f.shortDescription) return f.shortDescription;
        return [qsTr("Alt (Rel)"), qsTr("Distance to Home"), qsTr("Ground Speed"),
                qsTr("Flight Time"), qsTr("Temperature (1)"), qsTr("Flight Distance"),
                qsTr("Voltage"), qsTr("Current"), qsTr("Engine Load")][i];
    }
    function format(f) {
        if (!f || f.valueString === undefined) return "—";
        var val = String(f.enumOrValueString === undefined ? f.valueString : f.enumOrValueString);
        if (!val || val === "--" || val.toLowerCase() === "nan") return "—";
        return val + (f.units ? " " + f.units : "");
    }
    function reading(i) {
        if (!v) return "—";
        switch (i) {
        case 0: return format(v.altitudeRelative);
        case 1: return format(v.distanceToHome);
        case 2: return format(v.groundSpeed);
        case 3: return format(v.getFact("flightTime"));
        case 4: return v.temperature && v.temperature.telemetryAvailable ? format(v.temperature.temperature1) : "—";
        case 5: return format(v.flightDistance);
        case 6: return bat ? format(bat.voltage) : "—";
        case 7: return bat ? format(bat.current) : "—";
        case 8: return v.efi && v.efi.telemetryAvailable ? format(v.efi.engineLoad) : "—";
        }
        return "—";
    }
    color: qgcPal.window
    radius: ScreenTools.defaultFontPixelWidth / 2
    width: columns.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.5
    height: columns.implicitHeight + ScreenTools.defaultFontPixelWidth * 1.5
    DeadMouseArea { anchors.fill: parent }
    RowLayout {
        id: columns
        anchors.centerIn: parent
        spacing: ScreenTools.defaultFontPixelWidth * 1.25
        Repeater {
            model: 3
            ColumnLayout {
                property int col: index
                spacing: ScreenTools.defaultFontPixelHeight / 4
                Repeater {
                    model: 3
                    RowLayout {
                        property int fi: parent.col * 3 + index
                        spacing: ScreenTools.defaultFontPixelWidth / 4
                        QGCLabel {
                            font.pointSize: ScreenTools.smallFontPointSize
                            text: tele.label(fi)
                        }
                        QGCLabel {
                            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 7
                            horizontalAlignment: Text.AlignRight
                            font.pointSize: ScreenTools.defaultFontPointSize
                            text: tele.reading(fi)
                        }
                    }
                }
            }
        }
    }
}

