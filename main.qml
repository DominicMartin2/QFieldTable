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

    // [{ alias, fieldName, fieldIndex, sampleValue }]
    property var columns: []
    // [{ featureId, values: [] }]
    property var flatRows: []
    property string diagnosticMessage: ""
    property int expectedColumnCount: 0
    property int displayedColumnLimit: 12

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
        } catch (e1) { console.log("QField Table v0.4.3 mapLayers: " + e1) }

        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) for (var j = 0; j < canvasLayers.length; ++j) appendCandidate(canvasLayers[j], seen)
        } catch (e2) { console.log("QField Table v0.4.3 canvas layers: " + e2) }

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
        expectedColumnCount = 0
        diagnosticMessage = ""
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
            console.log("QField Table v0.4.3 iterator: " + error)
        }

        statusLabel.text = qsTr("Couche : %1 — %2 enregistrement(s); test sur les %3 premières entités")
                .arg(layerName(selectedLayer)).arg(totalFeatureCount).arg(previewFeatures.length)
        schemaBuildTimer.restart()
    }

    function featureId(feature) {
        if (!feature) return "?"
        try { return String(typeof feature.id === "function" ? feature.id() : feature.id) }
        catch (e) { return "?" }
    }

    function formatValue(value) {
        if (value === null || value === undefined) return "∅"
        var text = String(value)
        return text.length === 0 ? "\"\"" : text
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

        // Évite les doublons lorsque le Repeater est reconstruit.
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
        if (!feature || !column) return "∅"
        var value

        // Test principal demandé : QgsFeature.attribute(nom technique).
        if (column.fieldName && column.fieldName.length > 0) {
            try {
                value = feature.attribute(column.fieldName)
                if (value !== undefined) return formatValue(value)
            } catch (e1) {}
        }

        // Diagnostic de secours : surcharge par index, si elle est exposée dans cette version.
        if (column.fieldIndex >= 0) {
            try {
                value = feature.attribute(column.fieldIndex)
                if (value !== undefined) return formatValue(value)
            } catch (e2) {}
        }

        return "⚠ indisponible"
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
    }

    function openBrowser() {
        refreshLayers()
        browserDialog.open()
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.4.3 chargé")
    }

    Connections {
        target: iface
        function onLoadProjectEnded() { if (browserDialog.visible) refreshLayers() }
    }

    Timer {
        id: schemaBuildTimer
        interval: 120
        repeat: false
        onTriggered: {
            // resetData() a déjà vidé les anciennes données avant l'affectation
            // de l'entité de référence. Il ne faut surtout pas effacer ici les
            // colonnes que les délégués visibles viennent d'enregistrer.
            schemaPollTimer.restart()
        }
    }

    Timer {
        id: schemaPollTimer
        interval: 250
        repeat: true
        running: false
        property int attempts: 0
        onTriggered: {
            attempts++
            // Les délégués du Repeater enregistrent les colonnes dès que le
            // modèle devient disponible. On attend seulement leur création.
            if (plugin.columns.length > 0) {
                stop()
                attempts = 0
                rowBuildTimer.restart()
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
        interval: 180
        repeat: false
        onTriggered: plugin.buildRows()
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
        title: qsTr("QField Table — diagnostic v0.4.3")
        standardButtons: Dialog.Close
        width: Math.min(parent ? parent.width - 24 : 900, 1450)
        height: Math.min(parent ? parent.height - 24 : 750, 950)
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

            Label { id: statusLabel; Layout.fillWidth: true; wrapMode: Text.WordWrap }

            Label {
                Layout.fillWidth: true
                font.bold: true
                wrapMode: Text.WordWrap
                text: qsTr("FeatureModel de référence : %1 attribut(s) — Colonnes enregistrées : %2 — Lignes construites : %3")
                        .arg(referenceFeatureModel.count).arg(plugin.columns.length).arg(plugin.flatRows.length)
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.diagnosticMessage.length > 0
                text: qsTr("Erreur : %1").arg(plugin.diagnosticMessage)
                color: Theme.errorColor
                wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightGray }

            // Même mécanisme que la v0.2 : FeatureModel directement attaché à la
            // première entité, avec un Repeater réellement visible.
            Frame {
                id: referenceFrame
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                visible: plugin.previewFeatures.length > 0

                property var referenceFeature: plugin.previewFeatures.length > 0 ? plugin.previewFeatures[0] : null

                FeatureModel {
                    id: referenceFeatureModel
                    currentLayer: plugin.selectedLayer
                    feature: referenceFrame.referenceFeature
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 6

                    Label {
                        Layout.preferredWidth: 180
                        font.bold: true
                        text: qsTr("Entité de référence : %1").arg(plugin.featureId(referenceFrame.referenceFeature))
                    }

                    ListView {
                        id: visibleSchemaList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        clip: true
                        spacing: 4
                        model: referenceFeatureModel

                        delegate: Rectangle {
                            width: 210
                            height: visibleSchemaList.height
                            border.width: 1
                            border.color: Theme.lightGray
                            color: "transparent"

                            // Les rôles supplémentaires sont testés ici.
                            property var roleField: model.Field !== undefined ? model.Field : null
                            property var roleIndex: model.FieldIndex !== undefined ? model.FieldIndex : index

                            Component.onCompleted: plugin.registerColumn(
                                                       model.AttributeName,
                                                       roleField,
                                                       roleIndex,
                                                       model.AttributeValue)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 1
                                Label {
                                    width: parent.width
                                    font.bold: true
                                    elide: Text.ElideRight
                                    text: model.AttributeName !== undefined ? String(model.AttributeName) : qsTr("Champ")
                                }
                                Label {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: {
                                        var n = plugin.fieldObjectName(parent.parent.roleField)
                                        return n.length > 0 ? qsTr("nom: %1").arg(n) : qsTr("nom technique non exposé")
                                    }
                                }
                                Label {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: qsTr("valeur: %1").arg(plugin.formatValue(model.AttributeValue))
                                }
                            }
                        }

                        ScrollBar.horizontal: ScrollBar { }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                font.bold: true
                text: qsTr("Aperçu : identifiant + %1 premières colonnes").arg(Math.min(plugin.displayedColumnLimit, plugin.columns.length))
            }

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
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: tableContent
                    property int shownColumns: Math.min(plugin.displayedColumnLimit, plugin.columns.length)
                    property int idWidth: 100
                    property int cellWidth: 190
                    width: idWidth + shownColumns * cellWidth
                    spacing: 0

                    Row {
                        Rectangle {
                            width: tableContent.idWidth; height: 54
                            border.width: 1; border.color: Theme.lightGray
                            Label { anchors.fill: parent; anchors.margins: 6; font.bold: true; text: qsTr("Entité"); verticalAlignment: Text.AlignVCenter }
                        }
                        Repeater {
                            model: tableContent.shownColumns
                            delegate: Rectangle {
                                required property int index
                                width: tableContent.cellWidth; height: 54
                                border.width: 1; border.color: Theme.lightGray
                                Label {
                                    anchors.fill: parent; anchors.margins: 6
                                    font.bold: true; wrapMode: Text.WordWrap
                                    text: plugin.columns[index] ?
                                              ((plugin.columns[index].alias || qsTr("Champ")) +
                                               (plugin.columns[index].fieldName ? "\n[" + plugin.columns[index].fieldName + "]" : "")) : ""
                                }
                            }
                        }
                    }

                    Repeater {
                        model: plugin.flatRows
                        delegate: Row {
                            required property var modelData
                            required property int index
                            Rectangle {
                                width: tableContent.idWidth; height: 40
                                border.width: 1; border.color: Theme.lightGray
                                color: index % 2 ? "#f4f4f4" : "transparent"
                                Label { anchors.fill: parent; anchors.margins: 6; text: modelData.featureId; verticalAlignment: Text.AlignVCenter }
                            }
                            Repeater {
                                model: tableContent.shownColumns
                                delegate: Rectangle {
                                    required property int index
                                    width: tableContent.cellWidth; height: 40
                                    border.width: 1; border.color: Theme.lightGray
                                    color: parent.parent.index % 2 ? "#f4f4f4" : "transparent"
                                    Label {
                                        anchors.fill: parent; anchors.margins: 6
                                        elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        text: modelData.values[index] !== undefined ? modelData.values[index] : "∅"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                opacity: 0.75
                text: qsTr("Version 0.4.3 : conservation des colonnes enregistrées avant la minuterie de validation.")
            }
        }
    }
}
