pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    required property PanelWindow window

    width: row.implicitWidth + 10
    height: Theme.barHeight - 4

    color: Colors.md3.surface_container
    radius: height / 2

    Row {
        id: row

        spacing: 5

        anchors.centerIn: parent

        Repeater {
            model: SystemTray.items

            IconImage {
                id: icon

                required property var modelData

                width: 20
                height: 20

                source: icon.modelData.icon

                QsMenuAnchor {
                    id: trayMenu

                    anchor.window: root.window
                    menu: icon.modelData.menu
                }

                MouseArea {
                    anchors.fill: parent

                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            icon.modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            icon.modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            trayMenu.open();
                        } else {
                            icon.modelData.activate();
                        }
                    }
                }
            }
        }
    }
}
