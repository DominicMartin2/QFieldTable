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

    // Les objets QgsMapLayer ne peuvent pas être stockés directement dans un ListModel.
    // On conserve donc une liste JavaScript parallèle.
    property var vectorLayers: []
    property var selectedLayer: null
    property int previewLimit: 25

    function layerIsVector(layer) {
        if (!layer) return false
        try {
            // QgsMapLayerType.VectorLayer = 0
            return layer.type === 0 || layer.type() === 0
        } catch (e) {
            // Une couche possédant fields() et featureCount() est très probablement vectorielle.
            try {
                return layer.fields !== undefined && layer.featureCount !== undefined
            } catch (ignored) {
                return false
            }
        }
    }

    function appendCandidate(layer, seen) {
        if (!layer || !layerIsVector(layer)) return

        var id = ""
        var name = "Couche sans nom"
        try { id = String(typeof layer.id === "function" ? layer.id() : layer.id) } catch (e) {}
        try { name = String(typeof layer.name === "function" ? layer.name() : layer.name) } catch (e) {}

        if (!id) id = name + "_" + vectorLayers.length
        if (seen[id]) return
        seen[id] = true

        vectorLayers.push(layer)
        layerModel.append({ "label": name, "layerId": id })
    }

    function refreshLayers() {
        vectorLayers = []
        layerModel.clear()
        var seen = ({})

        // 1) Toutes les couches du projet, lorsque mapLayers() est exposé à QML.
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
            console.log("QField Table: qgisProject.mapLayers() indisponible: " + e1)
        }

        // 2) Repli sur les couches présentes dans les paramètres de la carte.
        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) {
                for (var j = 0; j < canvasLayers.length; ++j)
                    appendCandidate(canvasLayers[j], seen)
            }
        } catch (e2) {
            console.log("QField Table: mapSettings.layers indisponible: " + e2)
        }

        // 3) Toujours inclure la couche active, même si elle est masquée.
        try {
            appendCandidate(dashBoard.activeLayer, seen)
        } catch (e3) {}

        if (vectorLayers.length > 0) {
            layerCombo.currentIndex = 0
            selectLayer(0)
        } else {
            selectedLayer = null
            statusLabel.text = qsTr("Aucune couche vectorielle trouvée. Ouvrez un projet et appuyez sur Actualiser.")
            diagnosticsModel.clear()
        }
    }

    function selectLayer(index) {
        if (index < 0 || index >= vectorLayers.length) return
        selectedLayer = vectorLayers[index]
        inspectSelectedLayer()
    }

    function safeFeatureCount(layer) {
        try {
            return Number(typeof layer.featureCount === "function" ? layer.featureCount() : layer.featureCount)
        } catch (e) {
            return -1
        }
    }

    function fieldNameAt(fields, index) {
        var field = null
        try { field = fields.at(index) } catch (e1) {
            try { field = fields[index] } catch (e2) {}
        }
        if (!field) return "champ_" + index
        try { return String(typeof field.name === "function" ? field.name() : field.name) } catch (e3) {}
        return "champ_" + index
    }

    function fieldCount(fields) {
        try { return Number(typeof fields.count === "function" ? fields.count() : fields.count) } catch (e1) {}
        try { return Number(typeof fields.size === "function" ? fields.size() : fields.size) } catch (e2) {}
        try { return fields.length } catch (e3) {}
        return 0
    }

    function featureFields(feature, layer) {
        try { return typeof feature.fields === "function" ? feature.fields() : feature.fields } catch (e1) {}
        try { return typeof layer.fields === "function" ? layer.fields() : layer.fields } catch (e2) {}
        return null
    }

    function attributeValue(feature, fieldName, fieldIndex) {
        try {
            var value = feature.attribute(fieldName)
            return value === null || value === undefined ? "∅" : String(value)
        } catch (e1) {
            try {
                var value2 = feature.attribute(fieldIndex)
                return value2 === null || value2 === undefined ? "∅" : String(value2)
            } catch (e2) {
                return "[lecture impossible]"
            }
        }
    }

    function inspectSelectedLayer() {
        diagnosticsModel.clear()
        if (!selectedLayer) return

        var layerName = ""
        try { layerName = String(typeof selectedLayer.name === "function" ? selectedLayer.name() : selectedLayer.name) } catch (e) {}
        var count = safeFeatureCount(selectedLayer)
        statusLabel.text = qsTr("Couche : %1 — %2 enregistrement(s)").arg(layerName).arg(count >= 0 ? count : "?")

        try {
            var iterator = LayerUtils.createFeatureIterator(selectedLayer)
            var row = 0
            while (iterator.hasNext() && row < previewLimit) {
                var feature = iterator.next()
                var fid = "?"
                try { fid = String(typeof feature.id === "function" ? feature.id() : feature.id) } catch (ignored) {}

                var fields = featureFields(feature, selectedLayer)
                var numberOfFields = fieldCount(fields)
                if (numberOfFields === 0) {
                    diagnosticsModel.append({
                        "title": qsTr("Entité %1").arg(fid),
                        "details": qsTr("Impossible d’énumérer les champs dans cette version de QField.")
                    })
                } else {
                    var lines = []
                    for (var i = 0; i < numberOfFields; ++i) {
                        var fieldName = fieldNameAt(fields, i)
                        lines.push(fieldName + " = " + attributeValue(feature, fieldName, i))
                    }
                    diagnosticsModel.append({
                        "title": qsTr("Entité %1").arg(fid),
                        "details": lines.join("\n")
                    })
                }
                row++
            }

            if (row === 0) {
                diagnosticsModel.append({
                    "title": qsTr("Aucun enregistrement"),
                    "details": qsTr("La couche est vide ou son fournisseur n’a retourné aucune entité.")
                })
            }
        } catch (error) {
            diagnosticsModel.append({
                "title": qsTr("Erreur de diagnostic"),
                "details": String(error)
            })
            console.log("QField Table: " + error)
        }
    }

    function openBrowser() {
        refreshLayers()
        browserDialog.open()
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.1 chargé")
    }

    Connections {
        target: iface
        function onLoadProjectEnded() {
            if (browserDialog.visible)
                refreshLayers()
        }
    }

    ListModel { id: layerModel }
    ListModel { id: diagnosticsModel }

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
        title: qsTr("QField Table — diagnostic v0.1")
        standardButtons: Dialog.Close

        width: Math.min(parent ? parent.width - 24 : 800, 1000)
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
                text: qsTr("Aperçu en lecture seule des %1 premières entités. Cette version sert à confirmer l’accès QML aux couches, champs et attributs.").arg(plugin.previewLimit)
                opacity: 0.75
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.lightGray
            }

            ListView {
                id: diagnosticsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: diagnosticsModel

                ScrollBar.vertical: ScrollBar { }

                delegate: Frame {
                    required property string title
                    required property string details
                    width: diagnosticsList.width - (diagnosticsList.ScrollBar.vertical.visible ? 14 : 0)

                    ColumnLayout {
                        width: parent.width
                        Label {
                            Layout.fillWidth: true
                            text: title
                            font.bold: true
                        }
                        TextArea {
                            Layout.fillWidth: true
                            text: details
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.NoWrap
                            background: null
                        }
                    }
                }
            }
        }
    }
}
