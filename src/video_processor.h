#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QProcess>
#include <QFileInfo>
#include <QDir>
#include <QDateTime>

class VideoProcessor : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString sourceFile READ sourceFile WRITE setSourceFile NOTIFY sourceFileChanged)
    Q_PROPERTY(bool processing READ processing NOTIFY processingChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(double fps READ fps NOTIFY fpsChanged)
    Q_PROPERTY(QString waveformPath READ waveformPath NOTIFY waveformPathChanged)
    Q_PROPERTY(bool isVfr READ isVfr NOTIFY isVfrChanged)

public:
    explicit VideoProcessor(QObject *parent = nullptr);
    ~VideoProcessor();

    QString sourceFile() const;
    void setSourceFile(const QString &path);
    bool processing() const;
    QString status() const;
    double fps() const;
    QString waveformPath() const;
    bool isVfr() const;

    Q_INVOKABLE int frameDurationMs() const;
    Q_INVOKABLE void cut(qint64 startMs, qint64 endMs, const QString &outputPath,
                         bool removeAudio = false, const QVariantList &muteSegments = {});
    Q_INVOKABLE void cutSegments(const QVariantList &segments, const QString &outputPath,
                                  bool removeAudio = false, const QVariantList &muteSegments = {});

signals:
    void sourceFileChanged();
    void processingChanged();
    void statusChanged();
    void fpsChanged();
    void cutFinished(bool success);
    void waveformPathChanged();
    void isVfrChanged();

private:
    void setStatus(const QString &s);
    static QString msToTimestamp(qint64 ms);
    QString buildMuteFilter(const QVariantList &muteSegs, qint64 segStartMs, qint64 segEndMs);
    void processNextSegment();
    void concatSegments();
    void cleanTempDir(const QString &path);
    void probefps();
    void generateWaveform();

    QString m_sourceFile;
    bool m_processing = false;
    QString m_status;
    double m_fps = 0;
    QString m_waveformPath;
    bool m_isVfr = false;

    QStringList m_segmentFiles;
    QList<QPair<qint64, qint64>> m_segmentTimestamps;
    QString m_concatFilePath;
    QString m_finalOutputPath;
    int m_currentSegmentIndex = 0;
    QString m_realTmpDir;
    bool m_removeAudio = false;
    QVariantList m_muteSegments;
};