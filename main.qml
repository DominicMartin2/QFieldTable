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
    property int frozenColumnCount: 2
    property real horizontalOffset: 0
    property int sortColumn: -1
    property bool sortAscending: true
    property int filterColumn: -1
    property string filterMode: "contains"
    property string filterText: ""
    property string selectedCellAlias: ""
    property string selectedCellFieldName: ""
    property string selectedCellValue: ""
    property int selectedCellColumn: -1

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
        } catch (e1) { console.log("QField Table v0.5.4 mapLayers: " + e1) }

        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) for (var j = 0; j < canvasLayers.length; ++j) appendCandidate(canvasLayers[j], seen)
        } catch (e2) { console.log("QField Table v0.5.4 canvas layers: " + e2) }

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
        horizontalOffset = 0
        diagnosticMessage = ""
        sortColumn = -1
        sortAscending = true
        filterColumn = -1
        filterMode = "contains"
        filterText = ""
        selectedCellAlias = ""
        selectedCellFieldName = ""
        selectedCellValue = ""
        selectedCellColumn = -1
        if (searchField) searchField.text = ""
        if (columnFilterText) columnFilterText.text = ""
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
            console.log("QField Table v0.5.4 iterator: " + error)
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
            "sampleValue": formatValue(sampleValue),
            "width": 160
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

    function estimatedWidth(text) {
        var length = String(text === undefined || text === null ? "" : text).length
        return Math.max(110, Math.min(300, 34 + Math.min(length, 38) * 7.2))
    }

    function optimizeColumnWidths(rows) {
        var updated = []
        for (var c = 0; c < columns.length; ++c) {
            var col = columns[c]
            var width = estimatedWidth(col.alias || col.fieldName || qsTr("Champ"))
            for (var r = 0; r < rows.length; ++r)
                width = Math.max(width, estimatedWidth(rows[r].values[c]))
            updated.push({
                "alias": col.alias,
                "fieldName": col.fieldName,
                "fieldIndex": col.fieldIndex,
                "sampleValue": col.sampleValue,
                "width": width
            })
        }
        columns = updated
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
        optimizeColumnWidths(result)
        horizontalOffset = 0
        flatRows = result
        applyView()
    }

    function frozenWidth() {
        var total = 90
        var count = Math.min(frozenColumnCount, columns.length)
        for (var i = 0; i < count; ++i) total += columns[i].width
        return total
    }

    function scrollingWidth() {
        var total = 0
        for (var i = Math.min(frozenColumnCount, columns.length); i < columns.length; ++i)
            total += columns[i].width
        return total
    }

    function maxHorizontalOffset(viewportWidth) {
        return Math.max(0, scrollingWidth() - Math.max(0, viewportWidth))
    }

    function valueIsEmpty(value) {
        if (value === null || value === undefined) return true
        var text = String(value).trim()
        return text.length === 0 || text === '""' || text === "{}" || text.toLowerCase() === "null"
    }

    function rowMatchesColumnFilter(row) {
        if (filterColumn < 0 || filterColumn >= columns.length) return true
        var value = row.values[filterColumn]
        var text = String(value === undefined || value === null ? "" : value)
        var needle = String(filterText || "").toLowerCase().trim()

        if (filterMode === "empty") return valueIsEmpty(value)
        if (filterMode === "notempty") return !valueIsEmpty(value)
        if (filterMode === "equals") return text.toLowerCase() === needle
        if (needle.length === 0) return true
        return text.toLowerCase().indexOf(needle) >= 0
    }

    function compareValues(a, b) {
        var aText = String(a === undefined || a === null ? "" : a).trim()
        var bText = String(b === undefined || b === null ? "" : b).trim()
        var aNum = Number(aText.replace(',', '.'))
        var bNum = Number(bText.replace(',', '.'))
        if (aText.length > 0 && bText.length > 0 && !isNaN(aNum) && !isNaN(bNum))
            return aNum < bNum ? -1 : (aNum > bNum ? 1 : 0)
        return aText.localeCompare(bText, Qt.locale(), Locale.CompareCaseInsensitive)
    }

    function applyView() {
        var term = searchField ? String(searchField.text).toLowerCase().trim() : ""
        var result = []
        for (var r = 0; r < flatRows.length; ++r) {
            var row = flatRows[r]
            var globalMatch = term.length === 0 || String(row.featureId).toLowerCase().indexOf(term) >= 0
            if (!globalMatch) {
                for (var c = 0; c < row.values.length; ++c) {
                    if (String(row.values[c]).toLowerCase().indexOf(term) >= 0) {
                        globalMatch = true
                        break
                    }
                }
            }
            if (globalMatch && rowMatchesColumnFilter(row)) result.push(row)
        }

        if (sortColumn >= 0 && sortColumn < columns.length) {
            var col = sortColumn
            var asc = sortAscending
            result.sort(function(a, b) {
                var cmp = compareValues(a.values[col], b.values[col])
                if (cmp === 0) cmp = compareValues(a.featureId, b.featureId)
                return asc ? cmp : -cmp
            })
        }
        filteredRows = result
    }

    function toggleSort(columnIndex) {
        if (sortColumn === columnIndex) sortAscending = !sortAscending
        else {
            sortColumn = columnIndex
            sortAscending = true
        }
        applyView()
    }

    function selectCell(featureIdValue, columnIndex, value) {
        selectedFeatureId = String(featureIdValue)
        selectedCellColumn = columnIndex
        if (columnIndex >= 0 && columnIndex < columns.length) {
            selectedCellAlias = columns[columnIndex].alias || columns[columnIndex].fieldName || qsTr("Champ")
            selectedCellFieldName = columns[columnIndex].fieldName || ""
        } else {
            selectedCellAlias = qsTr("Identifiant de l’entité")
            selectedCellFieldName = "fid"
        }
        selectedCellValue = formatValue(value)
    }

    function copySelectedValue() {
        if (!selectedCellValue || selectedCellValue.length === 0) return
        try {
            if (Qt.application && Qt.application.clipboard) {
                if (typeof Qt.application.clipboard.setText === "function")
                    Qt.application.clipboard.setText(selectedCellValue)
                else
                    Qt.application.clipboard.text = selectedCellValue
                copyFeedback.text = qsTr("Valeur copiée")
                copyFeedbackTimer.restart()
                return
            }
        } catch (e1) { console.log("QField Table clipboard Qt: " + e1) }
        try {
            if (mainWindow && typeof mainWindow.copyToClipboard === "function") {
                mainWindow.copyToClipboard(selectedCellValue)
                copyFeedback.text = qsTr("Valeur copiée")
                copyFeedbackTimer.restart()
                return
            }
        } catch (e2) { console.log("QField Table clipboard mainWindow: " + e2) }
        copyFeedback.text = qsTr("Copie non disponible sur cette plateforme")
        copyFeedbackTimer.restart()
    }

    function clearColumnFilter() {
        filterColumn = -1
        filterMode = "contains"
        filterText = ""
        if (columnFilterText) columnFilterText.text = ""
        applyView()
    }

    function openBrowser() {
        refreshLayers()
        browserDialog.open()
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.5.4 chargé")
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
        id: copyFeedbackTimer
        interval: 1800
        repeat: false
        onTriggered: copyFeedback.text = ""
    }

    Timer {
        id: searchTimer
        interval: 250
        repeat: false
        onTriggered: plugin.applyView()
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
        title: qsTr("QField Table — v0.5.4")
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

            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("Filtre") ; font.bold: true }
                ComboBox {
                    id: filterColumnCombo
                    Layout.preferredWidth: 300
                    model: plugin.columns
                    textRole: "alias"
                    displayText: plugin.filterColumn >= 0 && plugin.filterColumn < plugin.columns.length
                                 ? (plugin.columns[plugin.filterColumn].alias || plugin.columns[plugin.filterColumn].fieldName)
                                 : qsTr("Choisir un champ…")
                    onActivated: {
                        plugin.filterColumn = currentIndex
                        plugin.applyView()
                    }
                }
                ComboBox {
                    id: filterModeCombo
                    Layout.preferredWidth: 150
                    model: [qsTr("Contient"), qsTr("Égale"), qsTr("Est vide"), qsTr("N'est pas vide")]
                    onActivated: {
                        plugin.filterMode = currentIndex === 1 ? "equals" : currentIndex === 2 ? "empty" : currentIndex === 3 ? "notempty" : "contains"
                        plugin.applyView()
                    }
                }
                TextField {
                    id: columnFilterText
                    Layout.fillWidth: true
                    enabled: plugin.filterMode === "contains" || plugin.filterMode === "equals"
                    placeholderText: qsTr("Valeur à rechercher…")
                    onTextChanged: {
                        plugin.filterText = text
                        searchTimer.restart()
                    }
                }
                Button { text: qsTr("Effacer"); onClicked: plugin.clearColumnFilter() }
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

            // En-tête fixe : il ne défile jamais verticalement.
            Item {
                id: fixedHeader
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                clip: true

                Rectangle { anchors.fill: parent; color: "#f8f8f8" }

                Row {
                    anchors.fill: parent

                    Row {
                        id: frozenHeaderRow
                        width: plugin.frozenWidth()
                        height: parent.height

                        Rectangle {
                            width: 90
                            height: parent.height
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
                            model: Math.min(plugin.frozenColumnCount, plugin.columns.length)
                            delegate: Rectangle {
                                required property int index
                                property var columnData: plugin.columns[index]
                                width: columnData ? columnData.width : 140
                                height: frozenHeaderRow.height
                                border.width: 1
                                border.color: Theme.lightGray
                                color: "#f8f8f8"
                                Label {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    text: columnData ? (columnData.alias || columnData.fieldName || qsTr("Champ"))
                                                       + (plugin.sortColumn === index ? (plugin.sortAscending ? " ▲" : " ▼") : "") : ""
                                }
                                ToolTip.visible: frozenHeaderMouse.containsMouse
                                ToolTip.text: columnData ? qsTr("%1 — cliquer pour trier").arg(columnData.fieldName) : ""
                                MouseArea {
                                    id: frozenHeaderMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: plugin.toggleSort(index)
                                }
                            }
                        }
                    }

                    Item {
                        id: scrollingHeaderViewport
                        width: Math.max(0, fixedHeader.width - frozenHeaderRow.width)
                        height: parent.height
                        clip: true

                        Row {
                            x: -plugin.horizontalOffset
                            height: parent.height
                            Repeater {
                                model: Math.max(0, plugin.columns.length - plugin.frozenColumnCount)
                                delegate: Rectangle {
                                    required property int index
                                    property int actualIndex: index + plugin.frozenColumnCount
                                    property var columnData: plugin.columns[actualIndex]
                                    width: columnData ? columnData.width : 140
                                    height: scrollingHeaderViewport.height
                                    border.width: 1
                                    border.color: Theme.lightGray
                                    color: "#f8f8f8"
                                    Label {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        text: columnData ? (columnData.alias || columnData.fieldName || qsTr("Champ"))
                                                           + (plugin.sortColumn === actualIndex ? (plugin.sortAscending ? " ▲" : " ▼") : "") : ""
                                    }
                                    ToolTip.visible: scrollingHeaderMouse.containsMouse
                                    ToolTip.text: columnData ? qsTr("%1 — cliquer pour trier").arg(columnData.fieldName) : ""
                                    MouseArea {
                                        id: scrollingHeaderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: plugin.toggleSort(actualIndex)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Le corps ne défile que verticalement. La partie droite est déplacée
            // horizontalement par le curseur commun à l'en-tête et aux lignes.
            Flickable {
                id: bodyFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: rowsColumn.height
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

                Column {
                    id: rowsColumn
                    width: bodyFlick.width

                    Repeater {
                        model: plugin.filteredRows
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: rowsColumn.width
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

                                Row {
                                    id: frozenCellsRow
                                    width: plugin.frozenWidth()
                                    height: parent.height

                                    Rectangle {
                                        width: 90
                                        height: parent.height
                                        border.width: 1
                                        border.color: Theme.lightGray
                                        color: plugin.selectedFeatureId === String(modelData.featureId) && plugin.selectedCellColumn === -1
                                               ? "#dff2c7" : "transparent"
                                        Label {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            text: modelData.featureId
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                        ToolTip.visible: entityCellMouse.containsMouse
                                        ToolTip.text: String(modelData.featureId)
                                        MouseArea {
                                            id: entityCellMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            pressAndHoldInterval: 500
                                            onClicked: plugin.selectCell(modelData.featureId, -1, modelData.featureId)
                                            onPressAndHold: plugin.selectCell(modelData.featureId, -1, modelData.featureId)
                                        }
                                    }

                                    Repeater {
                                        model: Math.min(plugin.frozenColumnCount, plugin.columns.length)
                                        delegate: Rectangle {
                                            required property int index
                                            property var columnData: plugin.columns[index]
                                            property string cellValue: modelData.values[index] !== undefined ? String(modelData.values[index]) : ""
                                            width: columnData ? columnData.width : 140
                                            height: frozenCellsRow.height
                                            border.width: 1
                                            border.color: Theme.lightGray
                                            color: plugin.selectedFeatureId === String(modelData.featureId) && plugin.selectedCellColumn === index
                                                   ? "#dff2c7" : "transparent"
                                            Label {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                                text: cellValue
                                            }
                                            ToolTip.visible: frozenCellMouse.containsMouse
                                            ToolTip.text: cellValue
                                            MouseArea {
                                                id: frozenCellMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                pressAndHoldInterval: 500
                                                onClicked: plugin.selectCell(modelData.featureId, index, cellValue)
                                                onPressAndHold: plugin.selectCell(modelData.featureId, index, cellValue)
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: scrollingCellsViewport
                                    width: Math.max(0, rowsColumn.width - frozenCellsRow.width)
                                    height: parent.height
                                    clip: true

                                    Row {
                                        x: -plugin.horizontalOffset
                                        height: parent.height
                                        Repeater {
                                            model: Math.max(0, plugin.columns.length - plugin.frozenColumnCount)
                                            delegate: Rectangle {
                                                required property int index
                                                property int actualIndex: index + plugin.frozenColumnCount
                                                property var columnData: plugin.columns[actualIndex]
                                                property string cellValue: modelData.values[actualIndex] !== undefined ? String(modelData.values[actualIndex]) : ""
                                                width: columnData ? columnData.width : 140
                                                height: scrollingCellsViewport.height
                                                border.width: 1
                                                border.color: Theme.lightGray
                                                color: plugin.selectedFeatureId === String(modelData.featureId) && plugin.selectedCellColumn === actualIndex
                                                       ? "#dff2c7" : "transparent"
                                                Label {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: cellValue
                                                }
                                                ToolTip.visible: scrollingCellMouse.containsMouse
                                                ToolTip.text: cellValue
                                                MouseArea {
                                                    id: scrollingCellMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    pressAndHoldInterval: 500
                                                    onClicked: plugin.selectCell(modelData.featureId, actualIndex, cellValue)
                                                    onPressAndHold: plugin.selectCell(modelData.featureId, actualIndex, cellValue)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: plugin.columns.length > plugin.frozenColumnCount

                Label { text: qsTr("Colonnes") }
                Slider {
                    id: horizontalSlider
                    Layout.fillWidth: true
                    from: 0
                    to: plugin.maxHorizontalOffset(scrollingHeaderViewport.width)
                    value: Math.min(plugin.horizontalOffset, to)
                    enabled: to > 0
                    onMoved: plugin.horizontalOffset = value
                    onToChanged: {
                        if (plugin.horizontalOffset > to) plugin.horizontalOffset = to
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: plugin.selectedFeatureId.length > 0 ? 190 : 44
                color: "#fafafa"
                border.width: 1
                border.color: Theme.lightGray
                radius: 3

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            font.bold: true
                            text: plugin.selectedFeatureId.length > 0
                                  ? qsTr("Entité %1 — %2").arg(plugin.selectedFeatureId).arg(plugin.selectedCellAlias)
                                  : qsTr("Cliquez sur une cellule pour afficher sa valeur complète.")
                            elide: Text.ElideRight
                        }
                        Label {
                            visible: plugin.selectedCellFieldName.length > 0
                            text: plugin.selectedCellFieldName
                            opacity: 0.65
                        }
                        Button {
                            visible: plugin.selectedFeatureId.length > 0
                            text: qsTr("Copier")
                            enabled: plugin.selectedCellValue.length > 0
                            onClicked: plugin.copySelectedValue()
                        }
                    }

                    ScrollView {
                        id: fullValueScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: plugin.selectedFeatureId.length > 0
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        TextArea {
                            id: fullValueArea
                            width: fullValueScroll.availableWidth
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            text: plugin.selectedCellValue
                            placeholderText: qsTr("Valeur vide")
                            padding: 10
                            topPadding: 10
                            bottomPadding: 10
                            leftPadding: 10
                            rightPadding: 10
                            background: Rectangle {
                                color: "white"
                                border.width: 1
                                border.color: Theme.lightGray
                                radius: 2
                            }
                        }
                    }

                    Label {
                        id: copyFeedback
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        color: Theme.mainColor
                        text: ""
                    }
                }
            }
        }
    }
}
