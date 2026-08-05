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
    property int previewLimit: 100
    property int totalFeatureCount: 0

    // [{ alias, fieldName, fieldIndex, sampleValue }]
    property var columns: []
    // [{ featureId, values: [] }]
    property var flatRows: []
    property var filteredRows: []
    property string diagnosticMessage: ""
    property string selectedFeatureId: ""

    function layerIsVector(layer) {
        if (!layer) return false
        try { return layer.type === 0 || layer.type() === 0 } catch (e) { return false }
    }

    function layerName(layer) {
        if (!layer) return ""
        try { return String(typeof layer.name === "function" ? layer.name() : layer.name) }
        catch (e) { return qsTr("Couche sans nom") }
    }

    function layerId(layer) {
        if (!layer) return ""
        try { return String(typeof layer.id === "function" ? layer.id() : layer.id) }
        catch (e) { return "" }
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
        resetData()
        var seen = ({})

        try {
            var projectLayers = qgisProject.mapLayers()
            if (projectLayers) {
                if (Array.isArray(projectLayers)) {
                    for (var i = 0; i < projectLayers.length; ++i) appendCandidate(projectLayers[i], seen)
                } else {
                    for (var key in projectLayers) appendCandidate(projectLayers[key], seen)
                }
            }
        } catch (e1) { console.log("QField Table v0.5.0 mapLayers: " + e1) }

        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) for (var j = 0; j < canvasLayers.length; ++j) appendCandidate(canvasLayers[j], seen)
        } catch (e2) { console.log("QField Table v0.5.0 canvas layers: " + e2) }

        try { appendCandidate(dashBoard.activeLayer, seen) } catch (e3) {}

        if (vectorLayers.length > 0) {
            layerCombo.currentIndex = 0
            selectLayer(0)
        } else {
            selectedLayer = null
            statusLabel.text = qsTr("Aucune couche vectorielle trouvée.")
        }
    }

    function selectLayer(index) {
        if (index < 0 || index >= vectorLayers.length) return
        selectedLayer = vectorLayers[index]
        inspectSelectedLayer()
    }

    function resetData() {
        previewFeatures = []
        totalFeatureCount = 0
        columns = []
        flatRows = []
        filteredRows = []
        selectedFeatureId = ""
        diagnosticMessage = ""
        if (searchField) searchField.text = ""
    }

    function inspectSelectedLayer() {
        resetData()
        if (!selectedLayer) return

        var found = []
        try {
            var iterator = LayerUtils.createFeatureIterator(selectedLayer)
            while (iterator.hasNext()) {
                var feature = iterator.next()
                totalFeatureCount++
                if (found.length < previewLimit) found.push(feature)
            }
            previewFeatures = found
        } catch (error) {
            diagnosticMessage = String(error)
            console.log("QField Table v0.5.0 iterator: " + error)
        }

        statusLabel.text = qsTr("Couche : %1 — %2 enregistrement(s); %3 chargé(s)")
                .arg(layerName(selectedLayer)).arg(totalFeatureCount).arg(previewFeatures.length)
        schemaPollTimer.restart()
    }

    function featureId(feature) {
        if (!feature) return "?"
        try { return String(typeof feature.id === "function" ? feature.id() : feature.id) }
        catch (e) { return "?" }
    }

    function formatValue(value) {
        if (value === null || value === undefined) return ""
        var text = String(value)
        return text
    }

    function fieldObjectName(fieldObject) {
        if (fieldObject === null || fieldObject === undefined) return ""
        try {
            if (typeof fieldObject.name === "function") return String(fieldObject.name())
            if (fieldObject.name !== undefined) return String(fieldObject.name)
        } catch (e) {}
        return ""
    }

    function registerColumn(aliasValue, fieldObject, fieldIndexValue, sampleValue) {
        var aliasText = aliasValue === undefined ? "" : String(aliasValue)
        var technicalName = fieldObjectName(fieldObject)
        var indexValue = -1
        if (fieldIndexValue !== undefined && fieldIndexValue !== null && !isNaN(Number(fieldIndexValue)))
            indexValue = Number(fieldIndexValue)

        for (var i = 0; i < columns.length; ++i) {
            if ((technicalName.length > 0 && columns[i].fieldName === technicalName) ||
                    (technicalName.length === 0 && columns[i].alias === aliasText && columns[i].fieldIndex === indexValue))
                return
        }

        var next = columns.slice(0)
        next.push({
            "alias": aliasText,
            "fieldName": technicalName,
            "fieldIndex": indexValue,
            "sampleValue": formatValue(sampleValue)
        })
        columns = next
        rowBuildTimer.restart()
    }

    function readAttribute(feature, column) {
        if (!feature || !column) return ""
        var value

        if (column.fieldName && column.fieldName.length > 0) {
            try {
                value = feature.attribute(column.fieldName)
                if (value !== undefined) return formatValue(value)
            } catch (e1) {}
        }

        if (column.fieldIndex >= 0) {
            try {
                value = feature.attribute(column.fieldIndex)
                if (value !== undefined) return formatValue(value)
            } catch (e2) {}
        }

        return ""
    }

    function buildRows() {
        if (columns.length === 0 || previewFeatures.length === 0) return
        var result = []
        for (var r = 0; r < previewFeatures.length; ++r) {
            var feature = previewFeatures[r]
            var values = []
            for (var c = 0; c < columns.length; ++c)
                values.push(readAttribute(feature, columns[c]))
            result.push({ "featureId": featureId(feature), "values": values })
        }
        flatRows = result
        applySearch()
    }

    function applySearch() {
        var term = searchField ? String(searchField.text).toLowerCase().trim() : ""
        if (term.length === 0) {
            filteredRows = flatRows.slice(0)
            return
        }

        var result = []
        for (var r = 0; r < flatRows.length; ++r) {
            var row = flatRows[r]
            var found = String(row.featureId).toLowerCase().indexOf(term) >= 0
            if (!found) {
                for (var c = 0; c < row.values.length; ++c) {
                    if (String(row.values[c]).toLowerCase().indexOf(term) >= 0) {
                        found = true
                        break
                    }
                }
            }
            if (found) result.push(row)
        }
        filteredRows = result
    }

    function openBrowser() {
        refreshLayers()
        browserDialog.open()
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.5.0 chargé")
    }

    Connections {
        target: iface
        function onLoadProjectEnded() { if (browserDialog.visible) refreshLayers() }
    }

    Timer {
        id: schemaPollTimer
        interval: 250
        repeat: true
        running: false
        property int attempts: 0
        onTriggered: {
            attempts++
            if (plugin.columns.length > 0) {
                // Laisse un bref délai pour que le Repeater ait enregistré tout le schéma.
                rowBuildTimer.restart()
                if (attempts >= 4) {
                    stop()
                    attempts = 0
                }
            } else if (attempts >= 20) {
                stop()
                attempts = 0
                plugin.diagnosticMessage = qsTr("Le FeatureModel n'a exposé aucun attribut après 5 secondes.")
            }
        }
        function restart() {
            stop()
            attempts = 0
            start()
        }
    }

    Timer {
        id: rowBuildTimer
        interval: 220
        repeat: false
        onTriggered: plugin.buildRows()
    }

    Timer {
        id: searchTimer
        interval: 250
        repeat: false
        onTriggered: plugin.applySearch()
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
        title: qsTr("QField Table — v0.5.0")
        standardButtons: Dialog.Close
        width: Math.min(parent ? parent.width - 24 : 900, 1500)
        height: Math.min(parent ? parent.height - 24 : 750, 980)
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("Couche"); font.bold: true }
                ComboBox {
                    id: layerCombo
                    Layout.fillWidth: true
                    model: layerModel
                    textRole: "label"
                    onActivated: plugin.selectLayer(currentIndex)
                }
                Button { text: qsTr("Actualiser"); onClicked: plugin.refreshLayers() }
            }

            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Rechercher dans tous les champs…")
                    onTextChanged: searchTimer.restart()
                }
                Label {
                    text: qsTr("%1 résultat(s) sur %2 chargé(s)")
                            .arg(plugin.filteredRows.length).arg(plugin.flatRows.length)
                    font.bold: true
                }
            }

            Label { id: statusLabel; Layout.fillWidth: true; wrapMode: Text.WordWrap }

            Label {
                Layout.fillWidth: true
                visible: plugin.diagnosticMessage.length > 0
                text: qsTr("Erreur : %1").arg(plugin.diagnosticMessage)
                color: Theme.errorColor
                wrapMode: Text.WordWrap
            }

            // Collecteur de schéma. Il reste visible dans l'arbre QML, mais son
            // empreinte est réduite à un pixel. Le Repeater instancie tous les
            // attributs du FeatureModel, contrairement au ListView virtualisé.
            Item {
                id: schemaCollector
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                opacity: 0.01
                visible: plugin.previewFeatures.length > 0
                clip: true

                property var referenceFeature: plugin.previewFeatures.length > 0 ? plugin.previewFeatures[0] : null

                FeatureModel {
                    id: referenceFeatureModel
                    currentLayer: plugin.selectedLayer
                    feature: schemaCollector.referenceFeature
                }

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    Repeater {
                        model: referenceFeatureModel
                        delegate: Item {
                            width: 1
                            height: 1
                            property var roleField: model.Field !== undefined ? model.Field : null
                            property var roleIndex: model.FieldIndex !== undefined ? model.FieldIndex : index
                            Component.onCompleted: plugin.registerColumn(
                                                       model.AttributeName,
                                                       roleField,
                                                       roleIndex,
                                                       model.AttributeValue)
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightGray }

            Flickable {
                id: tableFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: tableContent.width
                contentHeight: tableContent.height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalAndVerticalFlick
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOn }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

                Column {
                    id: tableContent
                    property int idWidth: 90
                    property int cellWidth: 190
                    width: idWidth + plugin.columns.length * cellWidth
                    spacing: 0

                    Row {
                        Rectangle {
                            width: tableContent.idWidth
                            height: 54
                            border.width: 1
                            border.color: Theme.lightGray
                            color: "#f8f8f8"
                            Label {
                                anchors.fill: parent
                                anchors.margins: 6
                                font.bold: true
                                text: qsTr("Entité")
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Repeater {
                            model: plugin.columns
                            delegate: Rectangle {
                                required property var modelData
                                width: tableContent.cellWidth
                                height: 54
                                border.width: 1
                                border.color: Theme.lightGray
                                color: "#f8f8f8"
                                Label {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    text: modelData.alias || modelData.fieldName || qsTr("Champ")
                                }
                                ToolTip.visible: headerMouse.containsMouse
                                ToolTip.text: modelData.fieldName || ""
                                MouseArea {
                                    id: headerMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }
                    }

                    Repeater {
                        model: plugin.filteredRows
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: tableContent.width
                            height: 40

                            Rectangle {
                                anchors.fill: parent
                                color: plugin.selectedFeatureId === String(modelData.featureId)
                                       ? Theme.mainColor
                                       : (index % 2 ? "#f4f4f4" : "transparent")
                                opacity: plugin.selectedFeatureId === String(modelData.featureId) ? 0.22 : 1
                            }

                            Row {
                                anchors.fill: parent
                                Rectangle {
                                    width: tableContent.idWidth
                                    height: 40
                                    border.width: 1
                                    border.color: Theme.lightGray
                                    color: "transparent"
                                    Label {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: modelData.featureId
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Repeater {
                                    model: plugin.columns.length
                                    delegate: Rectangle {
                                        required property int index
                                        width: tableContent.cellWidth
                                        height: 40
                                        border.width: 1
                                        border.color: Theme.lightGray
                                        color: "transparent"
                                        Label {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.values[index] !== undefined ? modelData.values[index] : ""
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: plugin.selectedFeatureId = String(modelData.featureId)
                            }
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                opacity: 0.75
                text: plugin.selectedFeatureId.length > 0
                      ? qsTr("Entité sélectionnée : %1").arg(plugin.selectedFeatureId)
                      : qsTr("Cliquez sur une ligne pour la sélectionner.")
            }
        }
    }
}
