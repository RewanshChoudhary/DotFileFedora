import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
pragma Singleton

Singleton {
    id: niriItem

    signal stateChanged()

    property string title: ""
    property bool isFullscreen: false
    property string layout: "Tiled"
    property int focusedWorkspaceId: 1

    property var workspaces: []
    property var workspaceCache: ({})
    property var windows: [] // tracked windows

    property bool initialized: false
    property int screenW: 0
    property int screenH: 0
    property real screenScale: 1

    function changeWorkspace(id) {
        sendSocketCommand(niriCommandSocket, {
            "Action": {
                "focus_workspace": {
                    "reference": { "Id": id }
                }
            }
        })
        dispatchProc.command = ["niri", "msg", "action", "focus-workspace", id.toString()]
        dispatchProc.running = true
    }

    function changeWorkspaceRelative(delta) {
        const cmd = delta > 0 ? "focus-workspace-down" : "focus-workspace-up"
        dispatchProc.command = ["niri", "msg", "action", cmd]
        dispatchProc.running = true
    }

    function isWorkspaceOccupied(id) {
        for (const ws of workspaces)
            if (ws.id === id) return true
        return false
    }

    function focusedWindowForWorkspace(id) {
        // focused window in workspace
        for (const win of windows) {
            if (win.workspaceId === id && win.isFocused) {
                return { class: win.appId, title: win.title }
            }
        }

        // fallback: any window in workspace
        for (const win of windows) {
            if (win.workspaceId === id) {
                return { class: win.appId, title: win.title }
            }
        }

        return null
    }

    function sendSocketCommand(sock, command) {
        if (sock.connected)
            sock.write(JSON.stringify(command) + "\n")
    }

    function startEventStream() {
        sendSocketCommand(niriEventStream, "EventStream")
    }

    function updateWorkspaces() {
        sendSocketCommand(niriCommandSocket, "Workspaces")
    }

    function updateWindows() {
        sendSocketCommand(niriCommandSocket, "Windows")
    }

    function updateFocusedWindow() {
        sendSocketCommand(niriCommandSocket, "FocusedWindow")
    }

    function recollectWorkspaces(workspacesData) {
        const list = []
        workspaceCache = {}

        for (const ws of workspacesData) {
            const data = {
                id: ws.idx !== undefined ? ws.idx + 1 : ws.id,
                internalId: ws.id,
                idx: ws.idx,
                name: ws.name || "",
                output: ws.output || "",
                isFocused: ws.is_focused === true,
                isActive: ws.is_active === true
            }

            list.push(data)
            workspaceCache[ws.id] = data
            if (data.isFocused)
                focusedWorkspaceId = data.id
        }

        list.sort((a, b) => a.id - b.id)
        workspaces = list
        stateChanged()
    }

    function recollectWindows(windowsData) {
        const list = []

        for (const win of windowsData) {
            list.push({
                appId: win.app_id || "",
                title: win.title || "",
                workspaceId: win.workspace_id,
                isFocused: win.is_focused === true
            })
        }

        windows = list
        stateChanged()
    }

    function recollectFocusedWindow(win) {
        if (win && win.title) {
            title = win.title
            isFullscreen = win.is_fullscreen || false
            layout = "Tiled"
        } else {
            title = "~"
            isFullscreen = false
            layout = "Tiled"
        }
        stateChanged()
    }

    Component.onCompleted: {
        if (Quickshell.env("NIRI_SOCKET")) {
            niriCommandSocket.connected = true
            niriEventStream.connected = true
            initialized = true
        }
    }

    Process {
        id: niriOutputsProc
        command: ["niri", "msg", "outputs"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                let sizeRe = /Logical size:\s*(\d+)x(\d+)/
                let scaleRe = /Scale:\s*([\d.]+)/

                for (const line of lines) {
                    let m
                    if ((m = sizeRe.exec(line))) {
                        screenW = parseInt(m[1], 10)
                        screenH = parseInt(m[2], 10)
                    } else if ((m = scaleRe.exec(line))) {
                        screenScale = parseFloat(m[1])
                    }
                }
                stateChanged()
            }
        }
    }

    Socket {
        id: niriCommandSocket
        path: Quickshell.env("NIRI_SOCKET") || ""
        connected: false

        onConnectedChanged: {
            if (connected) {
                updateWorkspaces()
                updateWindows()
                updateFocusedWindow()
            }
        }

        parser: SplitParser {
            onRead: (line) => {
                if (!line.trim()) return
                try {
                    const data = JSON.parse(line)
                    if (data?.Ok) {
                        const res = data.Ok
                        if (res.Workspaces) recollectWorkspaces(res.Workspaces)
                        else if (res.Windows) recollectWindows(res.Windows)
                        else if (res.FocusedWindow) recollectFocusedWindow(res.FocusedWindow)
                    }
                } catch (e) {
                    console.warn("Niri socket parse error:", e)
                }
            }
        }
    }

    Socket {
        id: niriEventStream
        path: Quickshell.env("NIRI_SOCKET") || ""
        connected: false

        onConnectedChanged: {
            if (connected)
                startEventStream()
        }

        parser: SplitParser {
            onRead: (data) => {
                if (!data.trim()) return
                try {
                    const event = JSON.parse(data.trim())

                    if (event.WorkspacesChanged)
                        recollectWorkspaces(event.WorkspacesChanged.workspaces)
                    else if (event.WorkspaceActivated)
                        updateWorkspaces()
                    else if (
                        event.WindowFocusChanged ||
                        event.WindowOpenedOrChanged ||
                        event.WindowClosed
                    )
                        updateWindows()
                } catch (e) {
                    console.warn("Niri event stream parse error:", e)
                }
            }
        }
    }

    Process { id: dispatchProc }
}
