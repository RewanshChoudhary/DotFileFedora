import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.services
import qs.config
import qs.modules.components
import qs.modules.functions

Scope {
    id: root

    property int innerSpacing: Metrics.spacing(10)
    property int topOffset: Metrics.margin(10)
    property int horizontalInset: Metrics.margin(20)
    property int stackPadding: Metrics.margin(16)
    readonly property bool popupsEnabled: Config.runtime.notifications.enabled && !Config.runtime.notifications.doNotDisturb

    PanelWindow {
        id: window

        implicitWidth: 550
        visible: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Normal
        WlrLayershell.namespace: "nucleus:notification"

        anchors {
            top: true
            left: Config.runtime.notifications.position.endsWith("left")
            bottom: true
            right: Config.runtime.notifications.position.endsWith("right")
        }

        Item {
            id: notificationList
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: root.topOffset

            Rectangle {
                id: bgRectangle

                layer.enabled: height > 0
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: root.horizontalInset
                anchors.rightMargin: root.horizontalInset
                anchors.right: parent.right
                height: popupList.contentHeight > 0 ? popupList.contentHeight + root.stackPadding * 2 : 0
                color: popupList.contentHeight > 0
                    ? ColorUtils.applyAlpha(Appearance.m3colors.m3surfaceContainerLow, 0.42)
                    : "transparent"
                radius: Metrics.radius("verylarge")
                border.width: popupList.contentHeight > 0 ? 1 : 0
                border.color: Appearance.m3colors.m3outlineVariant

                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowOpacity: 0.92
                    shadowColor: Appearance.m3colors.m3shadow
                    shadowBlur: 0.9
                    shadowScale: 1
                }

                Behavior on height {
                    enabled: Config.runtime.appearance.animations.enabled
                    NumberAnimation {
                        duration: Metrics.chronoDuration("small")
                        easing.type: Easing.InOutExpo
                    }
                }
            }

            ListView {
                id: popupList

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.horizontalInset
                anchors.rightMargin: root.horizontalInset
                anchors.topMargin: root.stackPadding
                height: contentHeight

                clip: false
                interactive: false
                spacing: root.innerSpacing
                boundsBehavior: Flickable.StopAtBounds
                model: root.popupsEnabled ? NotifServer.popups : []

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Metrics.chronoDuration("small")
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            properties: "x,y"
                            duration: Metrics.chronoDuration("normal")
                            easing.type: Easing.InOutExpo
                        }
                    }
                }
                move: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Metrics.chronoDuration("normal")
                        easing.type: Easing.InOutExpo
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Metrics.chronoDuration("normal")
                        easing.type: Easing.InOutExpo
                    }
                }
                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Metrics.chronoDuration("small")
                        easing.type: Easing.InCubic
                    }
                }

                delegate: NotificationChild {
                    required property var modelData

                    width: popupList.width

                    Component.onCompleted: {
                        if (!modelData.shown)
                            modelData.shown = true
                    }

                    title: modelData.summary
                    appName: modelData.appName
                    timestamp: modelData.timestamp
                    body: modelData.body
                    image: modelData.image || modelData.appIcon
                    urgency: modelData.urgency
                    rawNotif: modelData
                    tracked: modelData.shown
                    buttons: modelData.uiActions
                }
            }
        }

        mask: Region {
            width: window.width
            height: root.topOffset + bgRectangle.height
        }

    }

}
