#include "dir_lister.h"

DirLister::DirLister(QObject *parent) : QObject(parent) {}

QString DirLister::path() const { return m_path; }
void DirLister::setPath(const QString &p) {
    auto clean = p;
    if (clean.startsWith("file://")) clean = QUrl(clean).toLocalFile();
    if (clean.isEmpty()) clean = "/";
    QDir d(clean);
    if (!d.exists()) return;
    clean = d.absolutePath();
    if (m_path != clean) {
        m_path = clean;
        emit pathChanged();
        readDir();
    }
}

QStringList DirLister::extensions() const { return m_extensions; }
void DirLister::setExtensions(const QStringList &ext) {
    if (m_extensions != ext) {
        m_extensions = ext;
        emit extensionsChanged();
        applyFilters();
    }
}

QString DirLister::filter() const { return m_filter; }
void DirLister::setFilter(const QString &f) {
    if (m_filter != f) {
        m_filter = f;
        emit filterChanged();
        applyFilters();
    }
}

QVariantList DirLister::entries() const { return m_entries; }

Q_INVOKABLE void DirLister::refresh() { readDir(); }

Q_INVOKABLE QString DirLister::homePath() const {
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
}

Q_INVOKABLE QString DirLister::parentPath() const {
    QDir d(m_path);
    d.cdUp();
    return d.absolutePath();
}

Q_INVOKABLE bool DirLister::pathExists(const QString &p) const {
    return QFileInfo::exists(p);
}

Q_INVOKABLE QString DirLister::joinPath(const QString &dir, const QString &name) const {
    return QDir(dir).filePath(name);
}

Q_INVOKABLE QStringList DirLister::completePath(const QString &partial) const {
    QStringList results;
    QString input = partial;
    if (input.startsWith("file://"))
        input = QUrl(input).toLocalFile();
    if (input.isEmpty())
        return results;

    QString dirPath;
    QString prefix;
    int sep = input.lastIndexOf(QLatin1Char('/'));
    if (sep >= 0) {
        dirPath = input.left(sep + 1);
        if (dirPath.isEmpty()) dirPath = QStringLiteral("/");
        prefix = input.mid(sep + 1);
    } else {
        dirPath = m_path;
        prefix = input;
    }

    QDir d(dirPath);
    if (!d.exists()) {
        d = QDir(QDir::homePath());
        prefix = input;
        if (input.startsWith(QLatin1Char('/'))) return results;
        dirPath = d.absolutePath();
    }

    for (const auto &fi : d.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot,
                                           QDir::Name | QDir::IgnoreCase)) {
        if (fi.fileName().startsWith(prefix, Qt::CaseInsensitive))
            results.append(dirPath + (dirPath.endsWith(QLatin1Char('/')) ? QString() : QStringLiteral("/")) + fi.fileName());
    }
    return results;
}

void DirLister::readDir() {
    m_allEntries.clear();
    QDir d(m_path);
    d.setFilter(QDir::AllEntries | QDir::NoDotAndDotDot);
    d.setSorting(QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);

    for (const auto &fi : d.entryInfoList()) {
        QVariantMap entry;
        entry["name"] = fi.fileName();
        entry["path"] = fi.absoluteFilePath();
        entry["isDir"] = fi.isDir();
        entry["size"] = fi.size();
        m_allEntries.append(entry);
    }
    applyFilters();
}

void DirLister::applyFilters() {
    m_entries.clear();
    for (const auto &v : m_allEntries) {
        auto e = v.toMap();
        bool isDir = e["isDir"].toBool();
        QString name = e["name"].toString();

        if (!isDir && !m_extensions.isEmpty()) {
            bool match = false;
            for (const auto &ext : m_extensions) {
                if (name.endsWith(QLatin1Char('.') + ext, Qt::CaseInsensitive)) {
                    match = true;
                    break;
                }
            }
            if (!match) continue;
        }

        if (!m_filter.isEmpty()) {
            if (!name.contains(m_filter, Qt::CaseInsensitive))
                continue;
        }

        m_entries.append(v);
    }
    emit entriesChanged();
}