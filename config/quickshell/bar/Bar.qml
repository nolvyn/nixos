import Quickshell
import QtQuick

PanelWindow {
    id: topBar

    property real barHeight: 32

    implicitHeight: barHeight

    anchors {
        top: true
        left: true
        right: true
    }

    color: Qt.rgba(
    Colors.md3.surface.r,
    Colors.md3.surface.g,
    Colors.md3.surface.b,
    0.00
)

    Audio {
        id: audio
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        barHeight: topBar.implicitHeight
    }

    Battery {
        id: battery
        anchors.left: audio.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }

    Workspaces {
        id: workspaces

        anchors.left: battery.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        screen: topBar.screen
    }

    Clock {
        anchors.centerIn: parent
    }

    Tray {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        window: topBar
    }
}
