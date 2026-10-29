import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../code/schedule.js" as Schedule

PlasmoidItem {
    id: root
    width: 390
    height: 440
    preferredRepresentation: fullRepresentation

    property var now: new Date()
    property var schedule: null
    property bool loading: false
    property string error: ""
    property bool showWeek: false
    property int weekOffset: 0
    property var request: null
    property bool ready: false
    readonly property string groupPath: Plasmoid.configuration.groupPath.trim()
    readonly property string sourceUrl: "https://timetable.magtu.ru/" + encodeURIComponent(groupPath)
    readonly property var weekStart: Schedule.monday(now, weekOffset)
    readonly property int currentParity: Schedule.parity(now, Plasmoid.configuration.invertParity)
    readonly property int viewedParity: Schedule.parity(weekStart, Plasmoid.configuration.invertParity)
    readonly property var visibleDays: {
        var result = []
        var parity = showWeek ? viewedParity : currentParity
        var firstDay = showWeek ? 1 : (now.getDay() || 7)
        var lastDay = showWeek ? 7 : firstDay
        for (var day = firstDay; day <= lastDay; day++) {
            var date = new Date(weekStart)
            date.setDate(date.getDate() + day - 1)
            if (!showWeek) date = now
            result.push({label: Qt.formatDate(date, "dddd, d MMMM"),
                lessons: schedule ? (schedule.weeks[String(parity)][String(day)] || []) : []})
        }
        return result
    }

    function restore() {
        schedule = null
        try {
            var cached = JSON.parse(Plasmoid.configuration.cachedSchedule)
            if (cached.source === sourceUrl && cached.weeks["1"] && cached.weeks["2"])
                schedule = cached
        } catch (_) { /* No saved data yet. */ }
    }

    function reload() {
        if (request) request.abort()
        requestTimeout.stop()
        error = ""
        loading = true
        var url = sourceUrl
        var xhr = new XMLHttpRequest()
        request = xhr
        xhr.onreadystatechange = function () {
            if (xhr !== request || xhr.readyState !== XMLHttpRequest.DONE) return
            requestTimeout.stop()
            request = null
            loading = false
            if (xhr.status !== 200) {
                error = "Не удалось загрузить расписание. Проверьте сеть и группу."
                return
            }
            try {
                var parsed = Schedule.parse(xhr.responseText)
                parsed.source = url
                parsed.updatedAt = new Date().toISOString()
                schedule = parsed
                Plasmoid.configuration.cachedSchedule = JSON.stringify(parsed)
            } catch (e) { error = String(e.message || e) }
        }
        xhr.open("GET", url)
        requestTimeout.start()
        xhr.send()
    }

    onGroupPathChanged: { if (ready) { restore(); reload() } }
    Component.onCompleted: { ready = true; restore(); reload() }
    Component.onDestruction: { if (request) request.abort() }
    Timer {
        id: requestTimeout
        interval: 20000
        onTriggered: {
            var pending = root.request
            root.request = null
            if (pending) pending.abort()
            root.loading = false
            root.error = "Сайт не ответил за 20 секунд. Повторите обновление."
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Timer { interval: 3600000; running: true; repeat: true; onTriggered: root.reload() }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 300
        Layout.minimumHeight: 280
        Layout.preferredWidth: 390
        Layout.preferredHeight: 440
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: root.schedule ? root.schedule.group : root.groupPath
                elide: Text.ElideRight
            }
            Controls.ToolButton {
                icon.name: "view-refresh"
                text: "Обновить"
                display: Controls.AbstractButton.IconOnly
                enabled: !root.loading
                onClicked: root.reload()
                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: text
            }
        }
        RowLayout {
            Controls.Button {
                text: root.showWeek ? "На сегодня" : "Вся неделя"
                onClicked: { root.showWeek = !root.showWeek; root.weekOffset = 0 }
            }
            Controls.Label {
                Layout.fillWidth: true
                text: (root.showWeek ? root.viewedParity : root.currentParity) === 1 ? "Нечётная неделя" : "Чётная неделя"
                wrapMode: Text.WordWrap
            }
        }
        RowLayout {
            visible: root.showWeek
            Controls.ToolButton { text: "‹"; Accessible.name: "Предыдущая неделя"; onClicked: root.weekOffset-- }
            Controls.Label {
                Layout.fillWidth: true
                text: "С " + Qt.formatDate(root.weekStart, "dd.MM.yyyy")
                horizontalAlignment: Text.AlignHCenter
            }
            Controls.Button { text: "Текущая"; onClicked: root.weekOffset = 0 }
            Controls.ToolButton { text: "›"; Accessible.name: "Следующая неделя"; onClicked: root.weekOffset++ }
        }
        Controls.Label {
            Layout.fillWidth: true
            visible: root.loading || root.error.length > 0
            text: root.loading ? "Загрузка…" : root.error + (root.schedule ? " Показана сохранённая версия." : "")
            wrapMode: Text.WordWrap
        }
        Controls.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                Repeater {
                    model: root.schedule ? root.visibleDays : []
                    delegate: ColumnLayout {
                        id: daySection
                        required property var modelData
                        Layout.fillWidth: true
                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 4
                            text: daySection.modelData.label
                            wrapMode: Text.WordWrap
                        }
                        Controls.Label { visible: daySection.modelData.lessons.length === 0; text: "Занятий нет"; opacity: 0.65 }
                        Repeater {
                            model: daySection.modelData.lessons
                            delegate: Controls.Frame {
                                id: lesson
                                required property var modelData
                                Layout.fillWidth: true
                                ColumnLayout {
                                    width: parent.width
                                    Controls.Label { text: lesson.modelData.time + " · пара " + lesson.modelData.number; font.bold: true }
                                    Controls.Label { Layout.fillWidth: true; text: lesson.modelData.title; wrapMode: Text.WordWrap }
                                    Controls.Label {
                                        Layout.fillWidth: true
                                        text: [lesson.modelData.type, lesson.modelData.room, lesson.modelData.teacher].filter(function (x) { return x.length > 0 }).join(" · ")
                                        wrapMode: Text.WordWrap
                                        opacity: 0.7
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Controls.Label {
            Layout.fillWidth: true
            visible: root.schedule !== null
            text: root.schedule ? "Обновлено: " + Qt.formatDateTime(new Date(root.schedule.updatedAt), "dd.MM HH:mm") : ""
            font: Kirigami.Theme.smallFont
            opacity: 0.65
        }
        Controls.Button { text: "Открыть сайт МГТУ"; onClicked: Qt.openUrlExternally(root.sourceUrl) }
    }
}
