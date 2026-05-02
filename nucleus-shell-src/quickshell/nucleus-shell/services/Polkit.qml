pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

Singleton {
    id: root

    // Graceful fallback for systems without Quickshell.Services.Polkit.
    readonly property bool isActive: false
    readonly property bool isRegistered: false
    readonly property string path: ""
    readonly property QtObject flow: QtObject {
        readonly property bool failed: false
        readonly property bool isSuccessful: false
        readonly property bool isCompleted: false
        readonly property bool isCancelled: false
        readonly property string message: ""
        readonly property string inputPrompt: "Password:"

        function cancelAuthenticationRequest() {}
        function submit(_value) {}
    }
}
