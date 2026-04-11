import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root

    property real barHeight: 32
    property var sink: Pipewire.defaultAudioSink

    implicitWidth: pill.width
    implicitHeight: root.barHeight

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Rectangle {
        id: pill

        width: row.implicitWidth + 20
        height: root.barHeight - 4

        anchors.centerIn: parent

        color: Theme.surface0
        radius: height / 2

        Row {
            id: row

            spacing: 4

            anchors.centerIn: parent

            Text {
                id: volumeText

                color: Theme.text
                text: root.sink && root.sink.audio ? (root.sink.audio.muted ? "Muted" : Math.round(root.sink.audio.volume * 100) + "%") : "N/A"
            }
        }
    }

    MouseArea {
        anchors.fill: parent

        onWheel: wheel => {
            if (root.sink && root.sink.audio) {
                const step = 0.05;
                const delta = wheel.angleDelta.y > 0 ? step : -step;
                root.sink.audio.volume = Math.max(0.0, Math.min(1.5, parseFloat((root.sink.audio.volume + delta).toFixed(2))));
            }
        }
        onClicked: {
            if (root.sink && root.sink.audio) {
                root.sink.audio.muted = !root.sink.audio.muted;
            }
        }
    }
}
