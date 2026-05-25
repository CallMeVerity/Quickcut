#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QDir>
#include <QUrl>
#include <QFileInfo>
#include <QStandardPaths>

class DirLister : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QStringList extensions READ extensions WRITE setExtensions NOTIFY extensionsChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)

public:
    explicit DirLister(QObject *parent = nullptr);

    QString path() const;
    void setPath(const QString &p);
    QStringList extensions() const;
    void setExtensions(const QStringList &ext);
    QString filter() const;
    void setFilter(const QString &f);
    QVariantList entries() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString homePath() const;
    Q_INVOKABLE QString parentPath() const;
    Q_INVOKABLE bool pathExists(const QString &p) const;
    Q_INVOKABLE QString joinPath(const QString &dir, const QString &name) const;
    Q_INVOKABLE QStringList completePath(const QString &partial) const;

signals:
    void pathChanged();
    void extensionsChanged();
    void filterChanged();
    void entriesChanged();

private:
    void readDir();
    void applyFilters();

    QString m_path;
    QStringList m_extensions;
    QString m_filter;
    QVariantList m_allEntries;
    QVariantList m_entries;
};