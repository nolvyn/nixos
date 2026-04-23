import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root

    property real barHeight: 32
    property var sink: Pipewire.defaultAudioSink

    implicitWidth: pill.width
    implicitHeight: root.barHeight

    PwObjectTracker {
        objects: [root.sink]
    }

    readonly property bool isHeadphone: {
        if (!root.sink || !root.sink.properties["device.form-factor"])
            return false;
        if (root.sink.properties["device.form-factor"].includes("headphone") || root.sink.properties["device.form-factor"].includes("headset"))
            return true;

        return false;
    }

    readonly property string icon: {
        if (!root.sink || !root.sink.audio)
            return "";
        if (root.isHeadphone)
            return "󰋋";
        if (root.sink.audio.muted)
            return "󰸈";
        if (root.sink.audio.volume <= 0.33)
            return "󰕿";
        if (root.sink.audio.volume <= 0.67)
            return "󰖀";
        if (root.sink.audio.volume > 0.67)
            return "󰕾";
        return "";
    }

    Rectangle {
        id: pill

        width: row.implicitWidth + 20
        height: root.barHeight - 4

        anchors.centerIn: parent

        color: Colors.md3.surface_container
        radius: height / 2

        Row {
            id: row

            spacing: 4

            anchors.centerIn: parent

            Text {
                id: iconText

                color: Colors.md3.on_surface

                text: root.icon
            }

            Text {
                id: volumeText

                color: Colors.md3.on_surface

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
                root.sink.audio.volume = Math.max(0.0, Math.min(1.25, parseFloat((root.sink.audio.volume + delta).toFixed(2))));
            }
        }
        onClicked: {
            if (root.sink && root.sink.audio) {
                root.sink.audio.muted = !root.sink.audio.muted;
            }
        }
    }
}
