import Quickshell.Services.UPower
import QtQuick

Item {
    id: root

    implicitWidth: pill.width
    implicitHeight: Theme.barHeight

    readonly property bool isReady: {
        if (UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery)
            return true;
        return false;
    }

    readonly property string icon: {
        if (!isReady)
            return "";
        if (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
            return "󱟠";
        if (UPower.displayDevice.percentage <= 25)
            return "󰂃";
        if (UPower.displayDevice.percentage <= 50)
            return "󰁻";
        if (UPower.displayDevice.percentage <= 75)
            return "󰁾";
        if (UPower.displayDevice.percentage < 100)
            return "󰂂";
        if (UPower.displayDevice.percentage === 100)
            return "󰁹";
        return "";
    }

    Rectangle {
        id: pill

        anchors.centerIn: parent

        width: root.isReady ? row.implicitWidth + 10 : 0
        height: root.implicitHeight - 4

        radius: height / 2

        color: Theme.surface0

        Row {
            id: row

            spacing: 4

            anchors.centerIn: parent

            Text {
                id: iconText

                color: Theme.text

                text: root.icon
            }

            Text {
                id: batteryText

                color: Theme.text

                text: root.isReady ? Math.round(UPower.displayDevice.percentage) + "%" : ""
            }
        }
    }
}
