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

    color: Theme.barColor

    Audio {
        id: audio
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        barHeight: topBar.implicitHeight
    }

    Workspaces {
        anchors.left: audio.right
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
