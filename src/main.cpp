#include <QFont>
#include <QFontDatabase>
#include <QApplication>
#include <QEvent>
#include <QFileOpenEvent>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QUrl>
#include <QWindow>
#include <QFile>

#include "backend.h"
#include "systemtheme.h"

namespace {

// macOS routes document opens — double-click, Finder's "Open With", the Quick
// Look preview's open button, a drop on the Dock icon — through QFileOpenEvent
// on the application object, never through argv.
class DocumentOpener : public QObject {
public:
    DocumentOpener(Backend *backend, QObject *parent)
        : QObject(parent), m_backend(backend) {}

    // Events can arrive before the window exists; hold on to them until it does.
    void setReady() {
        m_ready = true;
        if (m_pending.isValid()) {
            const QUrl url = m_pending;
            m_pending.clear();
            openUrl(url);
        }
    }

protected:
    bool eventFilter(QObject *watched, QEvent *event) override {
        if (event->type() != QEvent::FileOpen)
            return QObject::eventFilter(watched, event);

        const QUrl url = static_cast<QFileOpenEvent *>(event)->url();
        if (m_ready)
            openUrl(url);
        else
            m_pending = url;
        return true;
    }

private:
    void openUrl(const QUrl &url) {
        // One document per process, the same rule Cmd+N follows: an incoming
        // document never replaces what is already on screen.
        if (m_backend->fileUrl().isEmpty() && !m_backend->modified()) {
            m_backend->open(url);
            return;
        }

        m_backend->openInNewWindow(url);
    }

    Backend *m_backend;
    QUrl m_pending;
    bool m_ready = false;
};

}  // namespace

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("omawrite"));

    QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/iAWriterMonoS-Regular.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/iAWriterMonoS-Italic.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/iAWriterMonoS-Bold.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/iAWriterMonoS-BoldItalic.ttf"));
    app.setOrganizationName(QStringLiteral("Omacom"));
    app.setOrganizationDomain(QStringLiteral("omacom.io"));

    QQuickStyle::setStyle(QStringLiteral("Material"));

    Backend backend(&app);
    SystemTheme systemTheme(&app);
    backend.setDarkMode(systemTheme.darkMode());
    QObject::connect(&systemTheme, &SystemTheme::darkModeChanged, &backend,
                     &Backend::setDarkMode);

    // Carry the desktop's text scale into the default font, so the chrome that
    // inherits it (dialog titles, buttons) grows along with the writing area.
    const QFont interfaceFont(QStringLiteral("iA Writer Mono S"));
    const qreal basePointSize = interfaceFont.pointSizeF() > 0
        ? interfaceFont.pointSizeF()
        : app.font().pointSizeF();
    const auto applyInterfaceFont = [&app, interfaceFont, basePointSize](qreal textScale) {
        QFont scaled = interfaceFont;
        scaled.setPointSizeF(basePointSize * textScale);
        app.setFont(scaled);
    };
    applyInterfaceFont(systemTheme.textScale());

    backend.setTextScale(systemTheme.textScale());
    QObject::connect(&systemTheme, &SystemTheme::textScaleChanged, &backend,
                     [&backend, applyInterfaceFont](qreal textScale) {
        applyInterfaceFont(textScale);
        backend.setTextScale(textScale);
    });

    DocumentOpener opener(&backend, &app);
    app.installEventFilter(&opener);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app,
                     [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings)
            qWarning().noquote() << warning.toString();
    });
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);

    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Could not load the Omawrite interface; resource available:"
                    << QFile::exists(QStringLiteral(":/Main.qml"));
        return -1;
    }

    backend.setParentWindow(qobject_cast<QWindow *>(engine.rootObjects().constFirst()));

    const QStringList args = app.arguments();
    if (args.size() > 1 && !backend.modified())
        backend.open(QUrl::fromLocalFile(args.at(1)));

    opener.setReady();

    return app.exec();
}
