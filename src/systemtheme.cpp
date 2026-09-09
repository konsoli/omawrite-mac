#include "systemtheme.h"

#include <QGuiApplication>
#include <QStyleHints>

SystemTheme::SystemTheme(QObject *parent) : QObject(parent) {
    m_darkMode = detectDarkMode();
    m_textScale = detectTextScale();

    if (QGuiApplication::styleHints()) {
        connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
                this, &SystemTheme::refresh);
    }
}

void SystemTheme::refresh() {
    setDarkMode(detectDarkMode());
    setTextScale(detectTextScale());
}

bool SystemTheme::detectDarkMode() const {
    if (!QGuiApplication::styleHints())
        return true;

    const Qt::ColorScheme scheme = QGuiApplication::styleHints()->colorScheme();
    if (scheme == Qt::ColorScheme::Light)
        return false;

    return true;
}

qreal SystemTheme::detectTextScale() const {
    return 1.0;  // no system-wide text-scale setting to follow
}

void SystemTheme::setDarkMode(bool darkMode) {
    if (m_darkMode == darkMode)
        return;

    m_darkMode = darkMode;
    emit darkModeChanged(m_darkMode);
}

void SystemTheme::setTextScale(qreal textScale) {
    if (qFuzzyCompare(m_textScale, textScale))
        return;

    m_textScale = textScale;
    emit textScaleChanged(m_textScale);
}
