import Quickshell
import QtQuick

Item {
    id: root

    implicitWidth: pill.width
    implicitHeight: pill.height

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Rectangle {
        id: pill

        width: clockText.implicitWidth + 20
        height: Theme.barHeight - 4

        anchors.centerIn: parent

        color: Theme.surface0
        radius: height / 2

        Text {
            id: clockText

            anchors.centerIn: parent

            color: Theme.text
            text: Qt.formatDateTime(clock.date, "dddd hh:mm AP - MM-dd-yyyy")
        }
    }
}
