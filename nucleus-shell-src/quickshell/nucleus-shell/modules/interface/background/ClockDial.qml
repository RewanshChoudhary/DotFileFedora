import QtQuick
import qs.modules.components

Item {
    id: root

    property color color: "white"
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real radius: Math.min(width, height) / 2
    opacity: 0.4

    // Hour marks (12 ticks)
    Repeater {
        model: 12

        Item {
            width: root.width
            height: root.height
            anchors.centerIn: parent
            rotation: index * 30
            transformOrigin: Item.Center

            Rectangle {
                width: 3              // thickness of tick
                height: 15            // length of tick
                color: root.color
                anchors.horizontalCenter: parent.horizontalCenter
                y: -root.radius * 0.15 / 2
                radius: width / 2
            }
        }
    }

    // Minute marks (60 ticks)
    Repeater {
        model: 60

        Item {
            width: root.width
            height: root.height
            anchors.centerIn: parent
            rotation: index * 6
            transformOrigin: Item.Center

            Rectangle {
                width: index % 5 === 0 ? 3 : 2   // thicker for 5-minute marks
                height: index % 5 === 0 ? 15 : 8 // longer for 5-minute marks
                color: root.color
                anchors.horizontalCenter: parent.horizontalCenter
                y: -root.radius * 0.15 / 2
                radius: width / 2
            }
        }
    }
}
