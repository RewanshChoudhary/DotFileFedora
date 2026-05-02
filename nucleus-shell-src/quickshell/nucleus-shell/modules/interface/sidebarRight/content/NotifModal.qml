import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.interface.notifications
import qs.services
import qs.config
import qs.modules.components

StyledRect {
    id: root

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Metrics.radius("normal")
    color: Appearance.m3colors.m3surfaceContainerLow
    border.width: 1
    border.color: Appearance.m3colors.m3outlineVariant
    property bool dndActive: Config.runtime.notifications.doNotDisturb
    readonly property int notifCount: NotifServer.data.length

    function toggleDnd() {
        Config.updateKey("notifications.doNotDisturb", !Config.runtime.notifications.doNotDisturb)
    }

    function clearAll() {
        const snapshot = NotifServer.data.slice()
        for (let i = 0; i < snapshot.length; i++) {
            const n = snapshot[i]
            if (n?.notification)
                n.notification.dismiss()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.margin(12)
        spacing: Metrics.spacing(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing(10)

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Metrics.radius("full")
                color: root.dndActive
                    ? Appearance.m3colors.m3tertiaryContainer
                    : Appearance.m3colors.m3primaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    icon: root.dndActive ? "notifications_off" : "notifications_active"
                    iconSize: Metrics.iconSize(18)
                    color: root.dndActive
                        ? Appearance.m3colors.m3onTertiaryContainer
                        : Appearance.m3colors.m3onPrimaryContainer
                }
            }

            ColumnLayout {
                spacing: 1
                StyledText {
                    text: "Notifications"
                    animate: false
                    font.pixelSize: Metrics.fontSize(14)
                    font.weight: Font.Medium
                    color: Appearance.m3colors.m3onSurface
                }
                StyledText {
                    text: root.notifCount === 1
                        ? "1 notification"
                        : root.notifCount + " notifications"
                    animate: false
                    font.pixelSize: Metrics.fontSize(12)
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
            }

            Item { Layout.fillWidth: true }

            StyledButton {
                id: silentButton
                text: root.dndActive ? "Silent" : "Alerts"
                icon: root.dndActive ? "do_not_disturb_on" : "notifications_active"
                implicitHeight: 36
                implicitWidth: 106
                secondary: true
                base_bg: root.dndActive
                    ? Appearance.m3colors.m3tertiaryContainer
                    : Appearance.m3colors.m3secondaryContainer
                base_fg: root.dndActive
                    ? Appearance.m3colors.m3onTertiaryContainer
                    : Appearance.m3colors.m3onSecondaryContainer
                onClicked: toggleDnd()
            }

            StyledButton {
                id: clearButton
                icon: "clear_all"
                text: "Clear"
                implicitHeight: 36
                implicitWidth: 94
                secondary: true
                enabled: root.notifCount > 0
                onClicked: clearAll()
            }
        }

        StyledRect {
            id: listShell
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Metrics.radius("normal")
            color: Appearance.m3colors.m3surface
            border.width: 1
            border.color: Appearance.m3colors.m3outlineVariant

            ListView {
                id: notifList
                anchors.fill: parent
                anchors.margins: Metrics.margin(8)

                clip: true
                spacing: Metrics.spacing(8)
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: Math.max(height, 520)
                ScrollBar.vertical: ScrollBar { }

                model: Config.runtime.notifications.enabled
                    ? NotifServer.history
                    : []

                delegate: NotificationChild {
                    required property var modelData

                    width: notifList.width - Metrics.margin(2)
                    tracked: true
                    title: modelData.summary
                    body: modelData.body
                    appName: modelData.appName
                    isHistory: true
                    timestamp: modelData.timestamp
                    urgency: modelData.urgency
                    image: modelData.image || modelData.appIcon
                    rawNotif: modelData
                    buttons: modelData.uiActions
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Metrics.spacing(6)
                visible: root.notifCount < 1

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 42
                    height: 42
                    radius: Metrics.radius("full")
                    color: Appearance.m3colors.m3surfaceContainerHigh

                    MaterialSymbol {
                        anchors.centerIn: parent
                        icon: "notifications_none"
                        iconSize: Metrics.iconSize(20)
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }
                }

                StyledText {
                    text: "No notifications"
                    animate: false
                    font.pixelSize: Metrics.fontSize(14)
                    color: Appearance.m3colors.m3onSurface
                    Layout.alignment: Qt.AlignHCenter
                }

                StyledText {
                    text: "New alerts will appear here"
                    animate: false
                    font.pixelSize: Metrics.fontSize(12)
                    color: Appearance.m3colors.m3onSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
