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

        color: Colors.md3.surface_container
        radius: height / 2

        Text {
            id: clockText

            anchors.centerIn: parent

            color: Colors.md3.on_surface
            text: Qt.formatDateTime(clock.date, "󰥔  hh:mm AP dddd 󰃭  MM-dd-yyyy")
        }
    }
}
