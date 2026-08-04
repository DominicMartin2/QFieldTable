import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import org.qgis
import Theme

Item {
    id: plugin
    objectName: "qfieldTablePlugin"

    property var mainWindow: iface.mainWindow()
    property var mapCanvas: iface.mapCanvas()
    property var dashBoard: iface.findItemByObjectName("dashBoard")

    property var vectorLayers: []
    property var selectedLayer: null
    property var previewFeatures: []
    property int previewLimit: 10
    property int totalFeatureCount: 0
    property string diagnosticMessage: ""

    function layerIsVector(layer) {
        if (!layer) return false
        try {
            return layer.type === 0 || layer.type() === 0
        } catch (e) {
            return false
        }
    }

    function layerName(layer) {
        if (!layer) return ""
        try {
            return String(typeof layer.name === "function" ? layer.name() : layer.name)
        } catch (e) {
            return qsTr("Couche sans nom")
        }
    }

    function layerId(layer) {
        if (!layer) return ""
        try {
            return String(typeof layer.id === "function" ? layer.id() : layer.id)
        } catch (e) {
            return ""
        }
    }

    function appendCandidate(layer, seen) {
        if (!layer || !layerIsVector(layer)) return

        var id = layerId(layer)
        var name = layerName(layer)
        if (!id) id = name + "_" + vectorLayers.length
        if (seen[id]) return

        seen[id] = true
        vectorLayers.push(layer)
        layerModel.append({ "label": name, "layerId": id })
    }

    function refreshLayers() {
        vectorLayers = []
        layerModel.clear()
        previewFeatures = []
        diagnosticMessage = ""
        var seen = ({})

        try {
            var projectLayers = qgisProject.mapLayers()
            if (projectLayers) {
                if (Array.isArray(projectLayers)) {
                    for (var i = 0; i < projectLayers.length; ++i)
                        appendCandidate(projectLayers[i], seen)
                } else {
                    for (var key in projectLayers)
                        appendCandidate(projectLayers[key], seen)
                }
            }
        } catch (e1) {
            console.log("QField Table v0.2: qgisProject.mapLayers() indisponible: " + e1)
        }

        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) {
                for (var j = 0; j < canvasLayers.length; ++j)
                    appendCandidate(canvasLayers[j], seen)
            }
        } catch (e2) {
            console.log("QField Table v0.2: mapSettings.layers indisponible: " + e2)
        }

        try {
            appendCandidate(dashBoard.activeLayer, seen)
        } catch (e3) {}

        if (vectorLayers.length > 0) {
            layerCombo.currentIndex = 0
            selectLayer(0)
        } else {
            selectedLayer = null
            totalFeatureCount = 0
            statusLabel.text = qsTr("Aucune couche vectorielle trouvée. Ouvrez un projet et appuyez sur Actualiser.")
        }
    }

    function selectLayer(index) {
        if (index < 0 || index >= vectorLayers.length) return
        selectedLayer = vectorLayers[index]
        inspectSelectedLayer()
    }

    function featureId(feature) {
        if (!feature) return "?"
        try {
            return String(typeof feature.id === "function" ? feature.id() : feature.id)
        } catch (e) {
            return "?"
        }
    }

    function displayName(feature) {
        if (!feature || !selectedLayer) return ""
        try {
            return String(FeatureUtils.displayName(selectedLayer, feature))
        } catch (e) {
            return ""
        }
    }

    function inspectSelectedLayer() {
        previewFeatures = []
        totalFeatureCount = 0
        diagnosticMessage = ""

        if (!selectedLayer) return

        var found = []
        try {
            var iterator = LayerUtils.createFeatureIterator(selectedLayer)
            while (iterator.hasNext()) {
                var feature = iterator.next()
                totalFeatureCount++
                if (found.length < previewLimit)
                    found.push(feature)
            }
            previewFeatures = found
        } catch (error) {
            diagnosticMessage = String(error)
            console.log("QField Table v0.2: " + error)
        }

        statusLabel.text = qsTr("Couche : %1 — %2 enregistrement(s)")
                .arg(layerName(selectedLayer))
                .arg(totalFeatureCount)
    }

    function formatValue(value) {
        if (value === null || value === undefined)
            return "∅"

        var text = String(value)
        if (text.length === 0)
            return "\"\""
        return text
    }

    function openBrowser() {
        refreshLayers()
        browserDialog.open()
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.2 chargé")
    }

    Connections {
        target: iface
        function onLoadProjectEnded() {
            if (browserDialog.visible)
                refreshLayers()
        }
    }

    ListModel { id: layerModel }

    QfToolButton {
        id: pluginButton
        iconSource: "icon.svg"
        iconColor: Theme.mainColor
        bgcolor: Theme.darkGray
        round: true
        onClicked: plugin.openBrowser()
    }

    QfDialog {
        id: browserDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("QField Table — diagnostic v0.2")
        standardButtons: Dialog.Close

        width: Math.min(parent ? parent.width - 24 : 800, 1050)
        height: Math.min(parent ? parent.height - 24 : 700, 900)
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: qsTr("Couche")
                    font.bold: true
                }

                ComboBox {
                    id: layerCombo
                    Layout.fillWidth: true
                    model: layerModel
                    textRole: "label"
                    onActivated: plugin.selectLayer(currentIndex)
                }

                Button {
                    text: qsTr("Actualiser")
                    onClicked: plugin.refreshLayers()
                }
            }

            Label {
                id: statusLabel
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Sélectionnez une couche.")
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Aperçu en lecture seule des %1 premières entités. Les champs et valeurs sont fournis par le FeatureModel natif de QField.").arg(plugin.previewLimit)
                opacity: 0.75
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.diagnosticMessage.length > 0
                text: qsTr("Erreur : %1").arg(plugin.diagnosticMessage)
                wrapMode: Text.WordWrap
                color: Theme.errorColor
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.lightGray
            }

            ListView {
                id: featureList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: plugin.previewFeatures

                ScrollBar.vertical: ScrollBar { }

                delegate: Frame {
                    id: featureFrame
                    required property var modelData
                    property var featureObject: modelData

                    width: featureList.width - (featureList.ScrollBar.vertical.visible ? 14 : 0)
                    height: featureColumn.implicitHeight + 20

                    FeatureModel {
                        id: nativeFeatureModel
                        currentLayer: plugin.selectedLayer
                        feature: featureFrame.featureObject
                    }

                    ColumnLayout {
                        id: featureColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 2

                        Label {
                            Layout.fillWidth: true
                            font.bold: true
                            text: {
                                var fid = plugin.featureId(featureFrame.featureObject)
                                var name = plugin.displayName(featureFrame.featureObject)
                                return name.length > 0
                                        ? qsTr("Entité %1 — %2").arg(fid).arg(name)
                                        : qsTr("Entité %1").arg(fid)
                            }
                        }

                        Repeater {
                            model: nativeFeatureModel

                            delegate: RowLayout {
                                width: featureColumn.width
                                spacing: 6

                                Label {
                                    Layout.preferredWidth: Math.min(280, featureColumn.width * 0.38)
                                    Layout.maximumWidth: Math.min(280, featureColumn.width * 0.38)
                                    font.bold: true
                                    elide: Text.ElideRight
                                    text: model.AttributeName !== undefined ? String(model.AttributeName) : qsTr("Champ")
                                }

                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WrapAnywhere
                                    text: plugin.formatValue(model.AttributeValue)
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: nativeFeatureModel.count === 0
                            text: qsTr("Aucun attribut exposé par FeatureModel pour cette entité.")
                            opacity: 0.7
                        }
                    }
                }

                footer: Label {
                    width: featureList.width
                    visible: plugin.previewFeatures.length === 0 && plugin.diagnosticMessage.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Aucun enregistrement à afficher.")
                    padding: 16
                }
            }
        }
    }
}
