pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Item {
    id: root

    property var plugins: []

    function reload() {
        listPluginsProc.running = true
    }

    Component.onCompleted: reload()

    Process {
        id: listPluginsProc
        // List directories under ~/.config/nucleus-shell/plugins
        command: ["sh", "-c", "ls -1 ~/.config/nucleus-shell/plugins"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(s => s.trim() !== "")
                root.plugins = names
            }
        }

    }
}
