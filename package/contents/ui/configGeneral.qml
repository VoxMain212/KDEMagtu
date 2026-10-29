import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_groupPath: group.text
    property alias cfg_invertParity: invert.checked

    Controls.TextField {
        id: group
        Kirigami.FormData.label: "Группа на сайте:"
        placeholderText: "АПИб-24-1_1"
    }
    Controls.Label {
        text: "Часть адреса после timetable.magtu.ru/ (включая подгруппу)."
        wrapMode: Text.WordWrap
    }
    Controls.CheckBox {
        id: invert
        text: "Поменять чётную и нечётную недели местами"
    }
    Controls.Label {
        text: "По умолчанию: неделя с 19.08.2024 — нечётная, как на сайте МГТУ."
        wrapMode: Text.WordWrap
    }
}
