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

                property var vm: QGroundControl.videoManager
                property bool dehazeActive: vm.dehazeRunMode !== "OFF"

                QGCVideoBackground {
                    id: rawVideo
                    objectName: "videoContent"
                    anchors.fill: parent

                    Connections {
                        target: QGroundControl.videoManager
                        function onImageFileChanged() {
                            processedVideoLayer.grabToImage(function(result) {
                                if (!result.saveToFile(QGroundControl.videoManager.imageFile)) {
                                    console.error("Error capturing video frame")
                                }
                            })
                        }
                    }
                }

                ShaderEffectSource {
                    id: videoTexture
                    sourceItem: rawVideo
                    live: true
                    recursive: false
                    hideSource: processedVideoLayer.dehazeActive
                    visible: false
                }

                ShaderEffect {
                    id: dehazeEffect
                    anchors.fill: parent
                    visible: processedVideoLayer.dehazeActive

                    property variant source: videoTexture
                    property real strength: {
                        if (vm.dehazeRunMode === "AUTO") return 0.72
                        if (vm.dehazeStrength === "LOW") return 0.35
                        if (vm.dehazeStrength === "HIGH") return 1.0
                        return 0.65
                    }
                    property real mode: {
                        if (vm.dehazeRunMode === "AUTO") return 1.0
                        if (vm.dehazeAlgorithm === "ADAPTIVE") return 1.0
                        if (vm.dehazeAlgorithm === "FAST DCP") return 2.0
                        if (vm.dehazeAlgorithm === "LIVE DCP") return 3.0
                        if (vm.dehazeAlgorithm === "CLASSIC") return 4.0
                        if (vm.dehazeAlgorithm === "DCP BALANCED") return 5.0
                        if (vm.dehazeAlgorithm === "DCP STRONG") return 6.0
                        if (vm.dehazeAlgorithm === "CAP") return 7.0
                        if (vm.dehazeAlgorithm === "CLAHE") return 8.0
                        if (vm.dehazeAlgorithm === "RETINEX") return 9.0
                        return 1.0
                    }

                    fragmentShader: "
                        varying highp vec2 qt_TexCoord0;
                        uniform sampler2D source;
                        uniform lowp float qt_Opacity;
                        uniform highp float strength;
                        uniform highp float mode;

                        highp float lum(highp vec3 c) {
                            return dot(c, vec3(0.299, 0.587, 0.114));
                        }

                        highp float darkAt(highp vec2 uv) {
                            highp vec2 d = vec2(0.0017, 0.0017);
                            highp vec3 c0 = texture2D(source, uv).rgb;
                            highp vec3 c1 = texture2D(source, uv + vec2(d.x, 0.0)).rgb;
                            highp vec3 c2 = texture2D(source, uv - vec2(d.x, 0.0)).rgb;
                            highp vec3 c3 = texture2D(source, uv + vec2(0.0, d.y)).rgb;
                            highp vec3 c4 = texture2D(source, uv - vec2(0.0, d.y)).rgb;
                            highp float m0 = min(c0.r, min(c0.g, c0.b));
                            highp float m1 = min(c1.r, min(c1.g, c1.b));
                            highp float m2 = min(c2.r, min(c2.g, c2.b));
                            highp float m3 = min(c3.r, min(c3.g, c3.b));
                            highp float m4 = min(c4.r, min(c4.g, c4.b));
                            return min(m0, min(m1, min(m2, min(m3, m4))));
                        }

                        highp vec3 recoverDcp(highp vec3 c, highp float power, highp float floorT) {
                            highp float dc = darkAt(qt_TexCoord0);
                            highp float t = clamp(1.0 - power * dc, floorT, 1.0);
                            highp vec3 A = vec3(0.94, 0.95, 0.97);
                            return clamp((c - A) / t + A, 0.0, 1.0);
                        }

                        void main() {
                            highp vec2 uv = qt_TexCoord0;
                            highp vec3 c = texture2D(source, uv).rgb;
                            highp vec3 outc = c;
                            highp float s = clamp(strength, 0.0, 1.0);
                            highp float y = lum(c);
                            highp float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
                            highp float sky = smoothstep(0.72, 0.98, y) * (1.0 - smoothstep(0.10, 0.35, sat));
                            highp float guard = 1.0 - 0.72 * sky;

                            if (mode < 1.5) {
                                highp vec3 dcp = recoverDcp(c, 0.72 + 0.20*s, 0.30 - 0.08*s);
                                highp vec3 ctr = clamp((c - 0.5) * (1.08 + 0.22*s) + 0.5, 0.0, 1.0);
                                outc = mix(c, mix(ctr, dcp, 0.60), (0.52 + 0.38*s) * guard);
                            } else if (mode < 2.5) {
                                outc = mix(c, recoverDcp(c, 0.70 + 0.15*s, 0.34 - 0.05*s), (0.55 + 0.30*s) * guard);
                            } else if (mode < 3.5) {
                                outc = mix(c, recoverDcp(c, 0.78 + 0.16*s, 0.30 - 0.05*s), (0.60 + 0.30*s) * guard);
                            } else if (mode < 4.5) {
                                highp vec3 classic = clamp((c - vec3(0.46)) * (1.10 + 0.24*s) + vec3(0.46), 0.0, 1.0);
                                classic = pow(classic, vec3(0.94));
                                outc = mix(c, classic, (0.55 + 0.34*s) * guard);
                            } else if (mode < 5.5) {
                                outc = mix(c, recoverDcp(c, 0.82 + 0.12*s, 0.27 - 0.04*s), (0.65 + 0.28*s) * guard);
                            } else if (mode < 6.5) {
                                outc = mix(c, recoverDcp(c, 0.91 + 0.07*s, 0.20 - 0.03*s), (0.75 + 0.22*s) * guard);
                            } else if (mode < 7.5) {
                                highp float mx = max(c.r, max(c.g, c.b));
                                highp float mn = min(c.r, min(c.g, c.b));
                                highp float saturation = mx > 0.001 ? (mx - mn) / mx : 0.0;
                                highp float depth = max(0.0, 0.121779 + 0.959710 * mx - 0.780245 * saturation);
                                highp float t = clamp(exp(-(0.85 + 0.45*s) * depth), 0.28, 1.0);
                                highp vec3 A = vec3(0.94, 0.95, 0.97);
                                highp vec3 cap = clamp((c - A) / t + A, 0.0, 1.0);
                                outc = mix(c, cap, (0.58 + 0.32*s) * guard);
                            } else if (mode < 8.5) {
                                highp vec3 local = clamp((c - vec3(y)) * (1.20 + 0.45*s) + vec3(smoothstep(0.0, 1.0, y)), 0.0, 1.0);
                                outc = mix(c, local, (0.50 + 0.38*s) * guard);
                            } else {
                                highp vec3 ret = log(vec3(1.0) + (4.0 + 3.0*s) * c) / log(5.0 + 3.0*s);
                                ret = clamp((ret - 0.5) * (1.05 + 0.18*s) + 0.5, 0.0, 1.0);
                                outc = mix(c, ret, (0.48 + 0.38*s) * guard);
                            }

                            highp float oy = lum(outc);
                            if (oy > 0.94) {
                                outc *= 0.94 / max(oy, 0.001);
                            }
                            gl_FragColor = vec4(outc, 1.0) * qt_Opacity;
                        }
                    "
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
    DehazePanel { anchors.fill: parent; visible: _connected }

}
