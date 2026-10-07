/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QElapsedTimer>
#include <QtCore/QRunnable>
#include <QtCore/QSize>
// #include <QtQmlIntegration/QtQmlIntegration>

Q_DECLARE_LOGGING_CATEGORY(VideoManagerLog)

class QQuickWindow;
class FinishVideoInitialization;
class SubtitleWriter;
class Vehicle;
class VideoReceiver;
class VideoSettings;

class VideoManager : public QObject
{
    Q_OBJECT
    // QML_ELEMENT
    // QML_UNCREATABLE("")
    Q_MOC_INCLUDE("Vehicle.h")
    Q_PROPERTY(bool     gstreamerEnabled        READ gstreamerEnabled                           CONSTANT)
    Q_PROPERTY(bool     qtmultimediaEnabled     READ qtmultimediaEnabled                        CONSTANT)
    Q_PROPERTY(bool     uvcEnabled              READ uvcEnabled                                 CONSTANT)
    Q_PROPERTY(bool     autoStreamConfigured    READ autoStreamConfigured                       NOTIFY autoStreamConfiguredChanged)
    Q_PROPERTY(bool     decoding                READ decoding                                   NOTIFY decodingChanged)
    Q_PROPERTY(bool     fullScreen              READ fullScreen             WRITE setfullScreen NOTIFY fullScreenChanged)
    Q_PROPERTY(bool     hasThermal              READ hasThermal                                 NOTIFY decodingChanged)
    Q_PROPERTY(bool     hasVideo                READ hasVideo                                   NOTIFY hasVideoChanged)
    Q_PROPERTY(bool     isStreamSource          READ isStreamSource                             NOTIFY isStreamSourceChanged)
    Q_PROPERTY(bool     isUvc                   READ isUvc                                      NOTIFY isUvcChanged)
    Q_PROPERTY(bool     recording               READ recording                                  NOTIFY recordingChanged)
    Q_PROPERTY(bool     streaming               READ streaming                                  NOTIFY streamingChanged)
    Q_PROPERTY(double   aspectRatio             READ aspectRatio                                NOTIFY aspectRatioChanged)
    Q_PROPERTY(double   hfov                    READ hfov                                       NOTIFY aspectRatioChanged)
    Q_PROPERTY(double   thermalAspectRatio      READ thermalAspectRatio                         NOTIFY aspectRatioChanged)
    Q_PROPERTY(double   thermalHfov             READ thermalHfov                                NOTIFY aspectRatioChanged)
    Q_PROPERTY(QSize    videoSize               READ videoSize                                  NOTIFY videoSizeChanged)
    Q_PROPERTY(QString  imageFile               READ imageFile                                  NOTIFY imageFileChanged)
    Q_PROPERTY(QString  uvcVideoSourceID        READ uvcVideoSourceID                           NOTIFY uvcVideoSourceIDChanged)
    Q_PROPERTY(QString  dehazeRunMode           READ dehazeRunMode       WRITE setDehazeRunMode  NOTIFY dehazeChanged)
    Q_PROPERTY(QString  dehazeStrength          READ dehazeStrength      WRITE setDehazeStrength NOTIFY dehazeChanged)
    Q_PROPERTY(QString  dehazeAlgorithm         READ dehazeAlgorithm     WRITE setDehazeAlgorithm NOTIFY dehazeChanged)
    Q_PROPERTY(bool     dehazePanelOpen         READ dehazePanelOpen     WRITE setDehazePanelOpen NOTIFY dehazeChanged)
    Q_PROPERTY(double   dehazeFps               READ dehazeFps                                  NOTIFY dehazePerformanceChanged)
    Q_PROPERTY(double   dehazeFrameMs           READ dehazeFrameMs                              NOTIFY dehazePerformanceChanged)

public:
    explicit VideoManager(QObject *parent = nullptr);
    ~VideoManager();

    static VideoManager *instance();
    static void registerQmlTypes();

    Q_INVOKABLE void grabImage(const QString &imageFile = QString());
    Q_INVOKABLE void startRecording(const QString &videoFile = QString());
    Q_INVOKABLE void startVideo();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void stopVideo();

    void init(QQuickWindow *rootWindow);
    void cleanup();
    bool autoStreamConfigured() const;
    bool decoding() const { return _decoding; }
    bool fullScreen() const { return _fullScreen; }
    bool hasThermal() const;
    bool hasVideo() const;
    bool isStreamSource() const;
    bool isUvc() const;
    bool recording() const { return _recording; }
    bool streaming() const { return _streaming; }
    double aspectRatio() const;
    double hfov() const;
    double thermalAspectRatio() const;
    double thermalHfov() const;
    QSize videoSize() const { return _videoSize; }
    QString imageFile() const { return _imageFile; }
    QString uvcVideoSourceID() const { return _uvcVideoSourceID; }
    QString dehazeRunMode() const { return _dehazeRunMode; }
    QString dehazeStrength() const { return _dehazeStrength; }
    QString dehazeAlgorithm() const { return _dehazeAlgorithm; }
    bool dehazePanelOpen() const { return _dehazePanelOpen; }
    double dehazeFps() const { return _dehazeFps; }
    double dehazeFrameMs() const { return _dehazeFrameMs; }
    void setDehazeRunMode(const QString &value) { if (_dehazeRunMode != value) { _dehazeRunMode = value; emit dehazeChanged(); } }
    void setDehazeStrength(const QString &value) { if (_dehazeStrength != value) { _dehazeStrength = value; emit dehazeChanged(); } }
    void setDehazeAlgorithm(const QString &value) { if (_dehazeAlgorithm != value) { _dehazeAlgorithm = value; emit dehazeChanged(); } }
    void setDehazePanelOpen(bool value) { if (_dehazePanelOpen != value) { _dehazePanelOpen = value; emit dehazeChanged(); } }
    void setfullScreen(bool on);
    static bool gstreamerEnabled();
    static bool qtmultimediaEnabled();
    static bool uvcEnabled();

signals:
    void aspectRatioChanged();
    void autoStreamConfiguredChanged();
    void decodingChanged();
    void fullScreenChanged();
    void hasVideoChanged();
    void imageFileChanged(const QString &filename);
    void isAutoStreamChanged();
    void isStreamSourceChanged();
    void isUvcChanged();
    void recordingChanged();
    void recordingStarted(const QString &filename);
    void streamingChanged();
    void uvcVideoSourceIDChanged();
    void videoSizeChanged();
    void dehazeChanged();
    void dehazePerformanceChanged();

private slots:
    void _communicationLostChanged(bool communicationLost);
    void _setActiveVehicle(Vehicle *vehicle);
    void _videoSourceChanged();

private:
    void _initVideoReceiver(VideoReceiver *receiver, QQuickWindow *window);
    bool _updateAutoStream(VideoReceiver *receiver);
    bool _updateUVC(VideoReceiver *receiver);
    bool _updateSettings(VideoReceiver *receiver);
    bool _updateVideoUri(VideoReceiver *receiver, const QString &uri);
    void _restartAllVideos();
    void _restartVideo(VideoReceiver *receiver);
    void _startReceiver(VideoReceiver *receiver);
    void _stopReceiver(VideoReceiver *receiver);
    static void _cleanupOldVideos();

    QList<VideoReceiver*> _videoReceivers;

    SubtitleWriter *_subtitleWriter = nullptr;
    VideoSettings *_videoSettings = nullptr;

    bool _initialized = false;
    bool _fullScreen = false;
    QAtomicInteger<bool> _decoding = false;
    QAtomicInteger<bool> _recording = false;
    QAtomicInteger<bool> _streaming = false;
    QSize _videoSize;
    QString _imageFile;
    QString _uvcVideoSourceID;
    Vehicle *_activeVehicle = nullptr;

    QString _dehazeRunMode = QStringLiteral("OFF");
    QString _dehazeStrength = QStringLiteral("MEDIUM");
    QString _dehazeAlgorithm = QStringLiteral("ADAPTIVE");
    bool _dehazePanelOpen = false;
    double _dehazeFps = 0.0;
    double _dehazeFrameMs = 0.0;
    QElapsedTimer _dehazePerfTimer;
    int _dehazeFrameCounter = 0;
};

/*===========================================================================*/

class FinishVideoInitialization : public QRunnable
{
public:
    FinishVideoInitialization();
    ~FinishVideoInitialization();

    void run() final;
};
