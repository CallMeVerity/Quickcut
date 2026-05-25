#include "video_processor.h"
#include <QUrl>
#include <QTextStream>
#include <QDebug>

VideoProcessor::VideoProcessor(QObject *parent) : QObject(parent) {
    QDir tmpDir(QDir::tempPath());
    for (const auto &fi : tmpDir.entryInfoList(QStringList() << "quickcut_*", QDir::Dirs))
        cleanTempDir(fi.absoluteFilePath());
    for (const auto &fi : tmpDir.entryInfoList(QStringList() << "quickcut_waveform_*.png", QDir::Files))
        QFile::remove(fi.absoluteFilePath());
}

VideoProcessor::~VideoProcessor() {
    if (!m_waveformPath.isEmpty())
        QFile::remove(m_waveformPath);
    if (!m_realTmpDir.isEmpty())
        cleanTempDir(m_realTmpDir);
}

QString VideoProcessor::sourceFile() const { return m_sourceFile; }
void VideoProcessor::setSourceFile(const QString &path) {
    auto clean = QUrl(path).toLocalFile();
    if (clean.isEmpty()) clean = path;
    if (m_sourceFile != clean) {
        m_sourceFile = clean;
        emit sourceFileChanged();
        probefps();
        generateWaveform();
    }
}

bool VideoProcessor::processing() const { return m_processing; }
QString VideoProcessor::status() const { return m_status; }
double VideoProcessor::fps() const { return m_fps; }
QString VideoProcessor::waveformPath() const { return m_waveformPath; }
bool VideoProcessor::isVfr() const { return m_isVfr; }

Q_INVOKABLE int VideoProcessor::frameDurationMs() const {
    return m_fps > 0 ? qRound(1000.0 / m_fps) : 33;
}

Q_INVOKABLE void VideoProcessor::cut(qint64 startMs, qint64 endMs, const QString &outputPath,
                         bool removeAudio, const QVariantList &muteSegments) {
    if (m_sourceFile.isEmpty() || m_processing) return;

    auto outFile = QUrl(outputPath).toLocalFile();
    if (outFile.isEmpty()) outFile = outputPath;

    QString srcExt = QFileInfo(m_sourceFile).suffix();
    if (!srcExt.isEmpty() && QFileInfo(outFile).suffix().toLower() != srcExt.toLower()) {
        outFile = outFile.left(outFile.lastIndexOf(QLatin1Char('.'))) + QLatin1Char('.') + srcExt.toLower();
    }

    qint64 duration = endMs - startMs;
    if (duration <= 0) return;

    m_processing = true;
    emit processingChanged();
    setStatus("Cutting...");

    auto *proc = new QProcess(this);
    QStringList args = {
        "-y",
        "-ss", msToTimestamp(startMs),
        "-i", m_sourceFile,
        "-t", msToTimestamp(duration),
    };

    if (removeAudio) {
        args << "-c:v" << "copy" << "-an";
    } else {
        auto filter = buildMuteFilter(muteSegments, startMs, startMs + duration);
        if (!filter.isEmpty()) {
            args << "-c:v" << "copy" << "-af" << filter << "-c:a" << "aac" << "-b:a" << "192k";
        } else {
            args << "-c" << "copy";
        }
    }

    args << outFile;

    connect(proc, &QProcess::finished, this, [this, proc](int exitCode) {
        proc->deleteLater();
        m_processing = false;
        emit processingChanged();
        if (exitCode == 0) {
            setStatus("Done");
            emit cutFinished(true);
        } else {
            auto err = QString::fromUtf8(proc->readAllStandardError());
            qWarning() << "ffmpeg cut failed:" << err;
            setStatus("Cut failed (see console)");
            emit cutFinished(false);
        }
    });

    proc->start("ffmpeg", args);
    if (!proc->waitForStarted(3000)) {
        proc->deleteLater();
        m_processing = false;
        emit processingChanged();
        setStatus("Failed to start ffmpeg");
        emit cutFinished(false);
    }
}

Q_INVOKABLE void VideoProcessor::cutSegments(const QVariantList &segments, const QString &outputPath,
                                 bool removeAudio, const QVariantList &muteSegments) {
    if (m_sourceFile.isEmpty() || m_processing || segments.isEmpty()) return;

    if (segments.size() == 1 && !removeAudio && muteSegments.isEmpty()) {
        auto seg = segments[0].toMap();
        cut(seg["start"].toLongLong(), seg["end"].toLongLong(), outputPath);
        return;
    }

    auto outFile = QUrl(outputPath).toLocalFile();
    if (outFile.isEmpty()) outFile = outputPath;

    m_processing = true;
    emit processingChanged();

    m_realTmpDir = QDir::tempPath() + "/quickcut_" + QString::number(QDateTime::currentMSecsSinceEpoch());
    if (!QDir().mkpath(m_realTmpDir)) {
        setStatus("Error: cannot create temp directory");
        m_processing = false;
        emit processingChanged();
        emit cutFinished(false);
        return;
    }

    m_segmentFiles.clear();
    m_segmentTimestamps.clear();
    QString srcExt = QFileInfo(m_sourceFile).suffix();
    if (srcExt.isEmpty()) srcExt = QStringLiteral("mov");

    for (int i = 0; i < segments.size(); ++i) {
        auto seg = segments[i].toMap();
        m_segmentTimestamps.append(qMakePair(
            seg["start"].toLongLong(),
            seg["end"].toLongLong()
        ));
        m_segmentFiles.append(m_realTmpDir + QString("/seg%1.%2").arg(i, 3, 10, QChar('0')).arg(srcExt));
    }

    m_concatFilePath = m_realTmpDir + "/concat.txt";
    {
        QFile f(m_concatFilePath);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            setStatus("Error: cannot write concat file");
            cleanTempDir(m_realTmpDir);
            m_processing = false;
            emit processingChanged();
            emit cutFinished(false);
            return;
        }
        QTextStream stream(&f);
        for (const auto &segFile : m_segmentFiles)
            stream << QStringLiteral("file '%1'").arg(segFile) << "\n";
        f.close();
    }

    if (QFileInfo(outFile).suffix().toLower() != srcExt.toLower()) {
        outFile = outFile.left(outFile.lastIndexOf(QLatin1Char('.'))) + QLatin1Char('.') + srcExt.toLower();
    }

    m_finalOutputPath = outFile;
    m_currentSegmentIndex = 0;
    m_removeAudio = removeAudio;
    m_muteSegments = muteSegments;
    processNextSegment();
}

void VideoProcessor::setStatus(const QString &s) {
    if (m_status != s) { m_status = s; emit statusChanged(); }
}

QString VideoProcessor::msToTimestamp(qint64 ms) {
    int h = ms / 3600000;
    int m = (ms % 3600000) / 60000;
    int s = (ms % 60000) / 1000;
    int ml = ms % 1000;
    return QStringLiteral("%1:%2:%3.%4")
        .arg(h, 2, 10, QChar('0'))
        .arg(m, 2, 10, QChar('0'))
        .arg(s, 2, 10, QChar('0'))
        .arg(ml, 3, 10, QChar('0'));
}

QString VideoProcessor::buildMuteFilter(const QVariantList &muteSegs, qint64 segStartMs, qint64 segEndMs) {
    QStringList parts;
    for (const auto &seg : muteSegs) {
        auto map = seg.toMap();
        qint64 muteStart = map["start"].toLongLong();
        qint64 muteEnd = map["end"].toLongLong();
        qint64 overlapStart = qMax(muteStart, segStartMs);
        qint64 overlapEnd = qMin(muteEnd, segEndMs);
        if (overlapStart >= overlapEnd) continue;
        double startSec = (overlapStart - segStartMs) / 1000.0;
        double endSec = (overlapEnd - segStartMs) / 1000.0;
        parts << QStringLiteral("between(t,%1,%2)")
                  .arg(startSec, 0, 'f', 3)
                  .arg(endSec, 0, 'f', 3);
    }
    if (parts.isEmpty()) return {};
    return QStringLiteral("volume=enable='%1':volume=0").arg(parts.join("+"));
}

void VideoProcessor::processNextSegment() {
    if (m_currentSegmentIndex >= m_segmentTimestamps.size()) {
        concatSegments();
        return;
    }

    qint64 startMs = m_segmentTimestamps[m_currentSegmentIndex].first;
    qint64 endMs = m_segmentTimestamps[m_currentSegmentIndex].second;
    qint64 duration = endMs - startMs;
    QString segFile = m_segmentFiles[m_currentSegmentIndex];

    setStatus(QString("Cutting segment %1/%2...").arg(m_currentSegmentIndex + 1).arg(m_segmentTimestamps.size()));

    auto *proc = new QProcess(this);
    QStringList args = {
        "-y",
        "-ss", msToTimestamp(startMs),
        "-i", m_sourceFile,
        "-t", msToTimestamp(duration),
    };

    bool hasMutes = !m_muteSegments.isEmpty();
    if (m_removeAudio) {
        args << "-c:v" << "copy" << "-an";
    } else if (hasMutes) {
        auto filter = buildMuteFilter(m_muteSegments, startMs, endMs);
        if (!filter.isEmpty())
            args << "-c:v" << "copy" << "-af" << filter << "-c:a" << "aac" << "-b:a" << "192k";
        else
            args << "-c:v" << "copy" << "-c:a" << "aac" << "-b:a" << "192k";
    } else {
        args << "-c" << "copy";
    }

    args << segFile;

    connect(proc, &QProcess::finished, this, [this, proc](int exitCode) {
        proc->deleteLater();
        if (exitCode != 0) {
            auto err = QString::fromUtf8(proc->readAllStandardError());
            qWarning() << "ffmpeg segment failed:" << err;
            cleanTempDir(m_realTmpDir);
            m_processing = false;
            emit processingChanged();
            setStatus("Cut failed (see console)");
            emit cutFinished(false);
            return;
        }
        m_currentSegmentIndex++;
        processNextSegment();
    });

    proc->start("ffmpeg", args);
    if (!proc->waitForStarted(3000)) {
        proc->deleteLater();
        cleanTempDir(m_realTmpDir);
        m_processing = false;
        emit processingChanged();
        setStatus("Failed to start ffmpeg");
        emit cutFinished(false);
    }
}

void VideoProcessor::concatSegments() {
    if (m_isVfr)
        setStatus("Concatenating (re-encoding for variable frame rate)...");
    else
        setStatus("Concatenating...");

    auto *proc = new QProcess(this);
    QStringList args = {
        "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", m_concatFilePath,
    };

    if (m_isVfr) {
        args << "-c:v" << "libx264"
             << "-preset" << "fast"
             << "-crf" << "18"
             << "-c:a" << "aac" << "-b:a" << "192k";
    } else {
        args << "-c" << "copy";
    }

    args << m_finalOutputPath;

    connect(proc, &QProcess::finished, this, [this, proc](int exitCode) {
        cleanTempDir(m_realTmpDir);
        proc->deleteLater();
        m_processing = false;
        emit processingChanged();
        if (exitCode == 0) {
            setStatus("Done");
            emit cutFinished(true);
        } else {
            auto err = QString::fromUtf8(proc->readAllStandardError());
            qWarning() << "ffmpeg concat failed:" << err;
            setStatus("Cut failed (see console)");
            emit cutFinished(false);
        }
    });

    proc->start("ffmpeg", args);
    if (!proc->waitForStarted(3000)) {
        proc->deleteLater();
        cleanTempDir(m_realTmpDir);
        m_processing = false;
        emit processingChanged();
        setStatus("Failed to start ffmpeg");
        emit cutFinished(false);
    }
}

void VideoProcessor::cleanTempDir(const QString &path) {
    QDir dir(path);
    if (dir.exists()) {
        for (const auto &fi : dir.entryInfoList(QDir::Files))
            QFile::remove(fi.absoluteFilePath());
        dir.rmdir(path);
    }
}

void VideoProcessor::probefps() {
    auto *proc = new QProcess(this);
    QStringList args = {
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=r_frame_rate:stream=avg_frame_rate",
        "-of", "csv=p=0",
        m_sourceFile
    };
    connect(proc, &QProcess::finished, this, [this, proc](int code) {
        if (code == 0) {
            auto out = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
            auto lines = out.split('\n');
            double rFps = 0;
            double aFps = 0;
            for (const auto &line : lines) {
                auto parts = line.split('/');
                if (parts.size() == 2) {
                    double num = parts[0].toDouble();
                    double den = parts[1].toDouble();
                    if (den > 0) {
                        if (rFps == 0) rFps = num / den;
                        else aFps = num / den;
                    }
                }
            }
            if (rFps > 0) {
                m_fps = rFps;
                emit fpsChanged();
            }
            m_isVfr = (rFps > 0 && aFps > 0 && qAbs(rFps - aFps) > 1.0);
            emit isVfrChanged();
        }
        proc->deleteLater();
    });
    proc->start("ffprobe", args);
}

void VideoProcessor::generateWaveform() {
    if (m_sourceFile.isEmpty()) return;

    m_waveformPath.clear();
    emit waveformPathChanged();

    auto *proc = new QProcess(this);
    QString outputPath = QDir::tempPath() + "/quickcut_waveform_" + QString::number(qint64(this)) + ".png";
    QStringList args = {
        "-y",
        "-hwaccel", "none",
        "-i", m_sourceFile,
        "-filter_complex", "[0:a]showwavespic=s=2000x64:colors=#444444:scale=sqrt",
        "-frames:v", "1",
        "-update", "1",
        outputPath
    };
    connect(proc, &QProcess::finished, this, [this, proc, outputPath](int exitCode) {
        proc->deleteLater();
        if (exitCode == 0 && QFileInfo::exists(outputPath)) {
            m_waveformPath = outputPath;
        } else {
            qWarning() << "ffmpeg waveform failed";
            m_waveformPath.clear();
        }
        emit waveformPathChanged();
    });
    proc->start("ffmpeg", args);
    if (!proc->waitForStarted(3000)) {
        proc->deleteLater();
        m_waveformPath.clear();
        emit waveformPathChanged();
    }
}