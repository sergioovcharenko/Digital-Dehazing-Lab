import QtQuick 2.12
import QtQuick.Layouts 1.12
import QGroundControl 1.0
import QGroundControl.Controls 1.0

Rectangle {
    id: tele
    property bool bottomMode: true
    property var v: QGroundControl.multiVehicleManager.activeVehicle
    property var bat: v && v.batteries && v.batteries.count ? v.batteries.get(0) : null
    function format(f) {
        if (!f || f.valueString === undefined) return "—";
        var val = String(f.valueString);
        if (!val || val === "--" || val === "nan") return "—";
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
    color: "#C0191D22"
    border.color: "#557F8790"
    border.width: 1
    radius: 6
    width: columns.implicitWidth + 24
    height: columns.implicitHeight + 16
    DeadMouseArea { anchors.fill: parent }
    RowLayout {
        id: columns
        anchors.centerIn: parent
        spacing: 18
        Repeater {
            model: 3
            ColumnLayout {
                property int col: index
                spacing: 7
                Repeater {
                    model: 3
                    RowLayout {
                        property int fi: parent.col * 3 + index
                        spacing: 6
                        Text {
                            color: "#DDDDDD"
                            font.pixelSize: 13
                            text: ["Alt Rel", "Home Dist", "Ground Speed",
                                   "Flight Time", "Temperature (1)", "Flight Distance",
                                   "Voltage", "Current", "EngineLoad"][fi]
                        }
                        Text {
                            Layout.minimumWidth: 55
                            horizontalAlignment: Text.AlignRight
                            color: "white"
                            font.pixelSize: 13
                            font.bold: true
                            text: tele.reading(fi)
                        }
                    }
                }
            }
        }
    }
}
