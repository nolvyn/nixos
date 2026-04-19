//@ pragma UseQApplication

import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {
                required property var modelData
                screen: modelData
            }
        }
    }
}
