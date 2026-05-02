import qs.config
import qs.modules.components
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property string title: "No Title"
    property string body: "No content"
    property var rawNotif: null
    property bool tracked: false
    property bool isHistory: false
    property string image: ""
    property string appName: "notify-send"
    property string timestamp: Qt.formatTime(new Date(), "hh:mm")
    property int urgency: 1
    property var buttons: [
        { label: "Okay!", onClick: () => console.log("Okay") }
    ]

    property bool isCritical: urgency === 2
    property bool singleActionClickable: buttons.length <= 1
    property real animProgress: tracked ? 1.0 : 0.0

    readonly property color tonePrimary: isCritical ? Appearance.m3colors.m3onErrorContainer : Appearance.m3colors.m3onSurface
    readonly property color toneSecondary: isCritical ? Appearance.m3colors.m3onErrorContainer : Appearance.m3colors.m3onSurfaceVariant
    readonly property color toneAccent: isCritical ? Appearance.m3colors.m3error : Appearance.m3colors.m3primary
    readonly property color bgIdle: isCritical ? Appearance.m3colors.m3errorContainer : Appearance.m3colors.m3surface
    readonly property color bgHover: isCritical ? Qt.darker(Appearance.m3colors.m3errorContainer, 1.05) : Appearance.m3colors.m3surfaceContainerLow
    readonly property color bgPressed: isCritical ? Qt.darker(Appearance.m3colors.m3errorContainer, 1.1) : Appearance.m3colors.m3surfaceContainer
    readonly property color iconBubble: isCritical ? Qt.darker(Appearance.m3colors.m3errorContainer, 1.12) : Appearance.m3colors.m3surfaceContainerHigh
    readonly property color timestampBg: isCritical ? Qt.darker(Appearance.m3colors.m3errorContainer, 1.08) : Appearance.m3colors.m3surfaceContainerLow
    readonly property color outline: isCritical ? Appearance.m3colors.m3error : Appearance.m3colors.m3outlineVariant

    function dismissNotification() {
        if (!root.rawNotif)
            return

        root.rawNotif.popup = false
        if (root.isHistory && root.rawNotif.notification)
            root.rawNotif.notification.dismiss()
    }

    function invokePrimaryActionAndDismiss() {
        if (root.buttons.length === 1 && root.buttons[0].onClick)
            root.buttons[0].onClick()
        dismissNotification()
    }

    opacity: animProgress
    clip: true

    transform: [
        Translate {
            y: (1.0 - root.animProgress) * -30
        },
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: 0.85 + (root.animProgress * 0.15)
            yScale: 0.85 + (root.animProgress * 0.15)
        }
    ]

    Behavior on animProgress {
        enabled: Config.runtime.appearance.animations.enabled
        NumberAnimation {
            duration: Metrics.chronoDuration("normal")
            easing.type: Easing.OutExpo
        }
    }

    Layout.fillWidth: true
    radius: Metrics.radius("normal")
    border.width: 1
    border.color: root.outline

    property bool hovered: mouseHandler.containsMouse
    property bool clicked: mouseHandler.containsPress

    color: {
        if (hovered)
            return clicked ? root.bgPressed : root.bgHover
        return root.bgIdle
    }

    Behavior on color {
        enabled: Config.runtime.appearance.animations.enabled
        ColorAnimation {
            duration: Metrics.chronoDuration("small")
            easing.type: Easing.InOutExpo
        }
    }

    Behavior on border.color {
        enabled: Config.runtime.appearance.animations.enabled
        ColorAnimation {
            duration: Metrics.chronoDuration("small")
            easing.type: Easing.InOutExpo
        }
    }

    implicitHeight: mainColumn.implicitHeight + Metrics.margin(12) * 2
    implicitWidth: 360

    Rectangle {
        id: accentBar
        width: Metrics.margin(4)
        radius: width / 2
        color: root.toneAccent
        anchors.left: parent.left
        anchors.leftMargin: Metrics.margin(8)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Metrics.margin(10)
        anchors.bottomMargin: Metrics.margin(10)
    }

    ColumnLayout {
        id: mainColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Metrics.margin(14)
            leftMargin: Metrics.margin(18)
        }
        spacing: Metrics.spacing(5)

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing(6)

            ClippingRectangle {
                width: 24
                height: 24
                radius: Metrics.radius("small")
                clip: true
                color: root.iconBubble

                IconImage {
                    id: appIconImage
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root.image
                    smooth: true
                    visible: root.image !== ""
                }
                MaterialSymbol {
                    icon: root.isCritical ? "warning" : "chat"
                    color: root.toneSecondary
                    anchors.centerIn: parent
                    visible: root.image === ""
                    iconSize: Metrics.iconSize(16)
                }
            }

            StyledText {
                text: root.appName
                animate: false
                font.pixelSize: Metrics.fontSize(12)
                color: root.toneSecondary
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: timestampText.implicitWidth + Metrics.margin(10)
                implicitHeight: 22
                radius: Metrics.radius("full")
                color: root.timestampBg

                StyledText {
                    id: timestampText
                    anchors.centerIn: parent
                    text: root.timestamp
                    animate: false
                    font.pixelSize: Metrics.fontSize(11)
                    color: root.toneSecondary
                }
            }

            Loader {
                active: root.singleActionClickable
                sourceComponent: Component {
                    Rectangle {
                        width: 20
                        height: 20
                        radius: width / 2
                        color: closeHover.containsMouse
                            ? (root.isCritical ? Qt.darker(root.iconBubble, 1.08) : Appearance.m3colors.m3surfaceContainerHigh)
                            : "transparent"

                        Behavior on color {
                            enabled: Config.runtime.appearance.animations.enabled
                            ColorAnimation { duration: Metrics.chronoDuration("small") }
                        }

                        MaterialSymbol {
                            icon: "close"
                            color: root.toneSecondary
                            anchors.centerIn: parent
                            iconSize: Metrics.iconSize(14)
                        }

                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                root.dismissNotification()
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            text: root.title
            animate: false
            font.pixelSize: Metrics.fontSize(15)
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            color: root.tonePrimary
            Layout.fillWidth: true
            Layout.topMargin: Metrics.margin(2)
        }

        StyledText {
            text: root.body
            animate: false
            visible: root.body.length > 0
            font.pixelSize: Metrics.fontSize(12)
            color: root.toneSecondary
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        RowLayout {
            visible: root.buttons.length > 1
            Layout.preferredHeight: 40
            Layout.fillWidth: true
            Layout.topMargin: Metrics.margin(4)
            spacing: Metrics.spacing(10)

            Repeater {
                model: buttons

                StyledButton {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    implicitWidth: 0
                    text: modelData.label
                    base_bg: {
                        if (root.isCritical)
                            return index === 0 ? Appearance.m3colors.m3error : Appearance.m3colors.m3errorContainer
                        return index === 0 ? Appearance.m3colors.m3primaryContainer : Appearance.m3colors.m3secondaryContainer
                    }
                    base_fg: {
                        if (root.isCritical)
                            return index === 0 ? Appearance.m3colors.m3onError : Appearance.m3colors.m3onErrorContainer
                        return index === 0 ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSecondaryContainer
                    }
                    onClicked: modelData.onClick()
                }
            }
        }
    }

    MouseArea {
        id: mouseHandler
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: root.singleActionClickable ? Qt.LeftButton : Qt.NoButton
        cursorShape: root.singleActionClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            mouse.accepted = true
            root.invokePrimaryActionAndDismiss()
        }
    }

    Component.onCompleted: {
        animProgress = 1.0
    }
}
