pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import qs.config

// from github.com/end-4/dots-hyprland with modifications

Singleton {
    id: root

    property list<Notif> data: []
    property list<Notif> popups: {
        let result = []
        for (let i = 0; i < data.length; i++) {
            if (data[i].popup && !data[i].pendingRemoval)
                result.push(data[i])
        }
        return result
    }
    property list<Notif> history: data
    property int maxHistoryEntries: 120
    property int maxPopupEntries: 4

    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const wrappedNotif = notifComp.createObject(root, {
                popup: true,
                notification: notif,
                shown: false
            });
            if (!wrappedNotif)
                return

            root.data.push(wrappedNotif);
            root.limitPopupCount();
            root.trimHistory();
        }
    }

    function limitPopupCount() {
        let visiblePopups = 0
        for (let i = data.length - 1; i >= 0; i--) {
            const entry = data[i]
            if (!entry || !entry.popup || entry.pendingRemoval)
                continue

            visiblePopups++
            if (visiblePopups > root.maxPopupEntries)
                entry.popup = false
        }
    }

    function trimHistory() {
        const overflow = root.data.length - root.maxHistoryEntries
        if (overflow <= 0)
            return

        let removed = 0
        for (let i = 0; i < root.data.length && removed < overflow; i++) {
            const entry = root.data[i]
            if (!entry || entry.pendingRemoval)
                continue

            entry.pendingRemoval = true
            entry.popup = false

            if (entry.notification) {
                entry.notification.dismiss()
            } else {
                root.data.splice(i, 1)
                i--
            }
            removed++
        }
    }

    function removeEntry(entry) {
        const i = data.indexOf(entry)
        if (i >= 0)
            data.splice(i, 1)
    }

    function removeById(id) {
        const i = data.findIndex(n => n.notification.id === id);
        if (i >= 0) {
            const entry = data[i]
            if (!entry)
                return

            entry.pendingRemoval = true
            entry.popup = false
            if (entry.notification)
                entry.notification.dismiss()
            else
                data.splice(i, 1);
        }
    }


    component Notif: QtObject {
        id: notif

        property bool popup
        readonly property date time: new Date()
        readonly property string timestamp: Qt.formatTime(time, "hh:mm")
        readonly property string timeStr: {
            const diff = Time.date.getTime() - time.getTime();
            const m = Math.floor(diff / 60000);
            const h = Math.floor(m / 60);

            if (h < 1 && m < 1)
                return "now";
            if (h < 1)
                return `${m}m`;
            return `${h}h`;
        }

        property bool shown: false
        property bool pendingRemoval: false
        required property Notification notification
        readonly property string summary: notification.summary
        readonly property string body: notification.body
        readonly property string appIcon: notification.appIcon
        readonly property string appName: notification.appName
        readonly property string image: notification.image
        readonly property int urgency: notification.urgency
        readonly property list<NotificationAction> actions: notification.actions
        readonly property var uiActions: {
            const mapped = []
            const actionList = notification.actions || []
            for (let i = 0; i < actionList.length; i++) {
                const action = actionList[i]
                if (!action)
                    continue
                mapped.push({
                    "label": action.text,
                    "onClick": () => action.invoke()
                })
            }
            return mapped
        }

        readonly property Timer timer: Timer {
            running: true
            interval: {
                if (notif.notification.expireTimeout > 0)
                    return notif.notification.expireTimeout
                if (notif.urgency === 2)
                    return 15000  // critical: 15 seconds
                return 5000
            }
            onTriggered: {
                notif.popup = false
            }
        }

        readonly property Connections conn2: Connections {
            target: notif.notification

            function onClosed(reason) {
                root.removeEntry(notif)
            }
        }

        readonly property Connections conn: Connections {
            target: notif.notification.Retainable

            function onDropped(): void {
                root.removeEntry(notif)
            }

            function onAboutToDestroy(): void {
                notif.destroy()
            }
        }

    }

    Component {
        id: notifComp

        Notif {}
    }
}
