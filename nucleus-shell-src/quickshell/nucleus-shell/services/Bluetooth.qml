pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth


Singleton {
    id: root
    readonly property BluetoothAdapter defaultAdapter: Bluetooth.defaultAdapter
    readonly property list<BluetoothDevice> devices: defaultAdapter?.devices?.values ?? []
    readonly property BluetoothDevice activeDevice: devices.find(d => d.connected) ?? null
    readonly property bool adapterPresent: defaultAdapter !== null
    readonly property bool bootstrapping: ensureOnProc.running || ensureOffProc.running
    property string lastError: ""

    readonly property string icon: {
        if (!defaultAdapter?.enabled)
            return "bluetooth_disabled"

        if (activeDevice)
            return "bluetooth_connected"

        return defaultAdapter.discovering
            ? "bluetooth_searching"
            : "bluetooth"
    }

    function setEnabled(enabled: bool): void {
        root.lastError = "";

        if (root.defaultAdapter)
            root.defaultAdapter.enabled = enabled;

        if (enabled) {
            ensureOnProc.exec(["bash", "-lc", "NUCLEUS_QS_SILENT=1 $HOME/.config/hypr/scripts/Nucleus_Quick_Settings.sh bt-on"]);
        } else {
            ensureOffProc.exec(["bash", "-lc", "NUCLEUS_QS_SILENT=1 $HOME/.config/hypr/scripts/Nucleus_Quick_Settings.sh bt-off"]);
        }
    }

    function toggleEnabled(): void {
        setEnabled(!(root.defaultAdapter?.enabled ?? false));
    }

    Process {
        id: ensureOnProc

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg.length > 0)
                    root.lastError = msg;
            }
        }
    }

    Process {
        id: ensureOffProc

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg.length > 0)
                    root.lastError = msg;
            }
        }
    }
}
