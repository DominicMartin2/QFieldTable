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
    property var sourceFeatures: []
    property var flatRows: []
    property var columnNames: []

    property int totalFeatureCount: 0
    property int previewLimit: 10
    property int displayColumnLimit: 12
    property int receivedCells: 0
    property int completedRows: 0
    property int collectionGeneration: 0
    property bool collectionActive: false
    property string diagnosticMessage: ""

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
        resetCollection()
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
        } catch (e1) { console.log("QField Table v0.4.0 mapLayers: " + e1) }

        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) {
                for (var j = 0; j < canvasLayers.length; ++j) appendCandidate(canvasLayers[j], seen)
            }
        } catch (e2) { console.log("QField Table v0.4.0 canvas layers: " + e2) }

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
        loadFeatures()
    }

    function featureId(feature) {
        if (!feature) return "?"
        try { return String(typeof feature.id === "function" ? feature.id() : feature.id) }
        catch (e) { return "?" }
    }

    function formatValue(value) {
        if (value === null || value === undefined) return ""
        var text = String(value)
        if (text === "Invalid Date" || text === "NULL" || text === "undefined") return ""
        if (text === "\"\"") return ""
        return text
    }

    function resetCollection() {
        collectionGeneration++
        collectionActive = false
        sourceFeatures = []
        flatRows = []
        columnNames = []
        receivedCells = 0
        completedRows = 0
        diagnosticMessage = ""
        diagnosticSummary.text = qsTr("En attente de la lecture...")
    }

    function loadFeatures() {
        resetCollection()
        totalFeatureCount = 0
        if (!selectedLayer) return

        var found = []
        try {
            var iterator = LayerUtils.createFeatureIterator(selectedLayer)
            while (iterator.hasNext()) {
                var feature = iterator.next()
                totalFeatureCount++
                if (found.length < previewLimit) found.push(feature)
            }
            sourceFeatures = found
            collectionActive = found.length > 0
        } catch (error) {
            diagnosticMessage = String(error)
            console.log("QField Table v0.4.0: " + error)
        }

        statusLabel.text = qsTr("Couche : %1 — %2 enregistrement(s); lecture des %3 premières lignes")
                .arg(layerName(selectedLayer)).arg(totalFeatureCount).arg(sourceFeatures.length)
        settleTimer.restart()
    }

    function registerCell(generation, rowIndex, columnIndex, attributeName, attributeValue, rowFieldCount) {
        if (generation !== collectionGeneration) return
        if (rowIndex < 0 || rowIndex >= sourceFeatures.length) return

        var rows = flatRows.slice(0)
        var row = rows[rowIndex]
        if (!row) {
            row = {
                "fid": featureId(sourceFeatures[rowIndex]),
                "values": [],
                "receivedMap": ({}),
                "received": 0,
                "fieldCount": rowFieldCount
            }
        }

        var values = row.values.slice(0)
        var receivedMap = row.receivedMap || ({})
        if (!receivedMap[columnIndex]) {
            receivedMap[columnIndex] = true
            row.received++
            receivedCells++
        }
        values[columnIndex] = formatValue(attributeValue)
        row.values = values
        row.receivedMap = receivedMap
        row.fieldCount = Math.max(row.fieldCount || 0, rowFieldCount || 0)
        rows[rowIndex] = row
        flatRows = rows

        if (rowIndex === 0) {
            var names = columnNames.slice(0)
            names[columnIndex] = String(attributeName !== undefined ? attributeName : ("champ_" + columnIndex))
            columnNames = names
        }

        updateCompletedRows(rows)
        settleTimer.restart()
    }

    function updateCompletedRows(rows) {
        var done = 0
        for (var i = 0; i < rows.length; ++i) {
            var row = rows[i]
            if (row && row.fieldCount > 0 && row.received >= row.fieldCount) done++
        }
        completedRows = done
    }

    function finaliseDiagnostic() {
        var prepared = 0
        for (var i = 0; i < flatRows.length; ++i) {
            if (flatRows[i] && flatRows[i].values) prepared += flatRows[i].values.length
        }
        diagnosticSummary.text = qsTr("%1 ligne(s) chargée(s) — %2 colonne(s) détectée(s) — %3 cellule(s) préparée(s) — %4/%5 lignes complètes")
                .arg(flatRows.length)
                .arg(columnNames.length)
                .arg(prepared)
                .arg(completedRows)
                .arg(sourceFeatures.length)
        collectionActive = false
    }

    function openBrowser() {
        refreshLayers()
        browserDialog.open()
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.4.0 chargé")
    }

    Connections {
        target: iface
        function onLoadProjectEnded() { if (browserDialog.visible) refreshLayers() }
    }

    Timer {
        id: settleTimer
        interval: 700
        repeat: false
        onTriggered: plugin.finaliseDiagnostic()
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
        title: qsTr("QField Table — v0.4.0")
        standardButtons: Dialog.Close
        width: Math.min(parent ? parent.width - 20 : 900, 1450)
        height: Math.min(parent ? parent.height - 20 : 720, 950)
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 8

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

            Label {
                id: statusLabel
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Sélectionnez une couche.")
            }

            Label {
                id: diagnosticSummary
                Layout.fillWidth: true
                font.bold: true
                text: qsTr("En attente de la lecture...")
                wrapMode: Text.WordWrap
            }

            ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, plugin.sourceFeatures.length * Math.max(1, plugin.columnNames.length))
                value: plugin.receivedCells
                indeterminate: plugin.collectionActive && plugin.columnNames.length === 0
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.diagnosticMessage.length > 0
                text: qsTr("Erreur : %1").arg(plugin.diagnosticMessage)
                color: Theme.errorColor
                wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightGray }

            // Collecteur indépendant de la mise en page. Instantiator crée tous les
            // délégués, même s'ils ne sont pas visibles à l'écran.
            Instantiator {
                id: rowCollector
                model: plugin.sourceFeatures

                delegate: Item {
                    id: rowCollectorDelegate
                    required property var modelData
                    required property int index
                    property int rowIndex: index
                    property int generation: plugin.collectionGeneration
                    width: 0
                    height: 0

                    FeatureModel {
                        id: featureAttributeModel
                        currentLayer: plugin.selectedLayer
                        feature: rowCollectorDelegate.modelData
                    }

                    Instantiator {
                        model: featureAttributeModel
                        delegate: Item {
                            required property int index
                            width: 0
                            height: 0
                            Component.onCompleted: plugin.registerCell(
                                rowCollectorDelegate.generation,
                                rowCollectorDelegate.rowIndex,
                                index,
                                model.AttributeName !== undefined ? model.AttributeName : ("champ_" + index),
                                model.AttributeValue,
                                featureAttributeModel.count
                            )
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Aperçu aplati : identifiant + %1 premières colonnes")
                    .arg(Math.min(plugin.displayColumnLimit, plugin.columnNames.length))
                font.bold: true
            }

            Flickable {
                id: flatFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: flatTable.width
                contentHeight: flatTable.height
                flickableDirection: Flickable.HorizontalAndVerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOn }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: flatTable
                    width: 110 + Math.max(1, Math.min(plugin.displayColumnLimit, plugin.columnNames.length)) * 190

                    Row {
                        Rectangle {
                            width: 110
                            height: 54
                            border.color: Theme.lightGray
                            color: Theme.mainBackgroundColor
                            Label {
                                anchors.fill: parent
                                anchors.margins: 6
                                text: qsTr("Entité")
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Repeater {
                            model: plugin.columnNames.slice(0, plugin.displayColumnLimit)
                            delegate: Rectangle {
                                required property var modelData
                                width: 190
                                height: 54
                                border.color: Theme.lightGray
                                color: Theme.mainBackgroundColor
                                Label {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: String(modelData)
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    Repeater {
                        model: plugin.flatRows
                        delegate: Row {
                            id: flatRow
                            required property var modelData
                            required property int index

                            Rectangle {
                                width: 110
                                height: 38
                                border.color: Theme.lightGray
                                color: flatRow.index % 2 === 0 ? Theme.mainBackgroundColor : "#f4f4f4"
                                Label {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: modelData ? modelData.fid : ""
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Repeater {
                                model: modelData && modelData.values
                                    ? modelData.values.slice(0, plugin.displayColumnLimit)
                                    : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 190
                                    height: 38
                                    border.color: Theme.lightGray
                                    color: flatRow.index % 2 === 0 ? Theme.mainBackgroundColor : "#f4f4f4"
                                    Label {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: String(modelData)
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Version 0.4.0 : collecte avec Instantiator, puis affichage à partir d'un modèle JavaScript aplati.")
                opacity: 0.7
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
            }
        }
    }
}
