pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland

Rectangle {
    id: root

    width: row.implicitWidth + 10
    height: Theme.barHeight - 4

    color: Colors.md3.surface_container
    radius: height / 2

    required property var screen

    property var icons: ({
            "1": "一",
            "2": "二",
            "3": "三",
            "4": "四",
            "5": "五",
            "6": "六",
            "7": "七",
            "8": "八",
            "9": "九",
            "10": "十",
            "browser": "󰳉",
            "spotify": "",
            "discord": "",
            "steam": "",
            "slack": "",
            "anime": "",
            "games": "󰊗",
            "qbitorrent": "󰃘",
            "terminal": "",
            "vscode": ""
        })

    Row {
        id: row

        anchors.centerIn: parent

        spacing: 5

        Repeater {
            model: Hyprland.workspaces.values.filter(workspace => workspace.monitor === Hyprland.monitorFor(screen))

            Rectangle {
                id: workspace

                required property var modelData

                height: 25
                width: 25

                radius: height / 2

                color: modelData.focused ? Colors.md3.outline : Colors.md3.surface_container_low

                Text {
                    anchors.centerIn: parent

                    text: root.icons[workspace.modelData.name] ?? workspace.modelData.name

                    color: workspace.modelData.focused ? Colors.md3.inverse_on_surface : Colors.md3.on_surface
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: workspace.modelData.activate()
                }
            }
        }
    }
}
