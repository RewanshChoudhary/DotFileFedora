import QtQuick
import QtQuick.Layouts
import qs.config
import qs.plugins

ColumnLayout {
    id: pluginColumn
    Layout.fillWidth: true
    spacing: 8
    implicitHeight: childrenRect.height

    Repeater {
        model: PluginLoader.plugins

        delegate: ContentCard {
            Layout.fillWidth: true

            Loader {
                Layout.fillWidth: true
                asynchronous: true
                source: Qt.resolvedUrl(
                    Directories.shellConfig + "/plugins/" + modelData + "/Settings.qml"
                )

                onStatusChanged: {
                    if (status === Loader.Ready) {
                        // recompute height when loader finishes loading
                        pluginColumn.implicitHeight = pluginColumn.childrenRect.height
                    }
                }
            }
        }
    }
}
