#pragma once

#include <QObject>

class SystemTheme : public QObject {
    Q_OBJECT

public:
    explicit SystemTheme(QObject *parent = nullptr);

    bool darkMode() const { return m_darkMode; }
    qreal textScale() const { return m_textScale; }

signals:
    void darkModeChanged(bool darkMode);
    void textScaleChanged(qreal textScale);

public slots:
    void refresh();

private:
    bool detectDarkMode() const;
    qreal detectTextScale() const;
    void setDarkMode(bool darkMode);
    void setTextScale(qreal textScale);

    bool m_darkMode = true;
    qreal m_textScale = 1.0;
};
