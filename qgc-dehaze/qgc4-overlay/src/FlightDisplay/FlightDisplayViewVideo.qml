/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick                          2.11
import QtQuick.Controls                 2.4
import QtQuick.Window                   2.11

import QGroundControl                   1.0
import QGroundControl.FlightDisplay     1.0
import QGroundControl.FlightMap         1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.Vehicle           1.0
import QGroundControl.Controllers       1.0

Item {
    id:     root
    clip:   true

    property bool useSmallFont: true
    property int  _dehazeFrameCounter: 0
    property real _dehazeFps: 0
    property real _dehazeFrameMs: 0

    Connections {
        target: root.Window.window
        onFrameSwapped: root._dehazeFrameCounter++
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var instantFps = root._dehazeFrameCounter
            root._dehazeFps = root._dehazeFps > 0 ? (root._dehazeFps * 0.55 + instantFps * 0.45) : instantFps
            root._dehazeFrameMs = root._dehazeFps > 0.1 ? (1000.0 / root._dehazeFps) : 0
            root._dehazeFrameCounter = 0
        }
    }

    property double _ar:                QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue > 0
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    property int    _fitMode:           QGroundControl.settingsManager.videoSettings.videoFit.rawValue

    function getWidth() {
        return videoBackground.getWidth()
    }
    function getHeight() {
        return videoBackground.getHeight()
    }

    property double _thermalHeightFactor: 0.85 //-- TODO

        Image {
            id:             noVideo
            anchors.fill:   parent
            source:         "/res/NoVideoBackground.jpg"
            fillMode:       Image.PreserveAspectCrop
            visible:        !(QGroundControl.videoManager.decoding)

            Rectangle {
                anchors.centerIn:   parent
                width:              noVideoLabel.contentWidth + ScreenTools.defaultFontPixelHeight
                height:             noVideoLabel.contentHeight + ScreenTools.defaultFontPixelHeight
                radius:             ScreenTools.defaultFontPixelWidth / 2
                color:              "black"
                opacity:            0.5
            }

            QGCLabel {
                id:                 noVideoLabel
                text:               QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue ? qsTr("WAITING FOR VIDEO") : qsTr("VIDEO DISABLED")
                font.family:        ScreenTools.demiboldFontFamily
                color:              "white"
                font.pointSize:     useSmallFont ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
                anchors.centerIn:   parent
            }
        }

    Rectangle {
        id:             videoBackground
        anchors.fill:   parent
        color:          "black"
        visible:        QGroundControl.videoManager.decoding
        function getWidth() {
            //-- Fit Width or Stretch
            if(_fitMode === 0 || _fitMode === 2) {
                return parent.width
            }
            //-- Fit Height
            return _ar != 0.0 ? parent.height * _ar : parent.width
        }
        function getHeight() {
            //-- Fit Height or Stretch
            if(_fitMode === 1 || _fitMode === 2) {
                return parent.height
            }
            //-- Fit Width
            return _ar != 0.0 ? parent.width * (1 / _ar) : parent.height
        }
        Component {
            id: videoBackgroundComponent

            Item {
                id: processedVideoLayer

                function algorithmIndex(name) {
                    switch (name) {
                    case "ADAPTIVE": return 1
                    case "FAST DCP": return 2
                    case "LIVE DCP": return 3
                    case "CLASSIC": return 4
                    case "DCP BALANCED": return 5
                    case "DCP STRONG": return 6
                    case "CAP": return 7
                    case "CLAHE": return 8
                    case "RETINEX": return 9
                    default: return 1
                    }
                }

                function strengthValue(name) {
                    if (name === "LOW") return 0.35
                    if (name === "HIGH") return 1.0
                    return 0.65
                }

                QGCVideoBackground {
                    id: videoContent
                    objectName: "videoContent"
                    anchors.fill: parent
                }

                ShaderEffectSource {
                    id: videoTexture
                    anchors.fill: videoContent
                    sourceItem: videoContent
                    hideSource: dehazeEffect.visible
                    live: true
                    recursive: false
                    smooth: true
                    visible: false
                }

                ShaderEffect {
                    id: dehazeEffect
                    anchors.fill: parent
                    visible: QGroundControl.videoManager.dehazeRunMode !== "OFF"
                    property variant source: videoTexture
                    property real dehazeMode: QGroundControl.videoManager.dehazeRunMode === "AUTO" ? 1.0 : processedVideoLayer.algorithmIndex(QGroundControl.videoManager.dehazeAlgorithm)
                    property real dehazeStrength: QGroundControl.videoManager.dehazeRunMode === "AUTO" ? 0.72 : processedVideoLayer.strengthValue(QGroundControl.videoManager.dehazeStrength)
                    property vector2d texel: Qt.vector2d(1.0 / Math.max(width, 1.0), 1.0 / Math.max(height, 1.0))
                    fragmentShader: "varying highp vec2 qt_TexCoord0;\nuniform sampler2D source;\nuniform lowp float qt_Opacity;\nuniform highp float dehazeMode;\nuniform highp float dehazeStrength;\nuniform highp vec2 texel;\nhighp float luma(highp vec3 c){return dot(c,vec3(0.299,0.587,0.114));}\nhighp float dark3(highp vec3 c){return min(c.r,min(c.g,c.b));}\nhighp vec3 blur9(highp vec2 uv){highp vec2 t=texel*2.0; highp vec3 c=texture2D(source,uv).rgb*0.28; c+=texture2D(source,uv+vec2(t.x,0.0)).rgb*0.12; c+=texture2D(source,uv-vec2(t.x,0.0)).rgb*0.12; c+=texture2D(source,uv+vec2(0.0,t.y)).rgb*0.12; c+=texture2D(source,uv-vec2(0.0,t.y)).rgb*0.12; c+=texture2D(source,uv+t).rgb*0.06; c+=texture2D(source,uv-t).rgb*0.06; c+=texture2D(source,uv+vec2(t.x,-t.y)).rgb*0.06; c+=texture2D(source,uv+vec2(-t.x,t.y)).rgb*0.06; return c;}\nhighp float localDark(highp vec2 uv){highp vec2 t=texel*2.5; highp float d=dark3(texture2D(source,uv).rgb); d=min(d,dark3(texture2D(source,uv+vec2(t.x,0.0)).rgb)); d=min(d,dark3(texture2D(source,uv-vec2(t.x,0.0)).rgb)); d=min(d,dark3(texture2D(source,uv+vec2(0.0,t.y)).rgb)); d=min(d,dark3(texture2D(source,uv-vec2(0.0,t.y)).rgb)); return d;}\nhighp vec3 dcp(highp vec3 c, highp float d, highp float omega, highp float ft){highp vec3 A=vec3(0.92,0.94,0.96); highp float t=clamp(1.0-omega*d,ft,1.0); return clamp((c-A)/t+A,0.0,1.0);}\nvoid main(){highp vec4 src=texture2D(source,qt_TexCoord0); highp vec3 c=src.rgb; highp float s=clamp(dehazeStrength,0.0,1.0); highp vec3 b=blur9(qt_TexCoord0); highp float y=luma(c); highp float d=localDark(qt_TexCoord0); highp vec3 o=c;\nif(dehazeMode<1.5){highp float haze=clamp(d*1.25+(1.0-abs(y-0.5)*2.0)*0.15,0.0,1.0); highp vec3 clear=dcp(c,d,0.68+0.22*s,0.32-0.08*s); highp vec3 detail=c+(c-b)*(0.35+0.65*s); o=mix(c,mix(clear,detail,0.35),clamp(haze*(0.45+0.55*s),0.0,1.0));}\nelse if(dehazeMode<2.5){o=dcp(c,d,0.62+0.18*s,0.36-0.06*s);}\nelse if(dehazeMode<3.5){highp vec3 r=dcp(c,d,0.70+0.18*s,0.32-0.07*s); o=mix(r,r+(r-b)*0.22*s,0.75);}\nelse if(dehazeMode<4.5){highp float ctr=1.08+0.22*s; o=(c-0.5)*ctr+0.5; o=pow(max(o,vec3(0.0)),vec3(0.96-0.08*s));}\nelse if(dehazeMode<5.5){o=dcp(c,d,0.78+0.12*s,0.28-0.05*s);}\nelse if(dehazeMode<6.5){o=dcp(c,d,0.88+0.08*s,0.20-0.05*s); o+=(o-b)*(0.25+0.30*s);}\nelse if(dehazeMode<7.5){highp float mx=max(c.r,max(c.g,c.b)); highp float mn=min(c.r,min(c.g,c.b)); highp float sat=mx>0.001?(mx-mn)/mx:0.0; highp float dep=max(0.0,0.121779+0.959710*mx-0.780245*sat); highp float t=clamp(exp(-(0.70+0.65*s)*dep),0.25,1.0); highp vec3 A=vec3(0.94); o=(c-A)/t+A;}\nelse if(dehazeMode<8.5){highp float ly=luma(b); highp float gain=1.0+(0.45+0.75*s)*(0.55-ly); o=c*gain+(c-b)*(0.30+0.55*s);}\nelse {highp vec3 illum=max(b,vec3(0.035)); highp vec3 ret=log(max(c,vec3(0.003)))-log(illum); ret=ret*(0.22+0.10*s)+0.52; o=mix(c,ret,0.55+0.30*s);}\nhighp float hi=smoothstep(0.76,1.0,y); o=mix(o,c,hi*(0.35+0.25*(1.0-s))); highp float oy=luma(o); o=mix(vec3(oy),o,0.93); gl_FragColor=vec4(clamp(o,0.0,1.0),src.a)*qt_Opacity;}"
                }

                Connections {
                    target: QGroundControl.videoManager
                    onImageFileChanged: {
                        processedVideoLayer.grabToImage(function(result) {
                            if (!result.saveToFile(QGroundControl.videoManager.imageFile)) {
                                console.error("Error capturing processed video frame")
                            }
                        })
                    }
                }

                Rectangle { color: Qt.rgba(1,1,1,0.5); height: parent.height; width: 1; x: parent.width * 0.33; visible: _showGrid && !QGroundControl.videoManager.fullScreen }
                Rectangle { color: Qt.rgba(1,1,1,0.5); height: parent.height; width: 1; x: parent.width * 0.66; visible: _showGrid && !QGroundControl.videoManager.fullScreen }
                Rectangle { color: Qt.rgba(1,1,1,0.5); width: parent.width; height: 1; y: parent.height * 0.33; visible: _showGrid && !QGroundControl.videoManager.fullScreen }
                Rectangle { color: Qt.rgba(1,1,1,0.5); width: parent.width; height: 1; y: parent.height * 0.66; visible: _showGrid && !QGroundControl.videoManager.fullScreen }
            }
        }
        Loader {
            // GStreamer is causing crashes on Lenovo laptop OpenGL Intel drivers. In order to workaround this
            // we don't load a QGCVideoBackground object when video is disabled. This prevents any video rendering
            // code from running. Setting QGCVideoBackground.receiver = null does not work to prevent any
            // video OpenGL from being generated. Hence the Loader to completely remove it.
            height:             parent.getHeight()
            width:              parent.getWidth()
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.decoding
            sourceComponent:    videoBackgroundComponent

            property bool videoDisabled: QGroundControl.settingsManager.videoSettings.videoSource.rawValue === QGroundControl.settingsManager.videoSettings.disabledVideoSource
        }

        //-- Thermal Image
        Item {
            id:                 thermalItem
            width:              height * QGroundControl.videoManager.thermalAspectRatio
            height:             _camera ? (_camera.thermalMode === QGCCameraControl.THERMAL_FULL ? parent.height : (_camera.thermalMode === QGCCameraControl.THERMAL_PIP ? ScreenTools.defaultFontPixelHeight * 12 : parent.height * _thermalHeightFactor)) : 0
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.hasThermal && _camera.thermalMode !== QGCCameraControl.THERMAL_OFF
            function pipOrNot() {
                if(_camera) {
                    if(_camera.thermalMode === QGCCameraControl.THERMAL_PIP) {
                        anchors.centerIn    = undefined
                        anchors.top         = parent.top
                        anchors.topMargin   = mainWindow.header.height + (ScreenTools.defaultFontPixelHeight * 0.5)
                        anchors.left        = parent.left
                        anchors.leftMargin  = ScreenTools.defaultFontPixelWidth * 12
                    } else {
                        anchors.top         = undefined
                        anchors.topMargin   = undefined
                        anchors.left        = undefined
                        anchors.leftMargin  = undefined
                        anchors.centerIn    = parent
                    }
                }
            }
            Connections {
                target:                 _camera
                onThermalModeChanged:   thermalItem.pipOrNot()
            }
            onVisibleChanged: {
                thermalItem.pipOrNot()
            }
            QGCVideoBackground {
                id:             thermalVideo
                objectName:     "thermalVideo"
                anchors.fill:   parent
                receiver:       QGroundControl.videoManager.thermalVideoReceiver
                opacity:        _camera ? (_camera.thermalMode === QGCCameraControl.THERMAL_BLEND ? _camera.thermalOpacity / 100 : 1.0) : 0
            }
        }
        //-- Zoom
        PinchArea {
            id:             pinchZoom
            enabled:        _hasZoom
            anchors.fill:   parent
            onPinchStarted: pinchZoom.zoom = 0
            onPinchUpdated: {
                if(_hasZoom) {
                    var z = 0
                    if(pinch.scale < 1) {
                        z = Math.round(pinch.scale * -10)
                    } else {
                        z = Math.round(pinch.scale)
                    }
                    if(pinchZoom.zoom != z) {
                        _camera.stepZoom(z)
                    }
                }
            }
            property int zoom: 0
        }
    }
    Rectangle {
        id: dehazePerfBadge
        visible: _connected
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
        width: ScreenTools.defaultFontPixelWidth * 26
        height: ScreenTools.defaultFontPixelHeight * 3.1
        radius: ScreenTools.defaultFontPixelWidth
        color: "#A016191D"
        border.width: 2
        border.color: QGroundControl.videoManager.dehazeRunMode === "OFF" ? "white" :
                      (root._dehazeFps >= 27 ? "#35D06F" : (root._dehazeFps >= 20 ? "#F2C94C" : "#EB5757"))

        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: QGroundControl.videoManager.dehazeRunMode === "OFF" ? "DEHAZING · OFF" :
                      QGroundControl.videoManager.dehazeAlgorithm + " · " + QGroundControl.videoManager.dehazeStrength
                color: parent.parent.border.color
                font.bold: true
                font.pixelSize: ScreenTools.smallFontPointSize * 1.6
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: QGroundControl.videoManager.dehazeRunMode === "OFF" ? "GPU LOCAL" :
                      root._dehazeFps.toFixed(1) + " FPS · " + root._dehazeFrameMs.toFixed(0) + " ms"
                color: parent.parent.border.color
                font.pixelSize: ScreenTools.smallFontPointSize * 1.45
            }
        }
    }

    Rectangle {
        id: dehazePanel
        visible: _connected && QGroundControl.videoManager.dehazePanelOpen
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
        width: Math.min(parent.width * 0.62, ScreenTools.defaultFontPixelWidth * 70)
        height: ScreenTools.defaultFontPixelHeight * 20
        radius: ScreenTools.defaultFontPixelWidth
        color: "#D0191D22"
        border.width: 1
        border.color: "#66FFFFFF"
        z: 1000

        property real gap: ScreenTools.defaultFontPixelWidth * 0.7

        Column {
            anchors.fill: parent
            anchors.margins: dehazePanel.gap
            spacing: dehazePanel.gap

            Row {
                width: parent.width
                spacing: dehazePanel.gap
                Repeater {
                    model: ["AUTO","MANUAL","OFF"]
                    Rectangle {
                        width: (dehazePanel.width - dehazePanel.gap * 4) / 3
                        height: ScreenTools.defaultFontPixelHeight * 2.4
                        radius: ScreenTools.defaultFontPixelWidth * 0.6
                        color: QGroundControl.videoManager.dehazeRunMode === modelData ? "#5535D06F" : "#333B4046"
                        border.width: 1
                        border.color: QGroundControl.videoManager.dehazeRunMode === modelData ? "#35D06F" : "#808080"
                        Text { anchors.centerIn: parent; text: modelData; color: "white"; font.bold: true }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                QGroundControl.videoManager.dehazeRunMode = modelData
                                if (modelData === "OFF") QGroundControl.videoManager.dehazePanelOpen = false
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: dehazePanel.gap
                Repeater {
                    model: ["LOW","MEDIUM","HIGH"]
                    Rectangle {
                        width: (dehazePanel.width - dehazePanel.gap * 4) / 3
                        height: ScreenTools.defaultFontPixelHeight * 2.2
                        radius: ScreenTools.defaultFontPixelWidth * 0.6
                        opacity: QGroundControl.videoManager.dehazeRunMode === "OFF" ? 0.45 : 1
                        color: QGroundControl.videoManager.dehazeStrength === modelData ? "#5535D06F" : "#333B4046"
                        border.width: 1
                        border.color: QGroundControl.videoManager.dehazeStrength === modelData ? "#35D06F" : "#808080"
                        Text { anchors.centerIn: parent; text: modelData; color: "white"; font.bold: true }
                        MouseArea {
                            anchors.fill: parent
                            enabled: QGroundControl.videoManager.dehazeRunMode !== "OFF"
                            onClicked: QGroundControl.videoManager.dehazeStrength = modelData
                        }
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 3
                spacing: dehazePanel.gap
                Repeater {
                    model: ["ADAPTIVE","FAST DCP","LIVE DCP","CLASSIC","DCP BALANCED","DCP STRONG","CAP","CLAHE","RETINEX"]
                    Rectangle {
                        width: (dehazePanel.width - dehazePanel.gap * 4) / 3
                        height: ScreenTools.defaultFontPixelHeight * 2.35
                        radius: ScreenTools.defaultFontPixelWidth * 0.6
                        opacity: QGroundControl.videoManager.dehazeRunMode === "MANUAL" ? 1 : 0.55
                        color: QGroundControl.videoManager.dehazeAlgorithm === modelData ? "#5535D06F" : "#333B4046"
                        border.width: 1
                        border.color: QGroundControl.videoManager.dehazeAlgorithm === modelData ? "#35D06F" : "#808080"
                        Text { anchors.centerIn: parent; text: modelData; color: "white"; font.bold: true; font.pixelSize: ScreenTools.smallFontPointSize * 1.25 }
                        MouseArea {
                            anchors.fill: parent
                            enabled: QGroundControl.videoManager.dehazeRunMode === "MANUAL"
                            onClicked: QGroundControl.videoManager.dehazeAlgorithm = modelData
                        }
                    }
                }
            }
        }
    }

}
