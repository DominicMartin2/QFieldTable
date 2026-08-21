import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import org.qgis
import Theme
import "qgzreader.js" as QgzReader

Item {
    id: plugin
    objectName: "qfieldTablePlugin"

    property var mainWindow: iface.mainWindow()
    property var mapCanvas: iface.mapCanvas()
    property var dashBoard: iface.findItemByObjectName("dashBoard")
    // Conteneur natif complet du formulaire QField. Il fournit le formulaire
    // et sa barre d'outils Enregistrer/Annuler.
    property var overlayFeatureFormDrawer:
        iface.findItemByObjectName("overlayFeatureFormDrawer")
    property string nativeEditDiagnostic: ""
    property bool nativeDiagnosticVisible: false

    property var vectorLayers: []
    property var selectedLayer: null
    property var previewFeatures: []
    property int previewLimit: 100
    property int totalFeatureCount: 0
    property int matchedFeatureCount: 0
    property bool loadAllRecords: false
    property string activePreFilterExpression: ""
    property int preFilterColumn: -1
    property string preFilterMode: "contains"
    property string preFilterText: ""
    property bool refreshAfterNativeEdit: false
    property string pendingZoomFeatureId: ""
    property var pendingNativeEditFeature: null
    property bool nativePreviousMapInteractive: true
    // v0.12.10 — Autosauvegarde du formulaire ouvert par QField Table.
    property bool nativeEditSessionActive: false
    property bool returnToTableAfterNativeClose: false
    property real nativeWheelOldScale: 0
    property var nativeWheelOldExtent: null
    property var nativeLockedMapExtent: null
    property bool nativeMapFrozenByPlugin: false
    property bool nativeAutosaveEnabled: true
    property int nativeAutosaveDelay: 2000
    property string nativeAutosaveSettingsPath: ""
    // v0.12.10 — sélection et modification en lot.
    property var batchSelectedIds: ({})
    property var batchFieldItems: []
    property var batchRelationItems: []
    property int batchFieldColumn: -1
    property string batchOperation: "replace"
    property string batchValueText: ""
    property var batchValueMapItems: []
    property bool batchIsValueMap: false
    property bool batchIsValueRelation: false
    property bool batchIsMultiValueRelation: false
    property string batchRelationRawValue: ""
    property int batchSuccessCount: 0
    property var batchFailedIds: []
    property bool batchInProgress: false
    // v0.12.10 — source ValueRelation complète.
    property var batchRelationLayer: null
    property string batchRelationLayerId: ""
    property string batchRelationKeyField: ""
    property string batchRelationValueField: ""
    property string batchRelationFilterExpression: ""
    property string batchNewRelationKey: ""
    property string batchNewRelationLabel: ""
    // Journal de sécurité de la session. Une entrée par entité réellement traitée.
    property var batchJournal: []
    property string batchJournalFilePath: ""
    property string batchJournalPersistenceError: ""
    property var batchJournalLayer: null
    property string batchJournalBackend: "json"
    property string batchJournalLayerName: "qfield_table_journal"
    // Clé métier préférée pour identifier les objets dans le journal.
    // Si ce champ n'existe pas dans la couche, le plugin utilise featureId.
    property string batchJournalEntityIdField: "id_unique_inv"

    // v0.12.10 — le FeatureModel de schéma est détaché/rattaché
    // explicitement lors d'un changement de couche.
    property var schemaLayer: null
    property var schemaFeature: null
    property bool schemaCollectorEnabled: false
    property int schemaGeneration: 0
    // Configuration de formulaire réellement utilisée par QField.
    property var projectWidgetConfigs: ({})
    property string batchRelationDiagnostic: ""
    property string batchRelationLayerSource: ""
    property string batchRelationLayerName: ""
    property string batchRelationResolutionMethod: ""
    property int batchRelationModelCount: 0
    property string batchRelationLoadingMethod: ""
    property string batchRelationIteratorError: ""
    property string projectConfigDiagnostic: ""
    property bool projectConfigReadAttempted: false
    property string projectXmlDiagnosticText: ""
    property string projectXmlSourceName: ""

    // [{ alias, fieldName, fieldIndex, sampleValue }]
    property var columns: []
    // v0.12.10 : cache des libellés ValueRelation / ValueMap.
    property var relationDisplayCaches: ({})
    // [{ featureId, feature, values: [] }] — valeurs lues à la demande pour accélérer le chargement
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
    property var distinctValues: []
    property var visibleDistinctValues: []
    property var selectedDistinctKeys: ({})
    property var activeColumnFilters: ({})
    // Redimensionnement différé : on évite de reconstruire le modèle
    // à chaque pixel pendant le glissement.
    property int resizingColumnIndex: -1
    property real resizingColumnWidth: -1
    property string sharedViewCode: ""
    // v0.12.10 — vues partagées synchronisées via une table du GeoPackage.
    property string sharedViewsLayerName: "qfield_table_vues"
    property var sharedViewsLayer: null
    property string sharedViewsError: ""
    property string pendingSharedViewJson: ""
    property string pendingSharedViewTitle: ""
    property string pendingSharedViewLayerName: ""
    property int pendingSharedViewAttempts: 0
    property string distinctSearchText: ""
    property string selectedCellAlias: ""
    property string selectedCellFieldName: ""
    property string selectedCellValue: ""
    property int selectedCellColumn: -1
    property real inspectorHeight: 190
    property real inspectorMinHeight: 105
    property bool inspectorCollapsed: false
    property var pendingDistinctKeys: ({})
    // Gestion des colonnes affichées. Les indices font référence à columns/row.values.
    property var displayedColumns: []
    property var columnOrder: []
    property var columnVisibility: ({})
    property var pendingColumnOrder: []
    property var pendingColumnVisibility: ({})
    property string columnSearchText: ""
    property var visibleColumnManagerItems: []
    property var selectedColumnManagerItems: []
    property int selectedDragOriginalIndex: -1
    property int selectedDragTargetPosition: -1
    property real selectedDragIndicatorY: -1
    property string restoredConfigurationKey: ""
    // Correctif 0.5.9.1 : conservation en mémoire pendant la session.
    // La persistance disque sera réintroduite via une API QField officiellement exposée.
    property string sessionProjectConfigurations: "{}"
    property int draggedColumnOriginalIndex: -1
    property int draggedTargetInsertPosition: -1
    property real columnDragIndicatorY: -1
    // Indique qu’un nouveau projet a été chargé pendant que la fenêtre était fermée.
    property bool needsProjectRefresh: true

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

        // Table technique interne du plugin : ne pas la proposer comme
        // couche de travail dans QField Table.
        if (name === batchJournalLayerName || name === sharedViewsLayerName)
            return
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
        } catch (e1) { console.log("QField Table v0.12.10 mapLayers: " + e1) }

        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) for (var j = 0; j < canvasLayers.length; ++j) appendCandidate(canvasLayers[j], seen)
        } catch (e2) { console.log("QField Table v0.12.10 canvas layers: " + e2) }

        try { appendCandidate(dashBoard.activeLayer, seen) } catch (e3) {}

        if (vectorLayers.length > 0) {
            layerCombo.currentIndex = 0
            selectLayer(0)
        } else {
            selectedLayer = null
            statusLabel.text = qsTr("Aucune couche vectorielle trouvée.")
        }
    }

    function detachSchemaCollector() {
        schemaCollectorEnabled = false
        schemaFeature = null
        schemaLayer = null
        schemaGeneration++
        schemaPollTimer.stop()
    }

    function attachSchemaCollector() {
        if (!selectedLayer || previewFeatures.length === 0) {
            schemaCollectorEnabled = false
            return
        }

        // Two-step attachment is intentional: it guarantees that the
        // FeatureModel sees a null layer/feature state before the new layer.
        var generation = schemaGeneration

        Qt.callLater(function() {
            if (generation !== plugin.schemaGeneration)
                return

            plugin.schemaLayer = plugin.selectedLayer
            plugin.schemaFeature = plugin.previewFeatures[0]

            Qt.callLater(function() {
                if (generation !== plugin.schemaGeneration)
                    return

                plugin.schemaCollectorEnabled = true
                schemaPollTimer.restart()
            })
        })
    }

    function selectLayer(index) {
        if (index < 0 || index >= vectorLayers.length) return

        detachSchemaCollector()
        selectedLayer = vectorLayers[index]
        inspectSelectedLayer()
    }

    function resetData() {
        schemaCollectorEnabled = false
        schemaFeature = null
        schemaLayer = null
        clearProjectWidgetConfigs()
        projectConfigReadAttempted = false
        projectConfigDiagnostic = ""
        projectXmlDiagnosticText = ""
        projectXmlSourceName = ""
        previewFeatures = []
        totalFeatureCount = 0
        matchedFeatureCount = 0
        loadAllRecords = false
        activePreFilterExpression = ""
        preFilterColumn = -1
        preFilterMode = "contains"
        preFilterText = ""
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
        distinctValues = []
        visibleDistinctValues = []
        selectedDistinctKeys = ({})
        activeColumnFilters = ({})
        distinctSearchText = ""
        selectedCellAlias = ""
        selectedCellFieldName = ""
        selectedCellValue = ""
        selectedCellColumn = -1
        inspectorCollapsed = false
        pendingDistinctKeys = ({})
        displayedColumns = []
        columnOrder = []
        columnVisibility = ({})
        pendingColumnOrder = []
        pendingColumnVisibility = ({})
        columnSearchText = ""
        visibleColumnManagerItems = []
        restoredConfigurationKey = ""
        draggedColumnOriginalIndex = -1
        draggedTargetInsertPosition = -1
        columnDragIndicatorY = -1
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
            matchedFeatureCount = totalFeatureCount
            previewFeatures = found
        } catch (error) {
            diagnosticMessage = String(error)
            console.log("QField Table v0.12.10 iterator: " + error)
        }

        updateLoadStatus()
        attachSchemaCollector()
    }

    function updateLoadStatus() {
        if (!selectedLayer) return
        var modeText = activePreFilterExpression.length > 0
                ? qsTr("préfiltre : %1 correspondance(s)").arg(matchedFeatureCount)
                : (loadAllRecords ? qsTr("tous les enregistrements") : qsTr("aperçu"))
        statusLabel.text = qsTr("Couche : %1 — %2 enregistrement(s); %3 chargé(s) — %4")
                .arg(layerName(selectedLayer)).arg(totalFeatureCount).arg(previewFeatures.length).arg(modeText)
    }

    function reloadFeaturesOnly() {
        if (!selectedLayer) return
        previewFeatures = []
        flatRows = []
        filteredRows = []
        selectedFeatureId = ""
        selectedCellColumn = -1
        selectedCellAlias = ""
        selectedCellFieldName = ""
        selectedCellValue = ""
        diagnosticMessage = ""

        var found = []
        var count = 0
        try {
            var iterator = activePreFilterExpression.length > 0
                    ? LayerUtils.createFeatureIteratorFromExpression(selectedLayer, activePreFilterExpression)
                    : LayerUtils.createFeatureIterator(selectedLayer)
            while (iterator.hasNext()) {
                var feature = iterator.next()
                count++
                if (loadAllRecords || found.length < previewLimit) found.push(feature)
            }
            matchedFeatureCount = count
            previewFeatures = found
        } catch (error) {
            diagnosticMessage = qsTr("Erreur de chargement : %1").arg(String(error))
            console.log("QField Table v0.12.10 filtered iterator: " + error)
        }
        updateLoadStatus()

        if (columns.length > 0) {
            rowBuildTimer.restart()
        } else {
            detachSchemaCollector()
            attachSchemaCollector()
        }
    }

    function expressionFieldName(name) {
        return '"' + String(name).replace(/"/g, '""') + '"'
    }

    function expressionString(value) {
        return "'" + String(value).replace(/'/g, "''") + "'"
    }

    function buildPreFilterExpression() {
        if (preFilterColumn < 0 || preFilterColumn >= columns.length) return ""
        var fieldName = columns[preFilterColumn].fieldName
        if (!fieldName || fieldName.length === 0) return ""
        var field = expressionFieldName(fieldName)
        var text = String(preFilterText || "").trim()
        if (preFilterMode === "empty")
            return "(" + field + " IS NULL OR trim(to_string(" + field + ")) = '')"
        if (preFilterMode === "notempty")
            return "(" + field + " IS NOT NULL AND trim(to_string(" + field + ")) <> '')"
        if (text.length === 0) return ""
        if (preFilterMode === "equals")
            return "to_string(" + field + ") = " + expressionString(text)
        return "to_string(" + field + ") ILIKE " + expressionString("%" + text + "%")
    }

    function loadFirstHundred() {
        loadAllRecords = false
        activePreFilterExpression = ""
        reloadFeaturesOnly()
        loadDialog.close()
    }

    function loadAllFeatures() {
        loadAllRecords = true
        activePreFilterExpression = ""
        reloadFeaturesOnly()
        loadDialog.close()
    }

    function loadWithPreFilter() {
        var expression = buildPreFilterExpression()
        if (expression.length === 0) {
            diagnosticMessage = qsTr("Choisissez un champ et une valeur de préfiltre.")
            return
        }
        loadAllRecords = true
        activePreFilterExpression = expression
        reloadFeaturesOnly()
        loadDialog.close()
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

    function isTechnicalIdentifierName(name) {
        var n = String(name || "").toLowerCase()
        return n === "fid" || n === "fid_1"
    }

    function expressionQuotedFieldName(name) {
        return '"' + String(name || "").replace(/"/g, '""') + '"'
    }

    function cleanDisplayedCollectionValue(value) {
        var text = formatValue(value).trim()

        // Nettoyage d'affichage seulement : la donnée source n'est pas modifiée.
        if (text === "{}")
            return ""

        if (text.length >= 2 &&
                text.charAt(0) === "{" &&
                text.charAt(text.length - 1) === "}") {
            text = text.substring(1, text.length - 1).trim()
        }

        return text
    }

    function representedValue(feature, fieldName, rawValue) {
        var rawText = formatValue(rawValue)
        if (!feature || !fieldName || String(fieldName).length === 0)
            return rawText

        try {
            displayExpressionEvaluator.layer = selectedLayer
            displayExpressionEvaluator.project = qgisProject
            displayExpressionEvaluator.feature = feature
            displayExpressionEvaluator.expressionText =
                    "represent_value(" + expressionQuotedFieldName(fieldName) + ")"

            var represented = displayExpressionEvaluator.evaluate()
            var text = formatValue(represented)

            // represent_value() peut retourner la valeur brute si aucun
            // formateur n'est configuré. On la conserve alors telle quelle.
            return cleanDisplayedCollectionValue(text.length > 0 ? text : rawText)
        } catch (e) {
            console.log("QField Table v0.12.10 represent_value(" + fieldName + "): " + e)
            return cleanDisplayedCollectionValue(rawText)
        }
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
            "fieldObject": fieldObject,
            "sampleValue": formatValue(sampleValue),
            "width": 160,
            "technicalHidden": isTechnicalIdentifierName(technicalName)
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
        // v0.12.10 : ne parcourt plus toutes les cellules au chargement.
        // La largeur initiale est estimée à partir de l’alias et de la valeur
        // de référence déjà fournie par le FeatureModel. Les autres valeurs
        // seront lues seulement lorsqu’une cellule devient visible.
        var updated = []
        for (var c = 0; c < columns.length; ++c) {
            var col = columns[c]
            var width = estimatedWidth(col.alias || col.fieldName || qsTr("Champ"))
            width = Math.max(width, estimatedWidth(col.sampleValue || ""))
            updated.push({
                "alias": col.alias,
                "fieldName": col.fieldName,
                "fieldIndex": col.fieldIndex,
                "fieldObject": col.fieldObject,
                "sampleValue": col.sampleValue,
                "width": width,
                "technicalHidden": col.technicalHidden === true
            })
        }
        columns = updated
        restoreColumnConfiguration()
        refreshDisplayedColumns()
    }

    function rowValue(row, columnIndex) {
        if (!row || columnIndex < 0 || columnIndex >= columns.length) return ""
        if (!row.values) row.values = []
        if (row.values[columnIndex] !== undefined) return row.values[columnIndex]
        var value = readAttribute(row.feature, columns[columnIndex])
        value = representedValue(row.feature, columns[columnIndex].fieldName, value)
        row.values[columnIndex] = value
        return value
    }

    function projectIdentifier() {
        try {
            var fileName = typeof qgisProject.fileName === "function" ? qgisProject.fileName() : qgisProject.fileName
            if (fileName !== undefined && fileName !== null && String(fileName).length > 0)
                return String(fileName)
        } catch (e1) {}
        try {
            var title = typeof qgisProject.title === "function" ? qgisProject.title() : qgisProject.title
            if (title !== undefined && title !== null && String(title).length > 0)
                return String(title)
        } catch (e2) {}
        return "projet_sans_identifiant"
    }

    function configurationKey() {
        return projectIdentifier() + "|" + layerId(selectedLayer)
    }

    function parseStoredConfigurations() {
        try {
            var parsed = JSON.parse(sessionProjectConfigurations || "{}")
            return parsed && typeof parsed === "object" ? parsed : ({})
        } catch (e) {
            console.log("QField Table v0.12.10 configuration invalide: " + e)
            return ({})
        }
    }

    function columnPersistentName(index) {
        if (index < 0 || index >= columns.length) return ""
        var fieldName = String(columns[index].fieldName || "")
        return fieldName.length > 0 ? fieldName : "__index__" + String(index)
    }

    function layerConfigurationPropertyKey() {
        return "qfield_table/view_config_v1"
    }

    function readLayerConfiguration() {
        if (!selectedLayer) return null
        try {
            var raw = selectedLayer.customProperty(layerConfigurationPropertyKey(), "")
            if (raw !== undefined && raw !== null && String(raw).length > 0) {
                var parsed = JSON.parse(String(raw))
                if (parsed && typeof parsed === "object") return parsed
            }
        } catch (e) {
            console.log("QField Table v0.12.10 lecture propriété couche: " + e)
        }
        return null
    }

    function saveColumnConfiguration() {
        if (!selectedLayer || columns.length === 0) return
        var all = parseStoredConfigurations()
        var orderNames = []
        var hiddenNames = []
        for (var i = 0; i < columnOrder.length; ++i) {
            var idx = Number(columnOrder[i])
            var name = columnPersistentName(idx)
            if (name.length > 0) orderNames.push(name)
            if (columnVisibility[String(idx)] === false && name.length > 0) hiddenNames.push(name)
        }
        var config = {
            "order": orderNames,
            "hidden": hiddenNames,
            "frozenColumnCount": frozenColumnCount,
            "inspectorHeight": inspectorHeight,
            "inspectorCollapsed": inspectorCollapsed
        }
        all[configurationKey()] = config
        sessionProjectConfigurations = JSON.stringify(all)

        // Stockage sur la couche: QgsMapLayer.customProperty/setCustomProperty sont
        // exposés à QML et les propriétés sont enregistrées avec le projet QGIS.
        try {
            selectedLayer.setCustomProperty(layerConfigurationPropertyKey(), JSON.stringify(config))
            try { qgisProject.setDirty(true) } catch (dirtyError) {}
        } catch (e) {
            console.log("QField Table v0.12.10 sauvegarde propriété couche: " + e)
        }
    }

    function restoreColumnConfiguration() {
        if (!selectedLayer || columns.length === 0) {
            ensureColumnConfiguration()
            return
        }
        var key = configurationKey()
        if (restoredConfigurationKey === key && columnOrder.length === columns.length) {
            ensureColumnConfiguration()
            return
        }

        var all = parseStoredConfigurations()
        var saved = readLayerConfiguration()
        if (!saved) saved = all[key]
        if (!saved || !saved.order || !Array.isArray(saved.order)) {
            columnOrder = []
            columnVisibility = ({})
            ensureColumnConfiguration()
            restoredConfigurationKey = key
            return
        }

        var indexByName = ({})
        for (var c = 0; c < columns.length; ++c)
            indexByName[columnPersistentName(c)] = c

        var order = []
        var used = ({})
        for (var i = 0; i < saved.order.length; ++i) {
            var savedName = String(saved.order[i])
            if (indexByName[savedName] === undefined) continue
            var idx = Number(indexByName[savedName])
            if (used[String(idx)]) continue
            used[String(idx)] = true
            order.push(idx)
        }
        for (var j = 0; j < columns.length; ++j) {
            if (!used[String(j)]) order.push(j)
        }

        var hidden = ({})
        if (saved.hidden && Array.isArray(saved.hidden))
            for (var h = 0; h < saved.hidden.length; ++h) hidden[String(saved.hidden[h])] = true

        var visibility = ({})
        for (var k = 0; k < columns.length; ++k)
            visibility[String(k)] = columns[k].technicalHidden === true ? false : (hidden[columnPersistentName(k)] !== true)

        columnOrder = order
        columnVisibility = visibility
        if (saved.frozenColumnCount !== undefined)
            frozenColumnCount = Math.max(0, Math.min(Number(saved.frozenColumnCount), columns.length))
        if (saved.inspectorHeight !== undefined)
            inspectorHeight = Math.max(inspectorMinHeight, Number(saved.inspectorHeight))
        if (saved.inspectorCollapsed !== undefined)
            inspectorCollapsed = saved.inspectorCollapsed === true
        restoredConfigurationKey = key
    }

    function movePendingColumnToInsertPosition(originalIndex, insertPosition) {
        var order = cloneArray(pendingColumnOrder)
        var from = order.indexOf(originalIndex)
        if (from < 0) from = order.indexOf(String(originalIndex))
        if (from < 0) return
        var item = order.splice(from, 1)[0]
        var target = Math.max(0, Math.min(Number(insertPosition), order.length + 1))
        if (target > from) target--
        target = Math.max(0, Math.min(target, order.length))
        order.splice(target, 0, item)
        pendingColumnOrder = order
        filterColumnManagerItems()
        refreshSelectedColumnManagerItems()
    }

    function beginColumnDrag(originalIndex) {
        if (String(columnSearchText || "").trim().length > 0) return
        draggedColumnOriginalIndex = Number(originalIndex)
        draggedTargetInsertPosition = -1
        columnDragIndicatorY = -1
    }

    function updateColumnDrag(contentY) {
        if (draggedColumnOriginalIndex < 0 || String(columnSearchText || "").trim().length > 0) return
        var visibleIndex = columnManagerList.indexAt(10, contentY)
        if (visibleIndex < 0) {
            if (contentY <= 0) {
                draggedTargetInsertPosition = 0
                columnDragIndicatorY = 0
            } else {
                draggedTargetInsertPosition = pendingColumnOrder.length
                columnDragIndicatorY = columnManagerList.contentHeight
            }
            return
        }
        var item = columnManagerList.itemAtIndex(visibleIndex)
        var entry = visibleColumnManagerItems[visibleIndex]
        if (!item || !entry) return
        var after = contentY > item.y + item.height / 2
        draggedTargetInsertPosition = Number(entry.position) + (after ? 1 : 0)
        columnDragIndicatorY = item.y + (after ? item.height : 0)
    }

    function finishColumnDrag() {
        if (draggedColumnOriginalIndex >= 0 && draggedTargetInsertPosition >= 0)
            movePendingColumnToInsertPosition(draggedColumnOriginalIndex, draggedTargetInsertPosition)
        draggedColumnOriginalIndex = -1
        draggedTargetInsertPosition = -1
        columnDragIndicatorY = -1
    }

    function cancelColumnDrag() {
        draggedColumnOriginalIndex = -1
        draggedTargetInsertPosition = -1
        columnDragIndicatorY = -1
    }

    function ensureColumnConfiguration() {
        if (columns.length === 0) {
            columnOrder = []
            columnVisibility = ({})
            displayedColumns = []
            return
        }
        var valid = columnOrder.length === columns.length
        if (valid) {
            var seen = ({})
            for (var i = 0; i < columnOrder.length; ++i) {
                var idx = Number(columnOrder[i])
                if (idx < 0 || idx >= columns.length || seen[idx]) { valid = false; break }
                seen[idx] = true
            }
        }
        if (!valid) {
            var order = []
            var visibility = ({})
            for (var c = 0; c < columns.length; ++c) {
                order.push(c)
                visibility[String(c)] = columns[c].technicalHidden === true ? false : true
            }
            columnOrder = order
            columnVisibility = visibility
        } else {
            var normalized = ({})
            for (var j = 0; j < columns.length; ++j)
                normalized[String(j)] = columns[j].technicalHidden === true ? false : (columnVisibility[String(j)] !== false)
            columnVisibility = normalized
        }
    }

    function refreshDisplayedColumns() {
        ensureColumnConfiguration()
        var result = []
        for (var p = 0; p < columnOrder.length; ++p) {
            var originalIndex = Number(columnOrder[p])
            if (columnVisibility[String(originalIndex)] === false) continue
            var source = columns[originalIndex]
            if (!source || source.technicalHidden === true) continue
            result.push({
                "alias": source.alias,
                "fieldName": source.fieldName,
                "fieldIndex": source.fieldIndex,
                "sampleValue": source.sampleValue,
                "width": source.width,
                "originalIndex": originalIndex
            })
        }
        displayedColumns = result
        if (horizontalSlider) horizontalOffset = Math.min(horizontalOffset, maxHorizontalOffset(scrollingHeaderViewport ? scrollingHeaderViewport.width : 0))
    }

    function cloneArray(source) {
        var result = []
        for (var i = 0; i < source.length; ++i) result.push(source[i])
        return result
    }

    function openColumnManager() {
        ensureColumnConfiguration()
        pendingColumnOrder = cloneArray(columnOrder)
        pendingColumnVisibility = ({})
        for (var key in columnVisibility)
            pendingColumnVisibility[key] = columnVisibility[key] !== false

        columnSearchText = ""
        filterColumnManagerItems()
        refreshSelectedColumnManagerItems()
        columnManagerDialog.open()
    }

    function filterColumnManagerItems() {
        var needle = String(columnSearchText || "").toLowerCase().trim()
        var result = []
        for (var p = 0; p < pendingColumnOrder.length; ++p) {
            var originalIndex = Number(pendingColumnOrder[p])
            var col = columns[originalIndex]
            if (!col || col.technicalHidden === true) continue
            var label = col.alias || col.fieldName || qsTr("Champ")
            var haystack = (String(label) + " " + String(col.fieldName || "")).toLowerCase()
            if (needle.length === 0 || haystack.indexOf(needle) >= 0)
                result.push({ "originalIndex": originalIndex, "position": p, "label": label, "fieldName": col.fieldName || "" })
        }
        visibleColumnManagerItems = result
    }

    function refreshSelectedColumnManagerItems() {
        var result = []
        for (var p = 0; p < pendingColumnOrder.length; ++p) {
            var originalIndex = Number(pendingColumnOrder[p])
            var col = columns[originalIndex]
            if (!col || col.technicalHidden === true) continue
            if (pendingColumnVisibility[String(originalIndex)] === false) continue
            result.push({
                "originalIndex": originalIndex,
                "position": p,
                "label": col.alias || col.fieldName || qsTr("Champ"),
                "fieldName": col.fieldName || ""
            })
        }
        selectedColumnManagerItems = result
    }

    function beginSelectedColumnDrag(originalIndex) {
        selectedDragOriginalIndex = Number(originalIndex)
        selectedDragTargetPosition = -1
        selectedDragIndicatorY = -1
    }

    function updateSelectedColumnDrag(contentY) {
        if (selectedDragOriginalIndex < 0) return

        var visibleIndex = selectedOrderList.indexAt(10, contentY)
        if (visibleIndex < 0) {
            if (contentY <= 0) {
                selectedDragTargetPosition = 0
                selectedDragIndicatorY = 0
            } else {
                selectedDragTargetPosition = pendingColumnOrder.length
                selectedDragIndicatorY = selectedOrderList.contentHeight
            }
            return
        }

        var item = selectedOrderList.itemAtIndex(visibleIndex)
        var entry = selectedColumnManagerItems[visibleIndex]
        if (!item || !entry) return

        var after = contentY > item.y + item.height / 2
        selectedDragTargetPosition = Number(entry.position) + (after ? 1 : 0)
        selectedDragIndicatorY = item.y + (after ? item.height : 0)
    }

    function finishSelectedColumnDrag() {
        if (selectedDragOriginalIndex >= 0 && selectedDragTargetPosition >= 0)
            movePendingColumnToInsertPosition(selectedDragOriginalIndex, selectedDragTargetPosition)

        selectedDragOriginalIndex = -1
        selectedDragTargetPosition = -1
        selectedDragIndicatorY = -1
        refreshSelectedColumnManagerItems()
    }

    function cancelSelectedColumnDrag() {
        selectedDragOriginalIndex = -1
        selectedDragTargetPosition = -1
        selectedDragIndicatorY = -1
    }

    function setPendingColumnVisible(originalIndex, checked) {
        var copy = ({})
        for (var key in pendingColumnVisibility)
            copy[key] = pendingColumnVisibility[key] !== false
        copy[String(originalIndex)] = checked
        pendingColumnVisibility = copy
        filterColumnManagerItems()
        refreshSelectedColumnManagerItems()
    }

    function setAllPendingColumnsVisible(checked) {
        var copy = ({})
        for (var i = 0; i < columns.length; ++i)
            copy[String(i)] = columns[i].technicalHidden === true ? false : checked
        pendingColumnVisibility = copy
        filterColumnManagerItems()
        refreshSelectedColumnManagerItems()
    }

    function invertPendingColumns() {
        var copy = ({})
        for (var i = 0; i < columns.length; ++i)
            copy[String(i)] = columns[i].technicalHidden === true
                              ? false
                              : (pendingColumnVisibility[String(i)] === false)
        pendingColumnVisibility = copy
        filterColumnManagerItems()
        refreshSelectedColumnManagerItems()
    }

    function movePendingColumn(originalIndex, direction) {
        // Dans le panneau de droite, ▲/▼ agit par rapport aux autres
        // colonnes visibles et non par rapport aux champs masqués.
        refreshSelectedColumnManagerItems()
        var selected = selectedColumnManagerItems
        var selectedPos = -1
        for (var s = 0; s < selected.length; ++s)
            if (Number(selected[s].originalIndex) === Number(originalIndex)) {
                selectedPos = s
                break
            }

        var targetSelected = selectedPos + direction
        if (selectedPos < 0 || targetSelected < 0 || targetSelected >= selected.length) return

        var targetEntry = selected[targetSelected]
        var insertPos = Number(targetEntry.position)
        if (direction > 0) insertPos += 1

        movePendingColumnToInsertPosition(Number(originalIndex), insertPos)
        refreshSelectedColumnManagerItems()
    }

    function resetPendingColumns() {
        var order = []
        var visibility = ({})
        for (var i = 0; i < columns.length; ++i) {
            order.push(i)
            visibility[String(i)] = columns[i].technicalHidden === true ? false : true
        }
        pendingColumnOrder = order
        pendingColumnVisibility = visibility
        filterColumnManagerItems()
        refreshSelectedColumnManagerItems()
    }

    function applyPendingColumns() {
        columnOrder = cloneArray(pendingColumnOrder)
        var visibility = ({})
        for (var key in pendingColumnVisibility) visibility[key] = pendingColumnVisibility[key] !== false
        columnVisibility = visibility
        refreshDisplayedColumns()
        horizontalOffset = 0
        saveColumnConfiguration()
        columnManagerDialog.close()
    }

    function cancelPendingColumns() {
        columnManagerDialog.close()
    }

    function visibleColumnCount() {
        var count = 0
        for (var i = 0; i < pendingColumnOrder.length; ++i)
            if (pendingColumnVisibility[String(pendingColumnOrder[i])] !== false) count++
        return count
    }

    function beginColumnResize(columnIndex, startWidth) {
        resizingColumnIndex = Number(columnIndex)
        resizingColumnWidth = Math.max(70, Math.min(700, Number(startWidth)))
    }

    function previewColumnResize(columnIndex, width) {
        if (Number(columnIndex) !== resizingColumnIndex) return
        resizingColumnWidth = Math.max(70, Math.min(700, Number(width)))
    }

    function effectiveColumnWidth(columnData) {
        if (!columnData) return 140
        return Number(columnData.originalIndex) === resizingColumnIndex && resizingColumnWidth > 0
               ? resizingColumnWidth
               : columnData.width
    }

    function commitColumnResize(columnIndex, width) {
        var finalWidth = Math.max(70, Math.min(700, Number(width)))
        resizingColumnIndex = -1
        resizingColumnWidth = -1

        if (columnIndex < 0 || columnIndex >= columns.length) return

        var next = []
        for (var i = 0; i < columns.length; ++i) {
            var c = columns[i]
            next.push({
                "alias": c.alias,
                "fieldName": c.fieldName,
                "fieldIndex": c.fieldIndex,
                "fieldObject": c.fieldObject,
                "sampleValue": c.sampleValue,
                "width": i === Number(columnIndex) ? finalWidth : c.width,
                "technicalHidden": c.technicalHidden === true
            })
        }

        columns = next
        refreshDisplayedColumns()
        saveColumnConfiguration()
    }

    function cancelColumnResize() {
        resizingColumnIndex = -1
        resizingColumnWidth = -1
    }

    function hasActiveFilter(columnIndex) {
        return activeColumnFilters[String(columnIndex)] !== undefined
    }

    function openHeaderFilter(columnIndex) {
        filterColumn = Number(columnIndex)
        var f = activeColumnFilters[String(filterColumn)]

        if (f) {
            filterMode = f.mode || "values"
            filterText = f.text || ""
            selectedDistinctKeys = cloneSelection(f.selected || ({}))
        } else {
            filterMode = "values"
            filterText = ""
            selectedDistinctKeys = ({})
        }

        headerFilterDialog.open()
    }

    function storeCurrentColumnFilter() {
        if (filterColumn<0) return
        var c=({})
        for (var k in activeColumnFilters) c[k]=activeColumnFilters[k]
        c[String(filterColumn)]={"mode":filterMode,"text":String(filterText||""),
                                 "selected":cloneSelection(selectedDistinctKeys)}
        activeColumnFilters=c
    }

    function rowMatchesAllFilters(row) {
        for (var k in activeColumnFilters) {
            var idx=Number(k), f=activeColumnFilters[k]
            var value=rowValue(row,idx)
            var text=String(value===undefined||value===null?"":value)
            var needle=String(f.text||"").toLowerCase().trim()
            if (f.mode==="values" && (!f.selected || f.selected[distinctKey(value)]!==true)) return false
            if (f.mode==="empty" && !valueIsEmpty(value)) return false
            if (f.mode==="notempty" && valueIsEmpty(value)) return false
            if (f.mode==="equals" && text.toLowerCase()!==needle) return false
            if (f.mode==="contains" && needle.length>0 && text.toLowerCase().indexOf(needle)<0) return false
        }
        return true
    }

    function applyHeaderFilter() {
        if (filterColumn < 0 || filterColumn >= columns.length) return

        if (filterMode === "values") {
            rebuildDistinctValues()

            var f = activeColumnFilters[String(filterColumn)]
            if (f && f.selected)
                selectedDistinctKeys = cloneSelection(f.selected)
            else {
                // À la première ouverture, tout est sélectionné par défaut.
                var all = ({})
                for (var i = 0; i < distinctValues.length; ++i)
                    all[distinctValues[i].key] = true
                selectedDistinctKeys = all
            }

            pendingDistinctKeys = cloneSelection(selectedDistinctKeys)
            distinctSearchText = ""
            filterDistinctList()
            headerFilterDialog.close()
            distinctFilterDialog.open()
            return
        }

        var copy = ({})
        for (var key in activeColumnFilters) copy[key] = activeColumnFilters[key]

        var meaningful = filterMode === "empty" || filterMode === "notempty" ||
                         ((filterMode === "contains" || filterMode === "equals") &&
                          String(filterText || "").trim().length > 0)

        if (meaningful) {
            copy[String(filterColumn)] = {
                "mode": filterMode,
                "text": String(filterText || ""),
                "selected": ({})
            }
        } else {
            delete copy[String(filterColumn)]
        }

        activeColumnFilters = copy
        applyView()
        headerFilterDialog.close()
    }

    function clearHeaderFilter() {
        if (filterColumn < 0) return

        var copy = ({})
        for (var key in activeColumnFilters)
            if (Number(key) !== Number(filterColumn))
                copy[key] = activeColumnFilters[key]

        activeColumnFilters = copy
        filterText = ""
        selectedDistinctKeys = ({})
        applyView()
        headerFilterDialog.close()
    }

    function clearAllFilters() {
        activeColumnFilters=({})
        filterColumn=-1
        applyView()
    }

    function currentSharedViewObject() {
        var fs = []

        for (var k in activeColumnFilters) {
            var idx = Number(k)
            var f = activeColumnFilters[k]
            var vals = []

            if (f.selected) {
                for (var v in f.selected)
                    if (f.selected[v] === true)
                        vals.push(v)
            }

            fs.push({
                "field": columns[idx].fieldName,
                "mode": f.mode,
                "text": f.text || "",
                "values": vals
            })
        }

        var vis = []

        for (var p = 0; p < columnOrder.length; ++p) {
            var ci = Number(columnOrder[p])

            if (columns[ci] &&
                !columns[ci].technicalHidden &&
                columnVisibility[String(ci)] !== false)
                vis.push(columns[ci].fieldName)
        }

        return {
            "format": "QFieldTableView",
            "version": 2,
            "layer": layerName(selectedLayer),
            "filters": fs,
            "visibleColumns": vis
        }
    }

    function findSharedViewsLayer() {
        var layers = []

        try {
            var projectLayers = ProjectUtils.mapLayers(qgisProject)

            if (projectLayers) {
                for (var key in projectLayers)
                    layers.push(projectLayers[key])
            }
        } catch (e) {
            console.log("QField Table v0.12.10 recherche qfield_table_vues : " + e)
        }

        for (var i = 0; i < layers.length; ++i) {
            if (layerName(layers[i]) === sharedViewsLayerName)
                return layers[i]
        }

        return null
    }

    function sharedViewAttribute(feature, fieldName) {
        if (!feature)
            return ""

        try {
            var value = feature.attribute(fieldName)
            return value === undefined || value === null ? "" : String(value)
        } catch (e) {
            return ""
        }
    }

    function loadSharedViews() {
        sharedViewsError = ""
        sharedViewsLayer = findSharedViewsLayer()
        sharedViewsListModel.clear()

        if (!sharedViewsLayer) {
            sharedViewsError =
                qsTr("La table « qfield_table_vues » n’est pas chargée dans le projet.")
            return false
        }

        var iterator = null

        try {
            iterator = LayerUtils.createFeatureIterator(sharedViewsLayer)

            while (iterator && iterator.hasNext()) {
                var feature = iterator.next()
                var title = sharedViewAttribute(feature, "titre")
                var layerTitle = sharedViewAttribute(feature, "couche")
                var status = sharedViewAttribute(feature, "statut")
                var author = sharedViewAttribute(feature, "auteur")
                var updated = sharedViewAttribute(feature, "date_modification")
                var created = sharedViewAttribute(feature, "date_creation")

                sharedViewsListModel.append({
                    "featureId": String(feature.id),
                    "uuid": sharedViewAttribute(feature, "vue_uuid"),
                    "title": title,
                    "label": (title.length > 0 ? title : qsTr("Vue sans titre")) +
                             " — " +
                             (status.length > 0 ? status : qsTr("À faire")),
                    "message": sharedViewAttribute(feature, "message"),
                    "layerName": layerTitle,
                    "viewJson": sharedViewAttribute(feature, "vue_json"),
                    "status": status.length > 0 ? status : "À faire",
                    "author": author,
                    "dateText": updated.length > 0 ? updated : created
                })
            }

            Qt.callLater(function() {
                plugin.synchronizeSharedViewSelection()
            })

            return true

        } catch (e) {
            sharedViewsError =
                qsTr("Lecture de qfield_table_vues impossible : %1")
                .arg(String(e))
            return false

        } finally {
            try {
                if (iterator)
                    iterator.close()
            } catch (closeError) {}
        }
    }

    function createSharedView(title, message, status) {
        title = String(title || "").trim()

        if (title.length === 0) {
            sharedViewsError = qsTr("Donnez un titre à la vue.")
            return false
        }

        sharedViewsLayer = findSharedViewsLayer()

        if (!sharedViewsLayer) {
            sharedViewsError =
                qsTr("La table « qfield_table_vues » n’est pas chargée dans le projet.")
            return false
        }

        try {
            var feature = FeatureUtils.createFeature(sharedViewsLayer)
            var now = journalTimestamp()

            feature.setAttribute("vue_uuid", journalUuid())
            feature.setAttribute("date_creation", now)
            feature.setAttribute("date_modification", now)
            feature.setAttribute("auteur", journalCloudUser())
            feature.setAttribute("titre", title)
            feature.setAttribute("message", String(message || ""))
            feature.setAttribute("couche", layerName(selectedLayer))
            feature.setAttribute(
                "vue_json",
                JSON.stringify(currentSharedViewObject())
            )
            feature.setAttribute("statut", String(status || "À faire"))

            sharedViewSaveModel.currentLayer = sharedViewsLayer
            sharedViewSaveModel.feature = feature
            sharedViewSaveModel.updateAttributesFromFeature(feature)

            if (!sharedViewSaveModel.create(true)) {
                sharedViewsError =
                    qsTr("QField n’a pas pu créer la vue partagée.")
                return false
            }

            loadSharedViews()
            return true

        } catch (e) {
            sharedViewsError =
                qsTr("Création de la vue impossible : %1").arg(String(e))
            return false
        }
    }

    function selectedSharedView() {
        if (sharedViewsCombo.currentIndex < 0 ||
            sharedViewsCombo.currentIndex >= sharedViewsListModel.count)
            return null

        return sharedViewsListModel.get(sharedViewsCombo.currentIndex)
    }

    function vectorLayerIndexByName(nameValue) {
        var wanted = String(nameValue || "")

        for (var i = 0; i < vectorLayers.length; ++i) {
            if (layerName(vectorLayers[i]) === wanted)
                return i
        }

        return -1
    }

    function synchronizeSharedViewSelection() {
        if (sharedViewsListModel.count <= 0) {
            sharedViewsCombo.currentIndex = -1
            return
        }

        if (sharedViewsCombo.currentIndex < 0 ||
            sharedViewsCombo.currentIndex >= sharedViewsListModel.count)
            sharedViewsCombo.currentIndex = 0

        var item = selectedSharedView()

        if (!item)
            return

        var statuses = ["À faire", "En cours", "Terminé", "Archivé"]
        var idx = statuses.indexOf(String(item.status || "À faire"))

        if (idx < 0)
            idx = 0

        sharedViewStatusCombo.currentIndex = idx
    }

    function continuePendingSharedViewApplication() {
        if (pendingSharedViewJson.length === 0) {
            sharedViewApplyTimer.stop()
            return
        }

        pendingSharedViewAttempts++

        // selectLayer() construit le schéma en plusieurs étapes. Attendre
        // simplement que les colonnes soient disponibles.
        if (layerName(selectedLayer) === pendingSharedViewLayerName &&
            columns.length > 0) {

            var json = pendingSharedViewJson
            var title = pendingSharedViewTitle

            pendingSharedViewJson = ""
            pendingSharedViewTitle = ""
            pendingSharedViewLayerName = ""
            pendingSharedViewAttempts = 0
            sharedViewApplyTimer.stop()

            if (importSharedViewCode(json)) {
                try {
                    mainWindow.displayToast(
                        qsTr("Vue « %1 » appliquée.").arg(title)
                    )
                } catch (e) {}

                sharedViewsDialog.close()
            }

            return
        }

        if (pendingSharedViewAttempts >= 20) {
            sharedViewApplyTimer.stop()
            sharedViewsError =
                qsTr("La couche cible n’a pas pu être préparée pour appliquer la vue.")

            pendingSharedViewJson = ""
            pendingSharedViewTitle = ""
            pendingSharedViewLayerName = ""
            pendingSharedViewAttempts = 0
        }
    }

    function applySelectedSharedView() {
        sharedViewsError = ""

        var item = selectedSharedView()

        if (!item) {
            sharedViewsError = qsTr("Aucune vue n’est sélectionnée.")
            return false
        }

        var targetName = String(item.layerName || "")
        var json = String(item.viewJson || "")

        if (targetName.length === 0 || json.length === 0) {
            sharedViewsError =
                qsTr("La vue sélectionnée ne contient pas toutes les informations nécessaires.")
            return false
        }

        // Si la couche est déjà active et prête, appliquer immédiatement.
        if (layerName(selectedLayer) === targetName && columns.length > 0) {
            if (importSharedViewCode(json)) {
                try {
                    mainWindow.displayToast(
                        qsTr("Vue « %1 » appliquée.").arg(item.title)
                    )
                } catch (e) {}

                return true
            }

            return false
        }

        // Sinon, sélectionner automatiquement la couche enregistrée avec la vue.
        var targetIndex = vectorLayerIndexByName(targetName)

        if (targetIndex < 0) {
            sharedViewsError =
                qsTr("La couche « %1 » n’est pas disponible dans QField Table.")
                .arg(targetName)
            return false
        }

        pendingSharedViewJson = json
        pendingSharedViewTitle = String(item.title || "")
        pendingSharedViewLayerName = targetName
        pendingSharedViewAttempts = 0

        try {
            layerCombo.currentIndex = targetIndex
        } catch (comboError) {}

        selectLayer(targetIndex)
        sharedViewApplyTimer.restart()

        return true
    }


    function findSharedViewFeature(featureIdText, uuidText) {
        if (!sharedViewsLayer)
            return null

        var wantedId = String(featureIdText || "")
        var wantedUuid = String(uuidText || "")
        var iterator = null

        try {
            iterator = LayerUtils.createFeatureIterator(sharedViewsLayer)

            while (iterator && iterator.hasNext()) {
                var feature = iterator.next()

                if (wantedUuid.length > 0 &&
                    sharedViewAttribute(feature, "vue_uuid") === wantedUuid)
                    return feature

                if (wantedId.length > 0 &&
                    String(feature.id) === wantedId)
                    return feature
            }
        } catch (e) {
            sharedViewsError = String(e)
        } finally {
            try {
                if (iterator)
                    iterator.close()
            } catch (closeError) {}
        }

        return null
    }


    function updateSelectedSharedViewStatus(status) {
        var item = selectedSharedView()

        if (!item)
            return false

        sharedViewsLayer = findSharedViewsLayer()

        if (!sharedViewsLayer)
            return false

        try {
            var feature = findSharedViewFeature(item.featureId, item.uuid)

            if (!feature) {
                sharedViewsError =
                    qsTr("La vue sélectionnée n’a pas été retrouvée.")
                return false
            }

            feature.setAttribute("statut", String(status || "À faire"))
            feature.setAttribute("date_modification", journalTimestamp())

            sharedViewSaveModel.currentLayer = sharedViewsLayer
            sharedViewSaveModel.feature = feature
            sharedViewSaveModel.updateAttributesFromFeature(feature)

            if (!sharedViewSaveModel.save(true)) {
                sharedViewsError =
                    qsTr("Le statut n’a pas pu être enregistré.")
                return false
            }

            loadSharedViews()
            return true

        } catch (e) {
            sharedViewsError = String(e)
            return false
        }
    }

    function makeSharedViewCode() {
        var fs=[]
        for (var k in activeColumnFilters) {
            var idx=Number(k), f=activeColumnFilters[k], vals=[]
            if (f.selected) for (var v in f.selected) if (f.selected[v]===true) vals.push(v)
            fs.push({"field":columns[idx].fieldName,"mode":f.mode,"text":f.text||"","values":vals})
        }
        var vis=[]
        for (var p=0;p<columnOrder.length;++p) {
            var ci=Number(columnOrder[p])
            if (columns[ci] && !columns[ci].technicalHidden && columnVisibility[String(ci)]!==false)
                vis.push(columns[ci].fieldName)
        }
        sharedViewCode=JSON.stringify(currentSharedViewObject(),null,2)
        shareText.text=sharedViewCode
        shareDialog.open()
    }

    function importSharedViewCode(txt) {
        try {
            var d = JSON.parse(String(txt || ""))

            if (!d || d.format !== "QFieldTableView")
                throw qsTr("Format QField Table invalide")

            // The shared view is tied to a layer schema. Refuse a clearly
            // different layer instead of silently applying field names that
            // may have another meaning.
            var importedLayerName = String(d.layer || "")
            var currentLayerName = layerName(selectedLayer)

            if (importedLayerName.length > 0 &&
                currentLayerName.length > 0 &&
                importedLayerName !== currentLayerName) {
                throw qsTr("Cette vue est prévue pour la couche « %1 », mais la couche active est « %2 ».")
                      .arg(importedLayerName)
                      .arg(currentLayerName)
            }

            // Technical field name -> current column index.
            var indexByName = ({})
            for (var i = 0; i < columns.length; ++i) {
                var technicalName = String(columns[i].fieldName || "")
                if (technicalName.length > 0)
                    indexByName[technicalName] = i
            }

            // ----------------------------------------------------------
            // 1. Restore active filters.
            // ----------------------------------------------------------
            var importedFilters = ({})

            for (var j = 0; j < (d.filters || []).length; ++j) {
                var f = d.filters[j] || ({})
                var filterField = String(f.field || "")
                var filterIndex = indexByName[filterField]

                if (filterIndex === undefined)
                    continue

                var selected = ({})
                var values = f.values || []

                for (var v = 0; v < values.length; ++v)
                    selected[String(values[v])] = true

                importedFilters[String(filterIndex)] = {
                    "mode": String(f.mode || "values"),
                    "text": String(f.text || ""),
                    "selected": selected
                }
            }

            activeColumnFilters = importedFilters
            filterColumn = -1
            filterText = ""
            selectedDistinctKeys = ({})

            // ----------------------------------------------------------
            // 2. Restore visible columns AND their order.
            //
            // visibleColumns is already serialized in the visible order.
            // Listed fields are put first in exactly that order.
            // Other fields are appended but hidden, so they remain available
            // later in the Columns dialog.
            // ----------------------------------------------------------
            if (d.visibleColumns !== undefined &&
                Array.isArray(d.visibleColumns)) {

                var importedOrder = []
                var importedVisibility = ({})
                var used = ({})

                for (var p = 0; p < d.visibleColumns.length; ++p) {
                    var fieldName = String(d.visibleColumns[p] || "")
                    var columnIndex = indexByName[fieldName]

                    if (columnIndex === undefined)
                        continue

                    columnIndex = Number(columnIndex)

                    if (used[String(columnIndex)] === true)
                        continue

                    used[String(columnIndex)] = true
                    importedOrder.push(columnIndex)

                    importedVisibility[String(columnIndex)] =
                        columns[columnIndex].technicalHidden === true
                        ? false
                        : true
                }

                // Keep all non-exported columns in the configuration, but hide
                // them. This makes the imported visibleColumns list exact.
                for (var c = 0; c < columns.length; ++c) {
                    if (used[String(c)] !== true)
                        importedOrder.push(c)

                    if (columns[c].technicalHidden === true)
                        importedVisibility[String(c)] = false
                    else if (used[String(c)] !== true)
                        importedVisibility[String(c)] = false
                }

                columnOrder = importedOrder
                columnVisibility = importedVisibility

                refreshDisplayedColumns()
                horizontalOffset = 0

                // Persist the imported choice exactly like "Colonnes > Appliquer".
                saveColumnConfiguration()
            }

            // ----------------------------------------------------------
            // 3. Re-evaluate the rows using all imported filters.
            // ----------------------------------------------------------
            applyView()

            // Close any currently selected detail that might refer to a
            // column hidden by the imported view.
            selectedCellColumn = -1
            selectedCellAlias = ""
            selectedCellFieldName = ""
            selectedCellValue = ""

            // Import réussi : ne pas utiliser diagnosticMessage, car cette
            // propriété est réservée aux avertissements/erreurs dans l'UI.
            diagnosticMessage = ""

            return true

        } catch (e) {
            diagnosticMessage =
                qsTr("Import impossible : %1").arg(String(e))
            return false
        }
    }


    function batchSelectionCount() {
        var count = 0
        for (var key in batchSelectedIds)
            if (batchSelectedIds[key] === true) count++
        return count
    }

    function isBatchSelected(featureIdValue) {
        return batchSelectedIds[String(featureIdValue)] === true
    }

    function setBatchSelected(featureIdValue, checked) {
        var copy = ({})
        for (var key in batchSelectedIds) copy[key] = batchSelectedIds[key] === true
        if (checked) copy[String(featureIdValue)] = true
        else delete copy[String(featureIdValue)]
        batchSelectedIds = copy
    }

    function clearBatchSelection() {
        batchSelectedIds = ({})
    }

    function selectAllFilteredRows() {
        var copy = ({})
        for (var i = 0; i < filteredRows.length; ++i)
            copy[String(filteredRows[i].featureId)] = true
        batchSelectedIds = copy
    }

    function selectedBatchRows() {
        var result = []
        for (var i = 0; i < flatRows.length; ++i)
            if (isBatchSelected(flatRows[i].featureId)) result.push(flatRows[i])
        return result
    }

    function parseStoredCollection(rawValue) {
        var text = String(rawValue === undefined || rawValue === null ? "" : rawValue).trim()
        if (text.length === 0 || text === "{}") return []
        if (text.charAt(0) === "{" && text.charAt(text.length - 1) === "}")
            text = text.substring(1, text.length - 1)

        var result = []
        var current = ""
        var quoted = false
        for (var i = 0; i < text.length; ++i) {
            var ch = text.charAt(i)
            if (ch === '"') {
                quoted = !quoted
                continue
            }
            if (ch === "," && !quoted) {
                if (current.trim().length > 0) result.push(current.trim())
                current = ""
            } else current += ch
        }
        if (current.trim().length > 0) result.push(current.trim())
        return result
    }

    function collectionContains(values, value) {
        var needle = String(value)
        for (var i = 0; i < values.length; ++i)
            if (String(values[i]) === needle) return true
        return false
    }

    function serializeStoredCollection(values) {
        var clean = []
        for (var i = 0; i < values.length; ++i) {
            var value = String(values[i] === undefined || values[i] === null ? "" : values[i]).trim()
            if (value.length === 0 || collectionContains(clean, value)) continue
            clean.push(value)
        }
        if (clean.length === 0) return "{}"

        var quoted = []
        for (var j = 0; j < clean.length; ++j)
            quoted.push('"' + clean[j].replace(/"/g, '\\"') + '"')
        return "{" + quoted.join(",") + "}"
    }

    function rawAttributeForRow(row, columnIndex) {
        if (!row || columnIndex < 0 || columnIndex >= columns.length) return ""
        try { return readAttribute(row.feature, columns[columnIndex]) }
        catch (e) { return "" }
    }

    function xmlDecode(value) {
        var s = String(value === undefined || value === null ? "" : value)
        return s.replace(/&quot;/g, "\"")
                .replace(/&apos;/g, "'")
                .replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">")
                .replace(/&amp;/g, "&")
                .replace(/&#10;/g, "\n")
                .replace(/&#13;/g, "\r")
    }

    function xmlAttribute(tagText, attributeName) {
        var source = String(tagText || "")
        var safeName = String(attributeName)
                .replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

        // L'attribut XML peut être entre guillemets doubles tout en contenant
        // des apostrophes, par exemple :
        // value="&quot;type&quot; = 'Carte topographique'"
        // On mémorise donc le délimiteur réellement utilisé.
        var re = new RegExp(
            "\\b" + safeName + "\\s*=\\s*([\"'])([\\s\\S]*?)\\1",
            "i"
        )

        var m = re.exec(source)
        return m ? xmlDecode(m[2]) : ""
    }

    function projectFilePath() {
        try {
            var p = typeof qgisProject.fileName === "function"
                    ? qgisProject.fileName() : qgisProject.fileName
            return String(p || "")
        } catch (e) {
            return ""
        }
    }

    function projectFieldIndexByName(fieldName) {
        var wanted = String(fieldName || "")
        for (var i = 0; i < columns.length; ++i) {
            if (String(columns[i].fieldName || "") === wanted)
                return Number(columns[i].fieldIndex)
        }
        return -1
    }

    function optionValueFromConfig(configText, optionName) {
        var source = String(configText || "")
        var wanted = String(optionName || "")

        var optionRe = /<Option\b[^>]*>/gi
        var match

        while ((match = optionRe.exec(source)) !== null) {
            var tag = match[0]
            var name = xmlAttribute(tag, "name")

            if (name === wanted) {
                // Some QGIS options of type "invalid" have no value attr.
                // Return the empty string in that case, which is correct.
                return xmlAttribute(tag, "value")
            }
        }

        return ""
    }

    function countOccurrences(text, needle) {
        var source = String(text || "")
        var wanted = String(needle || "")
        if (wanted.length === 0) return 0

        var count = 0
        var pos = 0
        var lowerSource = source.toLowerCase()
        var lowerWanted = wanted.toLowerCase()

        while ((pos = lowerSource.indexOf(lowerWanted, pos)) >= 0) {
            count++
            pos += lowerWanted.length
        }
        return count
    }

    function plainXmlContext(text, center, radius) {
        var source = String(text || "")
        var start = Math.max(0, Number(center) - (radius || 600))
        var end = Math.min(source.length, Number(center) + (radius || 600))
        var excerpt = source.substring(start, end)

        return excerpt.replace(/\r?\n/g, " ")
                      .replace(/\s+/g, " ")
                      .replace(/>\s+</g, "><")
    }

    function extractValueMapConfig(editBody) {
        var body = String(editBody || "")
        var items = []

        // Isolate the nested option named "map". QGIS stores each entry as:
        // <Option value="stored" ... name="Displayed label"/>
        var mapStartRe = /<Option\b[^>]*\bname=["']map["'][^>]*>/i
        var sm = mapStartRe.exec(body)
        var segment = body

        if (sm) {
            var start = sm.index + sm[0].length
            var depth = 1
            var tagRe = /<\/?Option\b[^>]*>/gi
            tagRe.lastIndex = start
            var tm
            var end = body.length
            while ((tm = tagRe.exec(body)) !== null) {
                if (/^<Option\b/i.test(tm[0]) && !/\/>$/.test(tm[0]))
                    depth++
                else if (/^<\/Option/i.test(tm[0]))
                    depth--
                if (depth === 0) {
                    end = tm.index
                    break
                }
            }
            segment = body.substring(start, end)
        }

        var optionRe = /<Option\b[^>]*\/>/gi
        var om
        while ((om = optionRe.exec(segment)) !== null) {
            var tag = om[0]
            var label = xmlAttribute(tag, "name")
            var value = xmlAttribute(tag, "value")
            if (!label || label === "map") continue
            items.push({ "label": label, "value": value })
        }

        return ({ "map": items })
    }

    function registerValueMapFromXml(fieldName, config) {
        var fieldIndex = projectFieldIndexByName(fieldName)
        if (fieldIndex < 0 || !config || !config.map || config.map.length === 0)
            return false
        registerProjectWidgetConfig(fieldIndex, fieldName, "ValueMap", config)
        return true
    }

    function parseValueMapsStandard(xmlText) {
        var source = String(xmlText || "")
        var registered = 0
        var fieldRe =
            /<field\b([^>]*)\bname=["']([^"']+)["']([^>]*)>([\s\S]*?)<\/field>/gi
        var match

        while ((match = fieldRe.exec(source)) !== null) {
            var fieldName = xmlDecode(match[2])
            var body = match[4]
            var editRe = /<editWidget\b([^>]*)>([\s\S]*?)<\/editWidget>/gi
            var edit
            while ((edit = editRe.exec(body)) !== null) {
                var tag = "<editWidget " + edit[1] + ">"
                if (String(xmlAttribute(tag, "type")).toLowerCase() !== "valuemap")
                    continue
                if (registerValueMapFromXml(fieldName, extractValueMapConfig(edit[2])))
                    registered++
                break
            }
        }
        return registered
    }

    function batchValueMapForColumn(columnIndex) {
        var info = batchWidgetInfo(columnIndex)
        if (String(info.type || "").toLowerCase() !== "valuemap")
            return []
        var cfg = info.config || ({})
        return cfg.map || []
    }

    function refreshBatchValueMap() {
        refreshBatchRelationType()
        batchValueMapItems = batchValueMapForColumn(batchFieldColumn)
        batchIsValueMap = batchValueMapItems.length > 0
        if (batchIsValueMap && batchValueMapItems.length > 0)
            batchValueText = String(batchValueMapItems[0].value)
    }

    function batchValueMapLabel(rawValue) {
        var raw = String(rawValue === undefined || rawValue === null ? "" : rawValue)
        for (var i=0; i<batchValueMapItems.length; ++i)
            if (String(batchValueMapItems[i].value) === raw)
                return String(batchValueMapItems[i].label)
        return raw
    }

    function extractValueRelationConfig(editTagAttributes, editBody) {
        var cfgText = String(editBody || "")
        return ({
            "Layer": optionValueFromConfig(cfgText, "Layer"),
            "LayerName": optionValueFromConfig(cfgText, "LayerName"),
            "LayerSource": optionValueFromConfig(cfgText, "LayerSource"),
            "Key": optionValueFromConfig(cfgText, "Key"),
            "Value": optionValueFromConfig(cfgText, "Value"),
            "AllowMulti": optionValueFromConfig(cfgText, "AllowMulti"),
            "FilterExpression": optionValueFromConfig(cfgText, "FilterExpression"),
            "OrderByValue": optionValueFromConfig(cfgText, "OrderByValue"),
            "AllowNull": optionValueFromConfig(cfgText, "AllowNull")
        })
    }

    function registerValueRelationFromXml(fieldName, config, sourceLabel) {
        var fieldIndex = projectFieldIndexByName(fieldName)
        if (fieldIndex < 0) return false

        registerProjectWidgetConfig(
            fieldIndex,
            fieldName,
            "ValueRelation",
            config
        )
        return true
    }

    function parseValueRelationsStandard(xmlText) {
        var source = String(xmlText || "")
        var registered = 0
        var fieldRe =
            /<field\b([^>]*)\bname=["']([^"']+)["']([^>]*)>([\s\S]*?)<\/field>/gi
        var match

        while ((match = fieldRe.exec(source)) !== null) {
            var fieldName = xmlDecode(match[2])
            var body = match[4]
            var edit =
                /<editWidget\b([^>]*)\btype=["']ValueRelation["']([^>]*)>([\s\S]*?)<\/editWidget>/i.exec(body)

            if (!edit) {
                // Some serializers can place type before/after other attributes.
                edit = /<editWidget\b([^>]*)>([\s\S]*?)<\/editWidget>/i.exec(body)
                if (!edit) continue

                var completeTag = "<editWidget " + edit[1] + ">"
                if (String(xmlAttribute(completeTag, "type")).toLowerCase() !== "valuerelation")
                    continue

                if (registerValueRelationFromXml(
                        fieldName,
                        extractValueRelationConfig(edit[1], edit[2]),
                        "standard")) {
                    registered++
                }
                continue
            }

            if (registerValueRelationFromXml(
                    fieldName,
                    extractValueRelationConfig(edit[1] + " " + edit[2], edit[3]),
                    "standard")) {
                registered++
            }
        }

        return registered
    }

    function parseValueRelationsByFieldNames(xmlText) {
        var source = String(xmlText || "")
        var lower = source.toLowerCase()
        var registered = 0

        // Use the actual fields of the selected layer as anchors.
        for (var c = 0; c < columns.length; ++c) {
            var fieldName = String(columns[c].fieldName || "")
            if (fieldName.length === 0) continue

            var escaped = fieldName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
            var fieldStartRe =
                new RegExp("<field\\\\b[^>]*\\\\bname=[\\\"']" + escaped + "[\\\"'][^>]*>", "i")
            var fm = fieldStartRe.exec(source)
            if (!fm) continue

            var fieldStart = fm.index
            var fieldEnd = lower.indexOf("</field>", fieldStart)
            if (fieldEnd < 0) fieldEnd = Math.min(source.length, fieldStart + 30000)

            var segment = source.substring(fieldStart, fieldEnd + 8)
            if (segment.toLowerCase().indexOf("valuerelation") < 0)
                continue

            var edit = /<editWidget\b([^>]*)>([\s\S]*?)<\/editWidget>/i.exec(segment)
            if (!edit) continue

            var tag = "<editWidget " + edit[1] + ">"
            if (String(xmlAttribute(tag, "type")).toLowerCase() !== "valuerelation")
                continue

            if (registerValueRelationFromXml(
                    fieldName,
                    extractValueRelationConfig(edit[1], edit[2]),
                    "field-name")) {
                registered++
            }
        }

        return registered
    }

    function parseValueRelationsGlobal(xmlText) {
        var source = String(xmlText || "")
        var lower = source.toLowerCase()
        var registered = 0
        var editRe = /<editWidget\b([^>]*)>([\s\S]*?)<\/editWidget>/gi
        var edit

        while ((edit = editRe.exec(source)) !== null) {
            var tag = "<editWidget " + edit[1] + ">"
            if (String(xmlAttribute(tag, "type")).toLowerCase() !== "valuerelation")
                continue

            var editStart = edit.index
            var lastFieldOpen = lower.lastIndexOf("<field", editStart)
            var lastFieldClose = lower.lastIndexOf("</field>", editStart)

            var fieldName = ""
            if (lastFieldOpen >= 0 && lastFieldOpen > lastFieldClose) {
                var fieldTagEnd = source.indexOf(">", lastFieldOpen)
                if (fieldTagEnd > lastFieldOpen) {
                    var fieldTag = source.substring(lastFieldOpen, fieldTagEnd + 1)
                    fieldName = xmlAttribute(fieldTag, "name")
                }
            }

            // If not nested in <field>, search backwards for a field name
            // within a conservative local window.
            if (fieldName.length === 0) {
                var contextStart = Math.max(0, editStart - 5000)
                var before = source.substring(contextStart, editStart)
                var re = /<field\b[^>]*\bname=["']([^"']+)["'][^>]*>/gi
                var m, lastName = ""
                while ((m = re.exec(before)) !== null)
                    lastName = xmlDecode(m[1])
                fieldName = lastName
            }

            if (fieldName.length > 0 &&
                registerValueRelationFromXml(
                    fieldName,
                    extractValueRelationConfig(edit[1], edit[2]),
                    "global")) {
                registered++
            }
        }

        return registered
    }

    function buildProjectXmlDiagnostic(content, sourceDescription, registeredCount) {
        var source = String(content || "")
        var lower = source.toLowerCase()

        var lines = []
        lines.push("QField Table v0.12.10 — diagnostic projet")
        lines.push("Source : " + sourceDescription)
        lines.push("Taille XML : " + source.length + " caractères")
        lines.push("")
        lines.push("Occurrences :")
        lines.push("  ValueRelation : " + countOccurrences(source, "ValueRelation"))
        lines.push("  <editWidget : " + countOccurrences(source, "<editWidget"))
        lines.push("  <fieldConfiguration : " + countOccurrences(source, "<fieldConfiguration"))
        lines.push("  AllowMulti : " + countOccurrences(source, "AllowMulti"))
        lines.push("  FilterExpression : " + countOccurrences(source, "FilterExpression"))
        lines.push("  Relations enregistrées par le plugin : " + registeredCount)
        lines.push("")

        var types = ({})
        var editRe = /<editWidget\b([^>]*)>/gi
        var edit
        while ((edit = editRe.exec(source)) !== null) {
            var type = xmlAttribute(edit[0], "type")
            if (type.length === 0) type = "(sans type)"
            types[type] = (types[type] || 0) + 1
        }

        lines.push("Types de widgets trouvés :")
        var typeNames = []
        for (var key in types) typeNames.push(key)
        typeNames.sort()
        if (typeNames.length === 0)
            lines.push("  aucun <editWidget> trouvé")
        else
            for (var t = 0; t < typeNames.length; ++t)
                lines.push("  " + typeNames[t] + " : " + types[typeNames[t]])

        lines.push("")
        lines.push("Champs visibles recherchés :")
        var maxFields = Math.min(columns.length, 40)
        for (var c = 0; c < maxFields; ++c) {
            var name = String(columns[c].fieldName || "")
            if (name.length === 0) continue
            var present = lower.indexOf('name="' + name.toLowerCase() + '"') >= 0 ||
                          lower.indexOf("name='" + name.toLowerCase() + "'") >= 0
            lines.push("  " + name + " : " + (present ? "présent dans XML" : "non trouvé"))
        }

        var vrPos = lower.indexOf("valuerelation")
        lines.push("")
        if (vrPos >= 0) {
            lines.push("Contexte de la première occurrence ValueRelation :")
            lines.push(plainXmlContext(source, vrPos, 1400))
        } else {
            lines.push("Aucune chaîne « ValueRelation » trouvée dans le .qgs interne.")

            // Helpful contexts for known multiple-field aliases/names.
            for (var i = 0; i < columns.length; ++i) {
                var colName = String(columns[i].fieldName || "")
                var colAlias = String(columns[i].alias || "")
                if (colAlias.toLowerCase().indexOf("multiple") < 0 &&
                    colAlias.toLowerCase().indexOf("multiples") < 0)
                    continue

                var pos = lower.indexOf(colName.toLowerCase())
                if (pos >= 0) {
                    lines.push("")
                    lines.push("Contexte du champ multiple « " + colName + " » :")
                    lines.push(plainXmlContext(source, pos, 1200))
                    break
                }
            }
        }

        projectXmlDiagnosticText = lines.join("\n")
        projectXmlSourceName = sourceDescription
    }

    function parseProjectWidgetConfigsXml(content, sourceDescription) {
        var xml = String(content || "")

        if (xml.length === 0 || xml.indexOf("<qgis") < 0) {
            projectConfigDiagnostic =
                qsTr("Le contenu XML du projet n'a pas pu être lu depuis %1.")
                .arg(sourceDescription)
            buildProjectXmlDiagnostic(xml, sourceDescription, 0)
            return false
        }

        var beforeCount = Object.keys(projectWidgetConfigs).length

        // v0.12.10: ValueMap / Liste de valeurs is stored in the project too.
        parseValueMapsStandard(xml)

        // Strategy 1: normal QGIS fieldConfiguration nesting.
        parseValueRelationsStandard(xml)

        // Strategy 2: anchor on actual technical field names.
        if (Object.keys(projectWidgetConfigs).length === beforeCount)
            parseValueRelationsByFieldNames(xml)

        // Strategy 3: global editWidget scan and nearest field association.
        if (Object.keys(projectWidgetConfigs).length === beforeCount)
            parseValueRelationsGlobal(xml)

        // Strategy 4: some embedded XML fragments may be XML-escaped once.
        if (Object.keys(projectWidgetConfigs).length === beforeCount &&
            xml.toLowerCase().indexOf("&lt;editwidget") >= 0) {
            var decoded = xmlDecode(xml)
            parseValueMapsStandard(decoded)
            parseValueRelationsStandard(decoded)
            if (Object.keys(projectWidgetConfigs).length === beforeCount)
                parseValueRelationsByFieldNames(decoded)
            if (Object.keys(projectWidgetConfigs).length === beforeCount)
                parseValueRelationsGlobal(decoded)
        }

        var afterCount = Object.keys(projectWidgetConfigs).length
        var found = Math.max(0, afterCount - beforeCount)

        buildProjectXmlDiagnostic(xml, sourceDescription, found)

        if (found > 0) {
            projectConfigDiagnostic =
                qsTr("%1 configuration(s) ValueRelation du projet détectée(s) dans %2.")
                .arg(found)
                .arg(sourceDescription)
            return true
        }

        projectConfigDiagnostic =
            qsTr("Aucune ValueRelation exploitable n'a été associée aux champs de la couche dans %1. Ouvrez « Diagnostic projet » pour voir la structure XML détectée.")
            .arg(sourceDescription)
        return false
    }

    function readProjectWidgetConfigsFromXml() {
        projectConfigReadAttempted = true
        projectConfigDiagnostic = ""

        var path = projectFilePath()
        if (path.length === 0) {
            projectConfigDiagnostic = qsTr("Impossible de déterminer le fichier du projet.")
            return false
        }

        var bytes
        try {
            bytes = FileUtils.readFileContent(path)
        } catch (e1) {
            projectConfigDiagnostic =
                qsTr("Lecture du projet impossible : %1").arg(String(e1))
            return false
        }

        if (/\.qgs$/i.test(path)) {
            try {
                return parseProjectWidgetConfigsXml(
                    QgzReader.bytesToUtf8(QgzReader.toUint8Array(bytes)),
                    qsTr("le projet .qgs")
                )
            } catch (e2) {
                projectConfigDiagnostic =
                    qsTr("Lecture du .qgs impossible : %1").arg(String(e2))
                return false
            }
        }

        if (/\.qgz$/i.test(path)) {
            try {
                var projectEntry = QgzReader.readQgsFromQgz(bytes)

                if (!projectEntry || !projectEntry.text) {
                    projectConfigDiagnostic =
                        qsTr("Le .qgz a été lu, mais aucun fichier .qgs n'a été trouvé dans l'archive.")
                    return false
                }

                return parseProjectWidgetConfigsXml(
                    projectEntry.text,
                    qsTr("le projet compressé .qgz (%1)").arg(projectEntry.name)
                )
            } catch (e3) {
                projectConfigDiagnostic =
                    qsTr("Lecture du projet .qgz impossible : %1").arg(String(e3))
                return false
            }
        }

        projectConfigDiagnostic =
            qsTr("Format de projet non pris en charge : %1").arg(path)
        return false
    }

    function registerProjectWidgetConfig(fieldIndex, fieldName, editorWidget, editorWidgetConfig) {
        var idx = Number(fieldIndex)
        if (isNaN(idx) || idx < 0) return

        var copy = ({})
        for (var key in projectWidgetConfigs) copy[key] = projectWidgetConfigs[key]
        copy[String(idx)] = {
            "type": String(editorWidget === undefined || editorWidget === null ? "" : editorWidget),
            "config": editorWidgetConfig || ({}),
            "fieldName": String(fieldName || "")
        }
        projectWidgetConfigs = copy
    }

    function clearProjectWidgetConfigs() {
        projectWidgetConfigs = ({})
    }

    function batchSetupValue(object, name, fallback) {
        if (object === null || object === undefined) return fallback
        try {
            if (typeof object[name] === "function") return object[name]()
            if (object[name] !== undefined) return object[name]
        } catch (e) {}
        return fallback
    }

    function batchWidgetInfo(columnIndex) {
        var info = { "type": "", "config": ({}), "source": "" }
        if (!selectedLayer || columnIndex < 0 || columnIndex >= columns.length)
            return info

        var col = columns[columnIndex]
        var fieldIndex = Number(col.fieldIndex)
        var cached = projectWidgetConfigs[String(fieldIndex)]

        if ((cached === undefined || cached === null) && !projectConfigReadAttempted) {
            readProjectWidgetConfigsFromXml()
            cached = projectWidgetConfigs[String(fieldIndex)]
        }

        if (cached !== undefined && cached !== null) {
            info.type = String(cached.type || "")
            info.config = cached.config || ({})
            info.source = "AttributeFormModel.EditorWidgetConfig"
        }

        return info
    }

    function batchConfigBoolean(config, names) {
        if (!config) return false

        for (var i = 0; i < names.length; ++i) {
            var key = names[i]
            try {
                var value = config[key]
                if (value === undefined || value === null) continue

                if (value === true || value === 1) return true

                var text = String(value).toLowerCase().trim()
                if (text === "true" || text === "1" || text === "yes")
                    return true
            } catch (e) {}
        }

        return false
    }

    function widgetSaysMultiple(columnIndex) {
        var info = batchWidgetInfo(columnIndex)
        var type = String(info.type || "").toLowerCase()
        var cfg = info.config || ({})

        return type === "valuerelation" &&
               batchConfigBoolean(cfg, ["AllowMulti", "allowMulti", "Multi", "multi",
                                        "Multiple", "multiple"])
    }

    function aliasSuggestsMultiple(columnIndex) {
        if (columnIndex < 0 || columnIndex >= columns.length) return false
        var col = columns[columnIndex]
        var label = String((col.alias || col.fieldName || "")).toLowerCase()

        // Fallback utile dans les projets où l'API QML ne restitue pas
        // complètement editorWidgetSetup(). Ce n'est jamais le seul critère.
        return label.indexOf("(multiples)") >= 0 ||
               label.indexOf("(multiple)") >= 0 ||
               label.indexOf(" multiples") >= 0
    }

    function fieldIsValueRelation(columnIndex) {
        if (columnIndex < 0 || columnIndex >= columns.length)
            return false
        var info = batchWidgetInfo(columnIndex)
        return String(info.type || "").toLowerCase() === "valuerelation"
    }

    function refreshBatchRelationType() {
        batchIsValueRelation = fieldIsValueRelation(batchFieldColumn)
        batchIsMultiValueRelation =
                batchIsValueRelation && fieldLooksMultiple(batchFieldColumn)
    }

    function fieldLooksMultiple(columnIndex) {
        if (columnIndex < 0 || columnIndex >= columns.length) return false

        // 1. Configuration du widget : fiable même si toutes les valeurs
        // sélectionnées sont actuellement vides.
        if (widgetSaysMultiple(columnIndex))
            return true

        // 2. Indice fourni par l'alias du projet, utilisé comme fallback
        // lorsque QField n'expose pas toute la configuration du widget.
        if (aliasSuggestsMultiple(columnIndex))
            return true

        // 3. Dernier recours : regarder la forme réellement stockée.
        var rows = selectedBatchRows()
        if (rows.length === 0) rows = filteredRows

        var inspected = Math.min(rows.length, 100)
        for (var i = 0; i < inspected; ++i) {
            var raw = String(rawAttributeForRow(rows[i], columnIndex) || "").trim()
            if (raw.charAt(0) === "{" && raw.charAt(raw.length - 1) === "}")
                return true
        }

        return false
    }

    function rebuildBatchFieldItems() {
        var result = []

        // L'utilisateur choisit uniquement parmi les colonnes réellement
        // visibles dans la table, et dans le même ordre d'affichage.
        for (var p = 0; p < displayedColumns.length; ++p) {
            var displayed = displayedColumns[p]
            if (!displayed) continue

            var originalIndex = Number(displayed.originalIndex)
            var col = columns[originalIndex]
            if (!col || col.technicalHidden === true) continue
            if (columnVisibility[String(originalIndex)] === false) continue

            result.push({
                "columnIndex": originalIndex,
                "label": col.alias || col.fieldName || qsTr("Champ"),
                "fieldName": col.fieldName || ""
            })
        }

        batchFieldItems = result
    }

    function batchConfigString(config, names) {
        if (!config) return ""
        for (var i = 0; i < names.length; ++i) {
            try {
                var value = config[names[i]]
                if (value !== undefined && value !== null && String(value).length > 0)
                    return String(value)
            } catch (e) {}
        }
        return ""
    }

    function normalizeLayerSource(value) {
        var s = String(value === undefined || value === null ? "" : value).trim()
        if (s.length === 0) return ""

        // QGIS may serialize absolute paths in the project while QField loads
        // the packaged copy using another base directory. Compare the provider
        // suffix and filename/layername conservatively.
        s = s.replace(/\\/g, "/")
        return s
    }

    function layerSourceText(layer) {
        if (!layer) return ""

        var candidates = []

        try {
            if (typeof layer.source === "function")
                candidates.push(String(layer.source() || ""))
            else if (layer.source !== undefined)
                candidates.push(String(layer.source || ""))
        } catch (e1) {}

        try {
            if (typeof layer.dataSource === "function")
                candidates.push(String(layer.dataSource() || ""))
            else if (layer.dataSource !== undefined)
                candidates.push(String(layer.dataSource || ""))
        } catch (e2) {}

        try {
            if (layer.provider && typeof layer.provider.dataSourceUri === "function")
                candidates.push(String(layer.provider.dataSourceUri() || ""))
        } catch (e3) {}

        for (var i = 0; i < candidates.length; ++i)
            if (candidates[i].length > 0)
                return normalizeLayerSource(candidates[i])

        return ""
    }

    function sourceTail(value) {
        var s = normalizeLayerSource(value)
        if (s.length === 0) return ""

        // Preserve the provider suffix, especially |layername=...
        var pipe = s.indexOf("|")
        var providerSuffix = pipe >= 0 ? s.substring(pipe) : ""
        var pathPart = pipe >= 0 ? s.substring(0, pipe) : s
        var slash = pathPart.lastIndexOf("/")
        var fileName = slash >= 0 ? pathPart.substring(slash + 1) : pathPart

        return fileName + providerSuffix
    }

    function layerMatchesSource(layer, wantedSource) {
        var wanted = normalizeLayerSource(wantedSource)
        if (wanted.length === 0 || !layer) return false

        var actual = layerSourceText(layer)
        if (actual.length === 0) return false

        if (actual === wanted) return true

        // Packaged QField projects usually change only the directory path.
        var wantedTail = sourceTail(wanted)
        var actualTail = sourceTail(actual)
        if (wantedTail.length > 0 && actualTail.length > 0 &&
                wantedTail === actualTail)
            return true

        // Last-resort comparison on layername suffix.
        var wantedLayername = ""
        var actualLayername = ""
        var wm = /\|layername=([^|]+)/i.exec(wanted)
        var am = /\|layername=([^|]+)/i.exec(actual)
        if (wm) wantedLayername = String(wm[1])
        if (am) actualLayername = String(am[1])

        return wantedLayername.length > 0 &&
               actualLayername.length > 0 &&
               wantedLayername === actualLayername
    }

    function allProjectVectorLayers() {
        var result = []
        var seen = ({})

        function addLayer(layer) {
            if (!layer) return

            var id = layerId(layer)
            var name = layerName(layer)
            var source = layerSourceText(layer)
            var key = id.length > 0 ? id : name + "|" + source

            if (seen[key]) return
            seen[key] = true
            result.push(layer)
        }

        // Source principale : API officielle QField prévue pour QML.
        // ProjectUtils.mapLayers() retourne une QVariantMap QML-compatible
        // de toutes les couches enregistrées par ID.
        try {
            var projectLayers = ProjectUtils.mapLayers(qgisProject)
            if (projectLayers) {
                for (var key in projectLayers)
                    addLayer(projectLayers[key])
            }
        } catch (e1) {
            console.log("QField Table v0.12.10 ProjectUtils.mapLayers: " + e1)
        }

        // Complément : garder les couches déjà exposées par le plugin.
        for (var i = 0; i < vectorLayers.length; ++i)
            addLayer(vectorLayers[i])

        return result
    }

    function findProjectVectorLayerById(idValue) {
        // Compatibility wrapper kept for older calls.
        var resolved = resolveProjectVectorLayer(idValue, "", "")
        return resolved.layer
    }

    function resolveProjectVectorLayer(layerIdValue, layerNameValue, layerSourceValue) {
        var wantedId = String(layerIdValue || "")
        var wantedName = String(layerNameValue || "")
        var wantedSource = normalizeLayerSource(layerSourceValue)

        // 0. Direct QVariantMap lookup through QField's QML-compatible helper.
        if (wantedId.length > 0) {
            try {
                var directLayers = ProjectUtils.mapLayers(qgisProject)
                if (directLayers && directLayers[wantedId])
                    return {
                        "layer": directLayers[wantedId],
                        "method": "ProjectUtils.mapLayers — Layer ID"
                    }
            } catch (e0) {
                console.log("QField Table v0.12.10 direct layer lookup: " + e0)
            }
        }

        var layers = allProjectVectorLayers()

        // 1. Exact layer ID.
        if (wantedId.length > 0) {
            for (var i = 0; i < layers.length; ++i) {
                if (layerId(layers[i]) === wantedId)
                    return {
                        "layer": layers[i],
                        "method": "ProjectUtils — Layer ID"
                    }
            }
        }

        // 2. Exact LayerName.
        if (wantedName.length > 0) {
            var nameMatches = []
            for (var j = 0; j < layers.length; ++j) {
                if (layerName(layers[j]) === wantedName)
                    nameMatches.push(layers[j])
            }

            if (nameMatches.length === 1)
                return {
                    "layer": nameMatches[0],
                    "method": "ProjectUtils — LayerName"
                }

            if (nameMatches.length > 1 && wantedSource.length > 0) {
                for (var k = 0; k < nameMatches.length; ++k) {
                    if (layerMatchesSource(nameMatches[k], wantedSource))
                        return {
                            "layer": nameMatches[k],
                            "method": "ProjectUtils — LayerName + LayerSource"
                        }
                }
            }
        }

        // 3. Data source URI.
        if (wantedSource.length > 0) {
            for (var s = 0; s < layers.length; ++s) {
                if (layerMatchesSource(layers[s], wantedSource))
                    return {
                        "layer": layers[s],
                        "method": "ProjectUtils — LayerSource"
                    }
            }
        }

        // 4. Tolerate a visible name serialized in the Layer option.
        if (wantedId.length > 0) {
            for (var n = 0; n < layers.length; ++n) {
                if (layerName(layers[n]) === wantedId)
                    return {
                        "layer": layers[n],
                        "method": "ProjectUtils — Layer as name"
                    }
            }
        }

        return { "layer": null, "method": "" }
    }

    function configureBatchRelationSource(columnIndex) {
        batchRelationLayer = null
        batchRelationLayerId = ""
        batchRelationLayerName = ""
        batchRelationLayerSource = ""
        batchRelationResolutionMethod = ""
        batchRelationKeyField = ""
        batchRelationValueField = ""
        batchRelationFilterExpression = ""
        batchRelationDiagnostic = ""

        var info = batchWidgetInfo(columnIndex)
        var cfg = info.config || ({})
        var type = String(info.type || "").toLowerCase()

        if (type !== "valuerelation") {
            batchRelationDiagnostic =
                projectConfigDiagnostic.length > 0
                ? projectConfigDiagnostic
                : qsTr("Widget détecté : %1 — aucune ValueRelation exploitable.")
                  .arg(info.type || qsTr("non exposé"))
            return false
        }

        batchRelationLayerId =
            batchConfigString(cfg, ["Layer", "layer", "LayerId", "layerId"])
        batchRelationLayerName =
            batchConfigString(cfg, ["LayerName", "layerName"])
        batchRelationLayerSource =
            batchConfigString(cfg, ["LayerSource", "layerSource", "Source", "source"])
        batchRelationKeyField =
            batchConfigString(cfg, ["Key", "key", "KeyField", "keyField"])
        batchRelationValueField =
            batchConfigString(cfg, ["Value", "value", "ValueField", "valueField"])
        batchRelationFilterExpression =
            batchConfigString(cfg, ["FilterExpression", "filterExpression", "Filter", "filter"])

        var resolved = resolveProjectVectorLayer(
            batchRelationLayerId,
            batchRelationLayerName,
            batchRelationLayerSource
        )

        batchRelationLayer = resolved.layer
        batchRelationResolutionMethod = resolved.method

        var valid = batchRelationLayer !== null &&
                    batchRelationKeyField.length > 0 &&
                    batchRelationValueField.length > 0

        if (valid) {
            batchRelationDiagnostic =
                qsTr("ValueRelation : %1 → clé %2 → titre %3 — couche résolue par %4%5")
                .arg(layerName(batchRelationLayer))
                .arg(batchRelationKeyField)
                .arg(batchRelationValueField)
                .arg(batchRelationResolutionMethod)
                .arg(batchRelationFilterExpression.length > 0
                     ? qsTr(" — filtre : %1").arg(batchRelationFilterExpression)
                     : "")
        } else {
            var loadedNames = []
            var layers = allProjectVectorLayers()
            for (var i = 0; i < Math.min(layers.length, 40); ++i)
                loadedNames.push(layerName(layers[i]) + " [" + layerId(layers[i]) + "]")

            batchRelationDiagnostic =
                qsTr("ValueRelation lue, mais couche non résolue via ProjectUtils. Layer=%1 ; LayerName=%2 ; LayerSource=%3 ; clé=%4 ; titre=%5. Couches du projet visibles en QML : %6")
                .arg(batchRelationLayerId)
                .arg(batchRelationLayerName)
                .arg(sourceTail(batchRelationLayerSource))
                .arg(batchRelationKeyField)
                .arg(batchRelationValueField)
                .arg(loadedNames.join(", "))
        }

        return valid
    }

    function registerBatchRelationOption(rawValue, displayValue) {
        var raw = String(rawValue === undefined || rawValue === null ? "" : rawValue)
        if (raw.length === 0) return

        var label = String(displayValue === undefined || displayValue === null ? "" : displayValue)
        if (label.length === 0) label = raw

        var next = batchRelationItems.slice(0)
        for (var i = 0; i < next.length; ++i) {
            if (String(next[i].rawValue) === raw) return
        }
        next.push({"rawValue": raw, "label": label})
        next.sort(function(a,b) { return String(a.label).localeCompare(String(b.label)) })
        batchRelationItems = next
        batchRelationModelCount = next.length
        Qt.callLater(function() {
            if (plugin.batchRelationItems.length > 0 &&
                batchRelationCombo.currentIndex < 0) {
                batchRelationCombo.currentIndex = 0
                batchRelationCombo.synchronizeRawValue()
            }
        })
    }

    function relationFeatureAttribute(feature, fieldName) {
        if (!feature || String(fieldName || "").length === 0)
            return ""

        try {
            var value = feature.attribute(fieldName)
            return value === undefined || value === null ? "" : String(value)
        } catch (e1) {}

        return ""
    }

    function loadBatchRelationItemsWithIterator() {
        batchRelationItems = []
        batchRelationModelCount = 0
        batchRelationLoadingMethod = "LayerUtils.FeatureIterator"
        batchRelationIteratorError = ""

        if (!batchRelationLayer ||
            batchRelationKeyField.length === 0 ||
            batchRelationValueField.length === 0) {
            batchRelationIteratorError =
                qsTr("Couche, clé ou champ d'affichage relationnel manquant.")
            return false
        }

        var iterator = null
        var result = []
        var seen = ({})

        try {
            if (batchRelationFilterExpression.length > 0) {
                iterator = LayerUtils.createFeatureIteratorFromExpression(
                    batchRelationLayer,
                    batchRelationFilterExpression
                )
            } else {
                iterator = LayerUtils.createFeatureIterator(batchRelationLayer)
            }

            if (!iterator) {
                batchRelationIteratorError =
                    qsTr("LayerUtils n'a pas retourné d'itérateur.")
                return false
            }

            var safety = 0
            while (iterator.hasNext()) {
                var feature = iterator.next()
                safety++

                if (safety > 100000) {
                    batchRelationIteratorError =
                        qsTr("Lecture interrompue après 100 000 entités.")
                    break
                }

                var raw = relationFeatureAttribute(
                    feature,
                    batchRelationKeyField
                )
                var label = relationFeatureAttribute(
                    feature,
                    batchRelationValueField
                )

                if (raw.length === 0)
                    continue

                if (seen[raw] === true)
                    continue

                seen[raw] = true

                result.push({
                    "rawValue": raw,
                    "label": label.length > 0 ? label : raw
                })
            }
        } catch (e) {
            batchRelationIteratorError = String(e)
            console.log(
                "QField Table v0.12.10 relation iterator: " + e
            )
        } finally {
            try {
                if (iterator)
                    iterator.close()
            } catch (closeError) {}
        }

        result.sort(function(a, b) {
            return String(a.label).localeCompare(String(b.label))
        })

        batchRelationItems = result
        batchRelationModelCount = result.length

        Qt.callLater(function() {
            if (plugin.batchRelationItems.length > 0) {
                batchRelationCombo.currentIndex = 0
                batchRelationCombo.synchronizeRawValue()
            } else {
                batchRelationCombo.currentIndex = -1
                plugin.batchRelationRawValue = ""
            }
        })

        return result.length > 0
    }

    function rebuildBatchRelationItems(columnIndex) {
        batchRelationItems = []
        batchRelationModelCount = 0
        batchRelationLoadingMethod = ""
        batchRelationIteratorError = ""

        if (configureBatchRelationSource(columnIndex)) {
            var loaded = loadBatchRelationItemsWithIterator()

            // The relation itself was correctly resolved even if the filter
            // legitimately returns zero values. Do not fall back to unrelated
            // keys already stored in the main table.
            if (!loaded && batchRelationIteratorError.length > 0) {
                batchRelationDiagnostic =
                    batchRelationDiagnostic +
                    qsTr(" — erreur de lecture : %1")
                    .arg(batchRelationIteratorError)
            }

            return
        }

        // Fallback only when no ValueRelation configuration can be resolved.
        // This preserves support for other custom multiple-value widgets.
        batchRelationLoadingMethod = "Valeurs déjà rencontrées"

        var seen = ({})
        var result = []

        for (var r = 0; r < flatRows.length; ++r) {
            var row = flatRows[r]
            var tokens =
                parseStoredCollection(rawAttributeForRow(row, columnIndex))

            for (var t = 0; t < tokens.length; ++t) {
                var rawToken = String(tokens[t])

                if (!seen[rawToken]) {
                    seen[rawToken] = true
                    result.push({
                        "rawValue": rawToken,
                        "label": rawToken
                    })
                }
            }
        }

        result.sort(function(a, b) {
            return String(a.label).localeCompare(String(b.label))
        })

        batchRelationItems = result
        batchRelationModelCount = result.length

        Qt.callLater(function() {
            if (plugin.batchRelationItems.length > 0) {
                batchRelationCombo.currentIndex = 0
                batchRelationCombo.synchronizeRawValue()
            }
        })
    }

    function relationLabelForRaw(rawValue) {
        var raw = String(rawValue === undefined || rawValue === null ? "" : rawValue)
        for (var i = 0; i < batchRelationItems.length; ++i) {
            if (String(batchRelationItems[i].rawValue) === raw)
                return String(batchRelationItems[i].label)
        }
        return raw
    }

    function displayedCollectionFromRaw(rawValue) {
        var tokens = parseStoredCollection(rawValue)
        var labels = []
        for (var i = 0; i < tokens.length; ++i)
            labels.push(relationLabelForRaw(tokens[i]))
        return labels.join("; ")
    }

    function findBatchJournalLayer() {
        var layers = []

        try {
            var projectLayers = ProjectUtils.mapLayers(qgisProject)
            if (projectLayers) {
                for (var key in projectLayers)
                    layers.push(projectLayers[key])
            }
        } catch (e1) {}

        // Fallback on the plugin's discovered layers.
        for (var i = 0; i < vectorLayers.length; ++i)
            layers.push(vectorLayers[i])

        for (var j = 0; j < layers.length; ++j) {
            if (layerName(layers[j]) === batchJournalLayerName)
                return layers[j]
        }

        return null
    }

    function journalFeatureAttribute(feature, fieldName) {
        if (!feature) return ""
        try {
            var value = feature.attribute(fieldName)
            return value === undefined || value === null ? "" : String(value)
        } catch (e) {
            return ""
        }
    }

    function loadBatchJournalFromLayer() {
        batchJournalLayer = findBatchJournalLayer()

        if (!batchJournalLayer)
            return false

        var entries = []
        var iterator = null

        try {
            iterator = LayerUtils.createFeatureIterator(batchJournalLayer)

            if (!iterator)
                return false

            while (iterator.hasNext()) {
                var f = iterator.next()

                entries.push({
                    "uuid": journalFeatureAttribute(f, "journal_uuid"),
                    "user": journalFeatureAttribute(f, "utilisateur"),
                    "timestamp": journalFeatureAttribute(f, "date_heure"),
                    "layer": journalFeatureAttribute(f, "couche"),
                    "featureId": journalFeatureAttribute(f, "id_entite"),
                    "field": journalFeatureAttribute(f, "champ"),
                    "fieldLabel": journalFeatureAttribute(f, "champ_titre"),
                    "operation": journalFeatureAttribute(f, "operation"),
                    "oldDisplay": journalFeatureAttribute(f, "avant"),
                    "newDisplay": journalFeatureAttribute(f, "apres"),
                    "oldRaw": journalFeatureAttribute(f, "brut_avant"),
                    "newRaw": journalFeatureAttribute(f, "brut_apres"),
                    "success": journalFeatureAttribute(f, "statut").toUpperCase() === "OK",
                    "note": journalFeatureAttribute(f, "note")
                })
            }
        } catch (e) {
            batchJournalPersistenceError =
                qsTr("Lecture de qfield_table_journal impossible : %1").arg(String(e))
            return false
        } finally {
            try {
                if (iterator)
                    iterator.close()
            } catch (closeError) {}
        }

        // Keep a predictable chronological display.
        entries.sort(function(a, b) {
            return String(a.timestamp).localeCompare(String(b.timestamp))
        })

        batchJournal = entries
        batchJournalBackend = "geopackage"
        batchJournalPersistenceError = ""
        return true
    }

    function writeBatchJournalEntryToLayer(entry) {
        if (!batchJournalLayer)
            batchJournalLayer = findBatchJournalLayer()

        if (!batchJournalLayer)
            return false

        try {
            var f = FeatureUtils.createFeature(batchJournalLayer)

            // Champs historiques obligatoires (structure v0.9.2).
            var requiredValues = {
                "date_heure": String(entry.timestamp || ""),
                "couche": String(entry.layer || ""),
                "id_entite": String(entry.featureId || ""),
                "champ": String(entry.field || ""),
                "champ_titre": String(entry.fieldLabel || ""),
                "operation": String(entry.operation || ""),
                "avant": String(entry.oldDisplay || ""),
                "apres": String(entry.newDisplay || ""),
                "brut_avant": String(entry.oldRaw || ""),
                "brut_apres": String(entry.newRaw || ""),
                "statut": entry.success === true ? "OK" : "ERREUR",
                "note": String(entry.note || "")
            }

            for (var fieldName in requiredValues) {
                if (!f.setAttribute(fieldName, requiredValues[fieldName])) {
                    batchJournalPersistenceError =
                        qsTr("Le champ « %1 » est absent de qfield_table_journal.")
                        .arg(fieldName)
                    return false
                }
            }

            // v0.12.10 : champs optionnels. Un ancien journal continue de
            // fonctionner, mais le script de migration active ces données.
            try { f.setAttribute("journal_uuid", String(entry.uuid || "")) } catch (uuidError) {}
            try { f.setAttribute("utilisateur", String(entry.user || "")) } catch (userError) {}

            journalSaveModel.currentLayer = batchJournalLayer
            journalSaveModel.feature = f
            journalSaveModel.updateAttributesFromFeature(f)

            if (!journalSaveModel.create(true)) {
                batchJournalPersistenceError =
                    qsTr("QField n'a pas pu créer l'entrée dans qfield_table_journal.")
                return false
            }

            batchJournalBackend = "geopackage"
            batchJournalPersistenceError = ""
            return true

        } catch (e) {
            batchJournalPersistenceError =
                qsTr("Écriture dans qfield_table_journal impossible : %1")
                .arg(String(e))
            return false
        }
    }


    function projectFilePathForJournal() {
        var p = ""
        try {
            if (qgisProject) {
                if (typeof qgisProject.fileName === "function")
                    p = String(qgisProject.fileName() || "")
                else if (qgisProject.fileName !== undefined)
                    p = String(qgisProject.fileName || "")
            }
        } catch (e) {}
        return p
    }

    function resolveBatchJournalFilePath() {
        var projectPath = projectFilePathForJournal()
        if (!projectPath)
            return ""

        var folder = ""
        try { folder = String(FileUtils.absolutePath(projectPath) || "") }
        catch (e) { return "" }

        if (!folder)
            return ""

        var sep = folder.charAt(folder.length - 1) === "/" ||
                  folder.charAt(folder.length - 1) === "\\" ? "" : "/"
        return folder + sep + "qfield_table_journal.json"
    }

    function loadPersistentBatchJournal() {
        batchJournalPersistenceError = ""

        // Preferred backend: a real project table, synchronizable with
        // the GeoPackage/QFieldCloud workflow.
        if (loadBatchJournalFromLayer()) {
            batchJournalFilePath = ""
            return true
        }

        // Fallback: local JSON journal from v0.9.1.
        batchJournalBackend = "json"
        batchJournalFilePath = resolveBatchJournalFilePath()

        if (!batchJournalFilePath)
            return false

        try {
            if (!FileUtils.fileExists(batchJournalFilePath)) {
                batchJournal = []
                return true
            }

            var bytes = FileUtils.readFileContent(batchJournalFilePath)
            var text = String(bytes)

            if (!text || text.trim().length === 0) {
                batchJournal = []
                return true
            }

            var parsed = JSON.parse(text)

            if (parsed && parsed.format === "QFieldTableJournal" &&
                    Array.isArray(parsed.entries)) {
                batchJournal = parsed.entries
                return true
            }

            batchJournalPersistenceError =
                qsTr("Le fichier de journal existe mais son format n'est pas reconnu.")

        } catch (e) {
            batchJournalPersistenceError = String(e)
        }

        return false
    }

    function savePersistentBatchJournal() {
        batchJournalPersistenceError = ""
        if (!batchJournalFilePath)
            batchJournalFilePath = resolveBatchJournalFilePath()

        if (!batchJournalFilePath) {
            batchJournalPersistenceError =
                qsTr("Impossible de déterminer le dossier du projet.")
            return false
        }

        try {
            var payload = {
                "format": "QFieldTableJournal",
                "version": 1,
                "project": FileUtils.fileName(projectFilePathForJournal(), true),
                "updated": journalTimestamp(),
                "entries": batchJournal
            }
            var ok = FileUtils.writeFileContent(
                        batchJournalFilePath,
                        JSON.stringify(payload, null, 2))
            if (!ok) {
                batchJournalPersistenceError =
                    qsTr("QField n'a pas pu écrire le fichier de journal.")
                return false
            }
            return true
        } catch (e) {
            batchJournalPersistenceError = String(e)
            return false
        }
    }

    function journalEntityIdentifier(row) {
        if (!row)
            return ""

        var preferredField = String(batchJournalEntityIdField || "").trim()

        if (preferredField.length > 0 && row.feature) {
            try {
                var value = row.feature.attribute(preferredField)

                if (value !== undefined &&
                    value !== null &&
                    String(value).trim().length > 0) {
                    return String(value)
                }
            } catch (e) {
                // Le champ n'existe pas dans cette couche :
                // utiliser l'identifiant interne comme secours.
            }
        }

        if (row.featureId !== undefined &&
            row.featureId !== null) {
            return String(row.featureId)
        }

        return ""
    }

    function journalUuid() {
        // UUID v4 généré localement : chaque appareil peut créer des lignes
        // hors ligne sans dépendre du fid auto-incrémenté.
        var template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
        return template.replace(/[xy]/g, function(c) {
            var r = Math.floor(Math.random() * 16)
            var v = c === 'x' ? r : ((r & 0x3) | 0x8)
            return v.toString(16)
        })
    }

    function journalCloudUser() {
        try {
            displayExpressionEvaluator.project = qgisProject
            displayExpressionEvaluator.layer = selectedLayer
            displayExpressionEvaluator.expressionText =
                    "coalesce(@cloud_username, @cloud_useremail, '')"

            var value = displayExpressionEvaluator.evaluate()
            if (value !== undefined && value !== null &&
                    String(value).trim().length > 0)
                return String(value).trim()
        } catch (e) {
            console.log('QField Table v0.12.10 cloud user: ' + e)
        }

        return qsTr('Utilisateur local')
    }

    function journalTimestamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
    }

    function appendBatchJournal(row, oldRaw, newRaw, success, note) {
        var col = columns[batchFieldColumn]
        var isMulti = fieldLooksMultiple(batchFieldColumn)
        var isValueMap = batchIsValueMap
        var isValueRelation = batchIsValueRelation

        var entry = {
            "uuid": journalUuid(),
            "user": journalCloudUser(),
            "timestamp": journalTimestamp(),
            "layer": layerName(selectedLayer),
            "featureId": journalEntityIdentifier(row),
            "field": col ? String(col.fieldName || "") : "",
            "fieldLabel": col ? String(col.alias || col.fieldName || "") : "",
            "operation": isValueRelation && !isMulti
                         ? qsTr("Remplacer")
                         : String(batchOperation),
            "oldRaw": String(oldRaw === undefined || oldRaw === null ? "" : oldRaw),
            "newRaw": String(newRaw === undefined || newRaw === null ? "" : newRaw),
            "oldDisplay": isValueMap ? batchValueMapLabel(oldRaw) :
                          (isValueRelation && !isMulti ? relationLabelForRaw(oldRaw) :
                           (isMulti ? displayedCollectionFromRaw(oldRaw) :
                            representedValue(row.feature, col.fieldName, oldRaw))),
            "newDisplay": isValueMap ? batchValueMapLabel(newRaw) :
                          (isValueRelation && !isMulti ? relationLabelForRaw(newRaw) :
                           (isMulti ? displayedCollectionFromRaw(newRaw) :
                            String(newRaw === undefined || newRaw === null ? "" : newRaw))),
            "success": success === true,
            "note": String(note || "")
        }

        var next = batchJournal.slice(0)
        next.push(entry)
        batchJournal = next

        // Preferred persistence: qfield_table_journal.
        if (writeBatchJournalEntryToLayer(entry))
            return

        // Safe fallback when the journal table is not in the project or
        // cannot be edited.
        batchJournalBackend = "json"

        if (!savePersistentBatchJournal())
            console.log("QField Table — journal non sauvegardé : " +
                        batchJournalPersistenceError)
    }


    function batchJournalText() {
        var lines = []
        lines.push("UUID\tUtilisateur\tDate/heure\tCouche\tEntité\tChamp\tOpération\tAvant (affiché)\tAprès (affiché)\tAvant (brut)\tAprès (brut)\tStatut\tNote")
        for (var i = 0; i < batchJournal.length; ++i) {
            var e = batchJournal[i]
            function clean(v) { return String(v === undefined || v === null ? "" : v).replace(/\t/g, " ").replace(/\r?\n/g, " ") }
            lines.push([
                clean(e.uuid), clean(e.user), clean(e.timestamp), clean(e.layer), clean(e.featureId),
                clean(e.fieldLabel), clean(e.operation),
                clean(e.oldDisplay), clean(e.newDisplay),
                clean(e.oldRaw), clean(e.newRaw),
                e.success ? "OK" : "ÉCHEC", clean(e.note)
            ].join("\t"))
        }
        return lines.join("\n")
    }

    function batchJournalCsvText() {
        function esc(v) {
            var s = String(v === undefined || v === null ? "" : v)
            return "\"" + s.replace(/"/g, "\"\"") + "\""
        }
        var rows = [["UUID","Utilisateur","Date/heure","Couche","Entité","Champ","Opération",
                     "Avant affiché","Après affiché","Avant brut","Après brut","Statut","Note"]]
        for (var i=0; i<batchJournal.length; ++i) {
            var e=batchJournal[i]
            rows.push([e.uuid||"",e.user||"",e.timestamp,e.layer,e.featureId,e.fieldLabel,e.operation,
                       e.oldDisplay,e.newDisplay,e.oldRaw,e.newRaw,
                       e.success ? "OK" : "ERREUR",e.note])
        }
        return rows.map(function(r){ return r.map(esc).join(";") }).join("\n")
    }

    function copyBatchJournalCsv() {
        var text=batchJournalCsvText()
        try {
            if (Qt.application && Qt.application.clipboard) {
                if (typeof Qt.application.clipboard.setText === "function")
                    Qt.application.clipboard.setText(text)
                else
                    Qt.application.clipboard.text=text
            }
        } catch(e) {}
    }

    function copyBatchJournal() {
        var text = batchJournalText()
        try {
            if (Qt.application && Qt.application.clipboard) {
                if (typeof Qt.application.clipboard.setText === "function")
                    Qt.application.clipboard.setText(text)
                else
                    Qt.application.clipboard.text = text
                return
            }
        } catch (e1) {}
        try {
            if (mainWindow && typeof mainWindow.copyToClipboard === "function")
                mainWindow.copyToClipboard(text)
        } catch (e2) {}
    }

    function openCreateRelationDialog() {
        if (!batchRelationLayer || batchRelationKeyField.length === 0 ||
                batchRelationValueField.length === 0) {
            diagnosticMessage = qsTr("La table liée ou ses champs clé/libellé ne peuvent pas être déterminés.")
            return
        }
        batchNewRelationKey = ""
        batchNewRelationLabel = ""
        createRelationDialog.open()
    }

    function createRelationEntry() {
        var key = String(batchNewRelationKey || "").trim()
        var label = String(batchNewRelationLabel || "").trim()
        if (!batchRelationLayer || key.length === 0 || label.length === 0) return

        try {
            var f = FeatureUtils.createFeature(batchRelationLayer)
            if (!f.setAttribute(batchRelationKeyField, key) ||
                    !f.setAttribute(batchRelationValueField, label)) {
                diagnosticMessage = qsTr("Impossible de préparer la nouvelle valeur relationnelle.")
                return
            }

            relationCreateModel.currentLayer = batchRelationLayer
            relationCreateModel.feature = f
            relationCreateModel.updateAttributesFromFeature(f)

            if (relationCreateModel.create(true)) {
                createRelationDialog.close()
                registerBatchRelationOption(key, label)
                batchRelationRawValue = key
                batchRelationCombo.currentIndex = batchRelationModel.findKey(key)
                diagnosticMessage = ""
            } else {
                diagnosticMessage = qsTr("La nouvelle entrée n'a pas pu être créée. Vérifiez les contraintes de la table liée.")
            }
        } catch (e) {
            diagnosticMessage = qsTr("Création de la valeur relationnelle impossible : %1").arg(e)
        }
    }

    function openBatchEditDialog() {
        if (batchSelectionCount() === 0) {
            diagnosticMessage = qsTr("Sélectionnez au moins un enregistrement avant la modification en lot.")
            return
        }
        rebuildBatchFieldItems()
        batchFieldColumn = batchFieldItems.length > 0 ? Number(batchFieldItems[0].columnIndex) : -1
        batchOperation = "replace"
        batchValueText = ""
        batchRelationRawValue = ""
        batchRelationItems = []
        refreshBatchValueMap()
        if (batchFieldColumn >= 0 && batchIsValueRelation)
            rebuildBatchRelationItems(batchFieldColumn)
        batchEditDialog.open()
    }

    function batchFieldChanged(itemIndex) {
        if (itemIndex < 0 || itemIndex >= batchFieldItems.length) return

        batchFieldColumn = Number(batchFieldItems[itemIndex].columnIndex)
        batchValueText = ""
        batchRelationRawValue = ""
        batchRelationItems = []
        batchRelationDiagnostic = ""
        refreshBatchValueMap()
        batchOperation = batchIsMultiValueRelation ? "add" : "replace"

        Qt.callLater(function() {
            plugin.refreshBatchRelationType()
            if (plugin.batchIsValueRelation)
                plugin.rebuildBatchRelationItems(plugin.batchFieldColumn)
            else
                plugin.batchRelationItems = []
        })
    }

    function batchNewRawValue(row) {
        if (batchFieldColumn < 0 || batchFieldColumn >= columns.length) return null

        // ValueRelation unique : écrire directement la clé choisie.
        if (batchIsValueRelation && !batchIsMultiValueRelation) {
            var uniqueChosen =
                    String(batchRelationRawValue || batchValueText || "").trim()
            return uniqueChosen.length > 0 ? uniqueChosen : null
        }

        // Champ simple ou ValueMap.
        if (!fieldLooksMultiple(batchFieldColumn))
            return batchValueText

        var chosen = String(batchRelationRawValue || batchValueText || "").trim()
        if (chosen.length === 0) return null
        var existing = parseStoredCollection(rawAttributeForRow(row, batchFieldColumn))

        if (batchOperation === "add") {
            if (!collectionContains(existing, chosen)) existing.push(chosen)
            return serializeStoredCollection(existing)
        }

        if (batchOperation === "remove") {
            var remaining = []
            for (var i = 0; i < existing.length; ++i)
                if (String(existing[i]) !== chosen) remaining.push(existing[i])
            return serializeStoredCollection(remaining)
        }

        return serializeStoredCollection([chosen])
    }

    function executeBatchEdit() {
        var rows = selectedBatchRows()
        if (rows.length === 0 || batchFieldColumn < 0) return

        batchSuccessCount = 0
        batchFailedIds = []
        batchInProgress = true
        var fieldName = columns[batchFieldColumn].fieldName

        for (var i = 0; i < rows.length; ++i) {
            var row = rows[i]
            var oldRawValue = rawAttributeForRow(row, batchFieldColumn)
            var newValue = batchNewRawValue(row)

            if (newValue === null || newValue === undefined) {
                batchFailedIds.push(String(row.featureId))
                appendBatchJournal(row, oldRawValue, newValue, false, qsTr("Nouvelle valeur invalide"))
                continue
            }

            try {
                if (String(oldRawValue) === String(newValue)) {
                    batchSuccessCount++
                    appendBatchJournal(row, oldRawValue, newValue, true, qsTr("Déjà conforme — aucune écriture"))
                    continue
                }

                batchSaveModel.currentLayer = selectedLayer
                batchSaveModel.feature = row.feature

                var edited = batchSaveModel.feature
                var setOk = edited.setAttribute(fieldName, newValue)
                if (!setOk) {
                    batchFailedIds.push(String(row.featureId))
                    appendBatchJournal(row, oldRawValue, newValue, false, qsTr("setAttribute() refusé"))
                    continue
                }

                if (!batchSaveModel.updateAttributesFromFeature(edited)) {
                    batchFailedIds.push(String(row.featureId))
                    appendBatchJournal(row, oldRawValue, newValue, false, qsTr("Attribut non transféré au FeatureModel"))
                    continue
                }

                if (batchSaveModel.save(true)) {
                    batchSuccessCount++
                    appendBatchJournal(row, oldRawValue, newValue, true, "")
                } else {
                    batchFailedIds.push(String(row.featureId))
                    appendBatchJournal(row, oldRawValue, newValue, false, qsTr("Échec de sauvegarde"))
                }
            } catch (e) {
                console.log("QField Table v0.12.10 batch feature " + row.featureId + ": " + e)
                batchFailedIds.push(String(row.featureId))
                appendBatchJournal(row, oldRawValue, newValue, false, String(e))
            }
        }

        batchInProgress = false
        batchConfirmDialog.close()
        batchEditDialog.close()
        reloadFeaturesOnly()
        batchResultDialog.open()
    }

    function buildRows() {
        if (columns.length === 0 || previewFeatures.length === 0) return
        // v0.12.10 : la construction initiale ne lit plus chaque attribut de
        // chaque entité. On conserve l’objet QgsFeature et un cache vide;
        // rowValue() lira ensuite uniquement les colonnes réellement utilisées.
        var result = []
        for (var r = 0; r < previewFeatures.length; ++r) {
            var feature = previewFeatures[r]
            result.push({ "featureId": featureId(feature), "feature": feature, "values": [] })
        }
        optimizeColumnWidths(result)
        horizontalOffset = 0
        flatRows = result
        applyView()
        diagnosticMessage = ""
    }

    function frozenWidth() {
        var total = 126
        var count = Math.min(frozenColumnCount, displayedColumns.length)
        for (var i = 0; i < count; ++i) total += displayedColumns[i].width
        return total
    }

    function scrollingWidth() {
        var total = 0
        for (var i = Math.min(frozenColumnCount, displayedColumns.length); i < displayedColumns.length; ++i)
            total += displayedColumns[i].width
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
        var value = rowValue(row, filterColumn)
        var text = String(value === undefined || value === null ? "" : value)
        var needle = String(filterText || "").toLowerCase().trim()

        if (filterMode === "values") {
            var key = distinctKey(value)
            return selectedDistinctKeys[key] === true
        }
        if (filterMode === "empty") return valueIsEmpty(value)
        if (filterMode === "notempty") return !valueIsEmpty(value)
        if (filterMode === "equals") return text.toLowerCase() === needle
        if (needle.length === 0) return true
        return text.toLowerCase().indexOf(needle) >= 0
    }

    function distinctKey(value) {
        return valueIsEmpty(value) ? "__QFIELD_TABLE_EMPTY__" : String(value)
    }

    function distinctLabel(value) {
        return valueIsEmpty(value) ? qsTr("(valeur vide)") : String(value)
    }

    function rebuildDistinctValues() {
        if (filterColumn < 0 || filterColumn >= columns.length) {
            distinctValues = []
            visibleDistinctValues = []
            selectedDistinctKeys = ({})
            return
        }
        var counts = ({})
        var originals = ({})
        for (var i = 0; i < flatRows.length; ++i) {
            var value = rowValue(flatRows[i], filterColumn)
            var key = distinctKey(value)
            counts[key] = (counts[key] || 0) + 1
            originals[key] = value
        }
        var result = []
        var selection = ({})
        for (var key in counts) {
            result.push({
                "key": key,
                "value": originals[key],
                "label": distinctLabel(originals[key]),
                "count": counts[key],
                "checked": true
            })
            selection[key] = true
        }
        result.sort(function(a, b) {
            if (a.count !== b.count) return b.count - a.count
            return String(a.label).localeCompare(String(b.label), Qt.locale(), Locale.CompareCaseInsensitive)
        })
        distinctValues = result
        selectedDistinctKeys = selection
        filterDistinctList()
    }

    function filterDistinctList() {
        var needle = String(distinctSearchText || "").toLowerCase().trim()
        var result = []
        for (var i = 0; i < distinctValues.length; ++i) {
            var item = distinctValues[i]
            if (needle.length === 0 || String(item.label).toLowerCase().indexOf(needle) >= 0)
                result.push(item)
        }
        visibleDistinctValues = result
    }

    function setDistinctChecked(key, checked) {
        var selection = ({})
        for (var current in selectedDistinctKeys) selection[current] = selectedDistinctKeys[current]
        selection[key] = checked
        selectedDistinctKeys = selection
        var updated = []
        for (var i = 0; i < distinctValues.length; ++i) {
            var item = distinctValues[i]
            updated.push({
                "key": item.key, "value": item.value, "label": item.label,
                "count": item.count, "checked": selection[item.key] === true
            })
        }
        distinctValues = updated
        filterDistinctList()
        applyView()
    }

    function setAllDistinctChecked(checked) {
        var selection = ({})
        var updated = []
        for (var i = 0; i < distinctValues.length; ++i) {
            var item = distinctValues[i]
            selection[item.key] = checked
            updated.push({
                "key": item.key, "value": item.value, "label": item.label,
                "count": item.count, "checked": checked
            })
        }
        selectedDistinctKeys = selection
        distinctValues = updated
        filterDistinctList()
        applyView()
    }

    function selectedDistinctCount() {
        var count = 0
        for (var key in selectedDistinctKeys) if (selectedDistinctKeys[key] === true) count++
        return count
    }

    function cloneSelection(source) {
        var copy = ({})
        for (var key in source) copy[key] = source[key] === true
        return copy
    }

    function pendingDistinctCount() {
        var count = 0
        for (var key in pendingDistinctKeys) if (pendingDistinctKeys[key] === true) count++
        return count
    }

    function pendingResultCount() {
        if (filterColumn < 0 || filterColumn >= columns.length) return flatRows.length
        var term = searchField ? String(searchField.text).toLowerCase().trim() : ""
        var count = 0
        for (var r = 0; r < flatRows.length; ++r) {
            var row = flatRows[r]
            var globalMatch = term.length === 0 || String(row.featureId).toLowerCase().indexOf(term) >= 0
            if (!globalMatch) {
                for (var c = 0; c < columns.length; ++c) {
                    if (String(rowValue(row, c)).toLowerCase().indexOf(term) >= 0) { globalMatch = true; break }
                }
            }
            if (globalMatch && pendingDistinctKeys[distinctKey(rowValue(row, filterColumn))] === true) count++
        }
        return count
    }

    function updatePendingDistinct(key, checked) {
        var copy = cloneSelection(pendingDistinctKeys)
        copy[key] = checked
        pendingDistinctKeys = copy
    }

    function setAllPendingDistinct(checked) {
        var copy = ({})
        for (var i = 0; i < distinctValues.length; ++i) copy[distinctValues[i].key] = checked
        pendingDistinctKeys = copy
    }

    function invertPendingDistinct() {
        var copy = ({})
        for (var i = 0; i < distinctValues.length; ++i) {
            var key = distinctValues[i].key
            copy[key] = pendingDistinctKeys[key] !== true
        }
        pendingDistinctKeys = copy
    }

    function applyPendingDistinct() {
        selectedDistinctKeys = cloneSelection(pendingDistinctKeys)
        var updated = []
        for (var i = 0; i < distinctValues.length; ++i) {
            var item = distinctValues[i]
            updated.push({
                "key": item.key, "value": item.value, "label": item.label,
                "count": item.count, "checked": selectedDistinctKeys[item.key] === true
            })
        }
        distinctValues = updated
        filterDistinctList()
        storeCurrentColumnFilter()
        applyView()
        distinctFilterDialog.close()
    }

    function cancelPendingDistinct() {
        pendingDistinctKeys = cloneSelection(selectedDistinctKeys)
        distinctFilterDialog.close()
    }

    function openDistinctFilter() {
        if (filterColumn < 0 || filterColumn >= columns.length) return
        filterMode = "values"
        distinctSearchText = ""
        rebuildDistinctValues()
        pendingDistinctKeys = cloneSelection(selectedDistinctKeys)
        distinctFilterDialog.open()
    }

    function reopenDistinctFilter() {
        pendingDistinctKeys = cloneSelection(selectedDistinctKeys)
        distinctSearchText = ""
        filterDistinctList()
        distinctFilterDialog.open()
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
                for (var c = 0; c < columns.length; ++c) {
                    if (String(rowValue(row, c)).toLowerCase().indexOf(term) >= 0) {
                        globalMatch = true
                        break
                    }
                }
            }
            if (globalMatch && rowMatchesAllFilters(row)) result.push(row)
        }

        if (sortColumn >= 0 && sortColumn < columns.length) {
            var col = sortColumn
            var asc = sortAscending
            result.sort(function(a, b) {
                var cmp = compareValues(rowValue(a, col), rowValue(b, col))
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

    function featureForId(featureIdValue) {
        var idText = String(featureIdValue || "")
        for (var i = 0; i < flatRows.length; ++i)
            if (String(flatRows[i].featureId) === idText) return flatRows[i].feature
        for (var j = 0; j < previewFeatures.length; ++j)
            if (featureId(previewFeatures[j]) === idText) return previewFeatures[j]
        return null
    }

    function zoomToFeature(featureIdValue) {
        if (!selectedLayer) return false
        var canvas = iface.mapCanvas()
        if (!canvas || !canvas.mapSettings) return false
        var feature = featureForId(featureIdValue)
        if (!feature) {
            diagnosticMessage = qsTr("Impossible de retrouver l’entité %1 pour le zoom.").arg(String(featureIdValue))
            return false
        }
        try {
            // Signature officielle QField : FeatureUtils.extent(mapSettings, layer, feature)
            var extent = FeatureUtils.extent(canvas.mapSettings, selectedLayer, feature)
            canvas.mapSettings.extent = extent
            return true
        } catch (zoomError) {
            diagnosticMessage = qsTr("Impossible de zoomer sur l’entité : %1").arg(String(zoomError))
            console.log("QField Table v0.12.10 zoom: " + zoomError)
            return false
        }
    }

    function performPendingZoom() {
        var idText = String(pendingZoomFeatureId || "")
        pendingZoomFeatureId = ""
        if (idText.length === 0) return
        if (zoomToFeature(idText)) {
            try {
                mainWindow.displayToast(qsTr("Entité %1 sélectionnée et centrée. Touchez-la sur la carte pour ouvrir son formulaire.").arg(idText))
            } catch (toastError) {}
        }
    }

    function handOffToNativeQField(featureIdValue) {
        if (!selectedLayer)
            return

        var idText = String(featureIdValue || selectedFeatureId)
        if (!idText || idText.length === 0)
            return

        var numericId = Number(idText)
        if (isNaN(numericId)) {
            diagnosticMessage =
                    qsTr("Identifiant d’entité invalide : %1").arg(idText)
            return
        }

        var feature = featureForId(idText)
        if (!feature) {
            diagnosticMessage =
                    qsTr("Impossible de retrouver l’entité %1.").arg(idText)
            return
        }

        try {
            LayerUtils.selectFeaturesInLayer(selectedLayer, [numericId])
        } catch (selectionError) {
            console.log("QField Table v0.12.10 sélection : " + selectionError)
        }

        refreshAfterNativeEdit = true
        pendingNativeEditFeature = feature

        // Fermer notre dialogue. Le zoom sera lancé après sa disparition.
        browserDialog.close()
        nativeJumpTimer.restart()
    }

    function jumpToPendingNativeFeature() {
        var feature = pendingNativeEditFeature
        pendingNativeEditFeature = null

        if (!feature || !selectedLayer)
            return

        try {
            var canvas = iface.mapCanvas()
            if (!canvas || !canvas.mapSettings) {
                openNativeFeatureForm(feature)
                return
            }

            // FeatureUtils transforme l'emprise de l'entité vers le CRS de
            // la carte. Le centre de cette emprise devient la destination.
            var extent = FeatureUtils.extent(
                        canvas.mapSettings,
                        selectedLayer,
                        feature)

            var center = extent.center

            // Ne jamais dézoomer. À grande échelle, rapprocher la vue à 1:2000.
            // Si l'utilisateur est déjà plus près, conserver son échelle.
            var currentScale = Number(canvas.mapSettings.scale)
            var targetScale = 2000

            if (!isNaN(currentScale) && currentScale > 0)
                targetScale = Math.min(currentScale, 2000)

            // API native QField. Le callback n'est appelé qu'une fois le
            // déplacement/zoom du canevas terminé.
            canvas.jumpTo(center, targetScale, -1, true, function() {
                plugin.openNativeFeatureForm(feature)
            })

        } catch (jumpError) {
            console.log("QField Table v0.12.10 jumpTo : " + jumpError)

            // Ne jamais empêcher l'édition si le zoom échoue.
            try {
                mainWindow.displayToast(
                    qsTr("Zoom impossible : %1").arg(String(jumpError)))
            } catch (toastError) {}

            openNativeFeatureForm(feature)
        }
    }


    function openNativeFeatureForm(feature) {
        var drawer = overlayFeatureFormDrawer
        if (!drawer) {
            try {
                drawer = iface.findItemByObjectName("overlayFeatureFormDrawer")
                overlayFeatureFormDrawer = drawer
            } catch (findError) {}
        }

        if (!drawer) {
            diagnosticMessage = qsTr("Le formulaire natif de QField n’a pas été trouvé.")
            try { mainWindow.displayToast(diagnosticMessage) } catch (toastError) {}
            return false
        }

        try {
            // Le FeatureModel est la source de vérité du formulaire natif.
            drawer.featureModel.currentLayer = selectedLayer
            drawer.featureModel.feature = feature

            // IMPORTANT : pour une entité existante, l'état d'édition doit
            // être appliqué au drawer ET au FeatureForm lorsque disponible.
            drawer.state = "Edit"
            if (drawer.featureForm) {
                try { drawer.featureForm.state = "Edit" } catch (stateError1) {}
                try { drawer.featureForm.state = "FeatureFormEdit" } catch (stateError2) {}
            }

            // Ouvrir d'abord le drawer puis refaire le zoom après le changement
            // de largeur de la carte afin que l'entité demeure visible.
            drawer.open()
            Qt.callLater(function() {
                try { drawer.featureForm.toolbarVisible = true } catch(toolbarError) {}

                nativeMapBlocker.visible = true

                // Le cadrage a déjà été effectué sur le canevas libre avant
                // l'ouverture du formulaire. Ne plus modifier l'emprise ici.
                var canvas = iface.mapCanvas()
                if (canvas) {
                    nativePreviousMapInteractive = canvas.interactive
                    canvas.interactive = true
                    plugin.freezeNativeMapForForm()
                }

                nativeEditSessionActive = true
                nativeMapBlocker.visible = true
                nativeEditBar.visible = true
                nativeEditBar.raise()
            })
            return true

        } catch (formError) {
            diagnosticMessage =
                    qsTr("Impossible d’ouvrir le formulaire natif : %1")
                    .arg(String(formError))
            console.log("QField Table v0.12.10 formulaire natif : " + formError)
            try { mainWindow.displayToast(diagnosticMessage) } catch (toastError2) {}
            return false
        }
    }

    function resolveAutosaveSettingsPath() {
        var projectPath = projectFilePathForJournal()
        if (!projectPath)
            return ""

        try {
            var folder = String(FileUtils.absolutePath(projectPath) || "")
            if (!folder)
                return ""

            var sep = folder.charAt(folder.length - 1) === "/" ||
                      folder.charAt(folder.length - 1) === "\\" ? "" : "/"

            return folder + sep + "qfield_table_settings.json"
        } catch (e) {
            return ""
        }
    }

    function loadAutosaveSettings() {
        nativeAutosaveSettingsPath = resolveAutosaveSettingsPath()

        if (!nativeAutosaveSettingsPath)
            return false

        try {
            if (!FileUtils.fileExists(nativeAutosaveSettingsPath))
                return true

            var text = String(
                        FileUtils.readFileContent(nativeAutosaveSettingsPath))

            if (!text || text.trim().length === 0)
                return true

            var obj = JSON.parse(text)

            if (obj.autosaveEnabled !== undefined)
                nativeAutosaveEnabled = obj.autosaveEnabled === true

            if (obj.autosaveDelayMs !== undefined) {
                var delay = Number(obj.autosaveDelayMs)
                if (!isNaN(delay))
                    nativeAutosaveDelay =
                            Math.max(500, Math.min(60000, delay))
            }

            return true
        } catch (e) {
            console.log("QField Table v0.12.10 réglages autosave : " + e)
            return false
        }
    }

    function saveAutosaveSettings() {
        if (!nativeAutosaveSettingsPath)
            nativeAutosaveSettingsPath = resolveAutosaveSettingsPath()

        if (!nativeAutosaveSettingsPath)
            return false

        try {
            var payload = {
                "format": "QFieldTableSettings",
                "version": 1,
                "autosaveEnabled": nativeAutosaveEnabled,
                "autosaveDelayMs": nativeAutosaveDelay
            }

            return FileUtils.writeFileContent(
                        nativeAutosaveSettingsPath,
                        JSON.stringify(payload, null, 2))
        } catch (e) {
            console.log("QField Table v0.12.10 sauvegarde réglages : " + e)
            return false
        }
    }

    function autosaveStatusText() {
        if (!nativeAutosaveEnabled)
            return qsTr("Autosave : désactivé")

        var seconds = nativeAutosaveDelay / 1000.0
        return qsTr("Autosave : %1 s").arg(seconds.toFixed(
                    seconds % 1 === 0 ? 0 : 1))
    }

    function scrollNativeFormStep(direction) {
        if (!nativeEditSessionActive)
            return false

        var target = nativeFormMainFlickable()
        if (!target)
            return false

        try {
            var maximum = Math.max(
                        0,
                        Number(target.contentHeight) -
                        Number(target.height))

            var step = 110
            var nextY = Math.max(
                        0,
                        Math.min(
                            maximum,
                            Number(target.contentY) +
                            (direction > 0 ? step : -step)))

            target.contentY = nextY
            return true

        } catch (e) {
            console.log("QField Table v0.12.10 scroll : " + e)
            return false
        }
    }

    function captureNativeMapWheel() {
        if (!nativeEditSessionActive)
            return

        var canvas = iface.mapCanvas()
        if (!canvas || !canvas.mapSettings)
            return

        try {
            nativeWheelOldScale = Number(canvas.mapSettings.scale)
            nativeWheelOldExtent = canvas.mapSettings.extent
            nativeWheelProxyTimer.restart()
        } catch (e) {
            console.log("QField Table v0.12.10 capture roulette : " + e)
        }
    }

    function applyNativeMapWheelToForm() {
        if (!nativeEditSessionActive)
            return

        var canvas = iface.mapCanvas()
        if (!canvas || !canvas.mapSettings)
            return

        try {
            var oldScale = Number(nativeWheelOldScale)
            var newScale = Number(canvas.mapSettings.scale)

            if (isNaN(oldScale) || isNaN(newScale) ||
                oldScale <= 0 || newScale <= 0)
                return

            if (Math.abs(newScale - oldScale) < 0.01)
                return

            // Échelle numérique plus grande = zoom arrière = défiler vers le bas.
            var direction = newScale > oldScale ? 1 : -1

            // Le canevas est gelé visuellement pendant l'édition; on restaure
            // néanmoins son emprise afin qu'aucun zoom ne subsiste.
            if (nativeWheelOldExtent)
                canvas.mapSettings.extent = nativeWheelOldExtent

            scrollNativeFormStep(direction)

        } catch (e) {
            console.log("QField Table v0.12.10 proxy roulette : " + e)
        }
    }

    function freezeNativeMapForForm() {
        var canvas = iface.mapCanvas()
        if (!canvas)
            return

        try {
            nativeLockedMapExtent = canvas.mapSettings.extent
            canvas.freeze("qfield_table_native_form")
            nativeMapFrozenByPlugin = true
        } catch (e) {
            nativeMapFrozenByPlugin = false
            console.log("QField Table v0.12.10 freeze carte : " + e)
        }
    }

    function restoreNativeMapAfterForm() {
        var canvas = iface.mapCanvas()
        if (!canvas)
            return

        try {
            if (nativeLockedMapExtent)
                canvas.mapSettings.extent = nativeLockedMapExtent

            if (nativeMapFrozenByPlugin)
                canvas.unfreeze("qfield_table_native_form")

            nativeMapFrozenByPlugin = false
            nativeLockedMapExtent = null
        } catch (e) {
            console.log("QField Table v0.12.10 unfreeze carte : " + e)
        }
    }

    function nativeFormMainFlickable() {
        var drawer = overlayFeatureFormDrawer
        var root = drawer ? drawer.featureForm : null

        if (!root)
            return null

        var best = null
        var bestScore = -1

        function inspect(item) {
            if (!item)
                return

            try {
                var itemText = String(item)
                var hasContentY =
                        typeof item.contentY !== "undefined"
                var hasContentHeight =
                        typeof item.contentHeight !== "undefined"
                var hasHeight =
                        typeof item.height !== "undefined"

                if (itemText.indexOf("Flickable") !== -1 &&
                    hasContentY && hasContentHeight && hasHeight &&
                    item.visible !== false &&
                    Number(item.contentHeight) > Number(item.height) + 4) {

                    // Le défilement principal du formulaire occupe normalement
                    // la plus grande hauteur. Les listes internes ont donc un
                    // score inférieur et ne capturent plus la roulette.
                    var score = Number(item.height)

                    if (score > bestScore) {
                        best = item
                        bestScore = score
                    }
                }
            } catch (inspectError) {}

            try {
                if (item.children) {
                    for (var i = 0; i < item.children.length; ++i)
                        inspect(item.children[i])
                }
            } catch (childrenError) {}
        }

        inspect(root)
        return best
    }

    function scrollNativeFormByWheel(wheel) {
        if (!nativeEditSessionActive)
            return false

        var target = nativeFormMainFlickable()

        if (!target)
            return false

        try {
            var delta = 0

            if (wheel.pixelDelta &&
                Number(wheel.pixelDelta.y) !== 0)
                delta = Number(wheel.pixelDelta.y)
            else if (wheel.angleDelta)
                delta = Number(wheel.angleDelta.y) / 120.0 * 110.0

            if (delta === 0)
                return false

            var maximum =
                    Math.max(0,
                             Number(target.contentHeight) -
                             Number(target.height))

            // Roulette vers le bas => contentY augmente.
            var nextY =
                    Math.max(0,
                             Math.min(maximum,
                                      Number(target.contentY) - delta))

            target.contentY = nextY
            wheel.accepted = true
            return true

        } catch (scrollError) {
            console.log(
                "QField Table v0.12.10 défilement formulaire : " +
                scrollError)
            return false
        }
    }

    function nativeFormMode() {
        var drawer = overlayFeatureFormDrawer
        if (!drawer)
            return ""

        try {
            if (drawer.featureForm && drawer.featureForm.state !== undefined)
                return String(drawer.featureForm.state || "")
        } catch (e1) {}

        try {
            return String(drawer.state || "")
        } catch (e2) {}

        return ""
    }

    function nativeFormIsNewEntity() {
        var mode = nativeFormMode().toLowerCase()

        // Selon la version QField, l'état peut être Add ou FeatureFormAdd.
        return mode === "add" ||
               mode === "featureformadd" ||
               mode.indexOf("add") !== -1
    }

    function nativeAutosaveCurrentForm() {
        if (!nativeEditSessionActive || !nativeAutosaveEnabled)
            return

        var drawer = overlayFeatureFormDrawer
        if (!drawer || !drawer.featureForm)
            return

        var form = drawer.featureForm
        var model = null

        try { model = form.model } catch (modelError) {}

        // La première sauvegarde d'une nouvelle entité doit rester manuelle.
        if (nativeFormIsNewEntity()) {
            console.log("QField Table v0.12.10 Autosave : nouvelle entité ignorée")
            return
        }

        // Même règle que l'Autosave Toolkit : une contrainte forte invalide
        // interdit l'autosauvegarde.
        try {
            if (model &&
                model.hasConstraints &&
                !model.constraintsHardValid) {

                mainWindow.displayToast(
                    qsTr("Autosauvegarde impossible : remplissez les champs obligatoires."))

                console.log("QField Table v0.12.10 Autosave : contrainte invalide")
                return
            }
        } catch (constraintError) {
            console.log("QField Table v0.12.10 Autosave contraintes : " +
                        constraintError)
        }

        try {
            var ok = false

            // AttributeFormModel.save() sauvegarde l'entité existante tout en
            // conservant le formulaire ouvert.
            if (model && typeof model.save === "function")
                ok = model.save()
            else if (typeof form.save === "function")
                ok = form.save()

            if (ok) {
                mainWindow.displayToast(qsTr("Enregistrement automatique"))
                console.log("QField Table v0.12.10 Autosave : sauvegarde réussie")
            } else {
                console.log("QField Table v0.12.10 Autosave : sauvegarde refusée")
            }

        } catch (saveError) {
            console.log("QField Table v0.12.10 Autosave erreur : " + saveError)
        }
    }

    function nativeAutosaveValueChanged() {
        if (!nativeEditSessionActive || !nativeAutosaveEnabled)
            return

        nativeAutosaveTimer.restart()
        console.log("QField Table v0.12.10 Autosave : modification détectée")
    }

    function saveNativeFeatureFormCore(showToast) {
        nativeAutosaveTimer.stop()

        var drawer = overlayFeatureFormDrawer
        if (!drawer || !drawer.featureForm)
            return false

        try {
            var form = drawer.featureForm
            var model = null

            try { model = form.model } catch (modelError) {}

            if (model &&
                model.hasConstraints &&
                !model.constraintsHardValid) {

                if (showToast) {
                    mainWindow.displayToast(
                        qsTr("Enregistrement impossible : remplissez les champs obligatoires."))
                }
                return false
            }

            var ok = false

            if (model && typeof model.save === "function")
                ok = model.save()
            else if (typeof form.save === "function")
                ok = form.save()
            else if (drawer.featureModel &&
                     typeof drawer.featureModel.save === "function")
                ok = drawer.featureModel.save(true)

            if (ok) {
                refreshAfterNativeEdit = true

                if (showToast) {
                    try {
                        mainWindow.displayToast(
                            qsTr("Enregistrement sauvegardé."))
                    } catch (toastError) {}
                }
                return true
            }

            if (showToast) {
                try {
                    mainWindow.displayToast(
                        qsTr("La sauvegarde a été refusée. Vérifiez les contraintes du formulaire."))
                } catch (toastError2) {}
            }

            return false

        } catch (saveError) {
            console.log("QField Table v0.12.10 sauvegarde : " + saveError)

            if (showToast) {
                try {
                    mainWindow.displayToast(
                        qsTr("Erreur pendant la sauvegarde : %1")
                        .arg(String(saveError)))
                } catch (toastError3) {}
            }

            return false
        }
    }

    function saveNativeFeatureForm() {
        saveNativeFeatureFormCore(true)
    }



    function returnToAttributeTableNow() {
        returnToTableTimer.stop()

        if (!returnToTableAfterNativeClose)
            return

        returnToTableAfterNativeClose = false

        // openBrowser() voit refreshAfterNativeEdit=true et recharge
        // automatiquement la couche avant de réafficher la table.
        Qt.callLater(function() {
            plugin.openBrowser()
        })
    }

    function closeNativeFeatureFormAndReturn() {
        var drawer = overlayFeatureFormDrawer

        if (!saveNativeFeatureFormCore(false)) {
            try {
                mainWindow.displayToast(
                    qsTr("Impossible de fermer : corrigez les champs obligatoires ou les contraintes."))
            } catch (toastError) {}
            return
        }

        nativeAutosaveTimer.stop()
        nativeEditSessionActive = false
        returnToTableAfterNativeClose = true
        refreshAfterNativeEdit = true

        nativeEditBar.visible = false
        nativeMapBlocker.visible = false

        restoreNativeMapAfterForm()

        var canvas = iface.mapCanvas()
        if (canvas)
            canvas.interactive = nativePreviousMapInteractive

        if (!drawer) {
            returnToTableAfterNativeClose = true
            returnToTableTimer.restart()
            return
        }

        try {
            drawer.close()

            // OverlayFeatureFormDrawer ne signale pas toujours onClosed()
            // lorsqu'il est fermé programmatiquement. Le retour à la table
            // est donc déclenché explicitement après la fermeture visuelle.
            returnToTableTimer.restart()

        } catch (closeError) {
            console.log(
                "QField Table v0.12.10 fermeture après sauvegarde : " +
                closeError)

            returnToTableAfterNativeClose = true
            returnToTableTimer.restart()
        }
    }


    function cancelNativeFeatureForm() {
        var drawer = overlayFeatureFormDrawer

        nativeAutosaveTimer.stop()
        nativeEditSessionActive = false
        returnToTableAfterNativeClose = true
        refreshAfterNativeEdit = true

        nativeEditBar.visible = false
        nativeMapBlocker.visible = false

        restoreNativeMapAfterForm()

        if (!drawer) {
            returnToTableTimer.restart()
            return
        }

        try {
            // reset() est l'API QField qui restaure les valeurs originales
            // et abandonne les modifications tamponnées.
            if (drawer.featureModel &&
                typeof drawer.featureModel.reset === "function")
                drawer.featureModel.reset()

            try {
                if (drawer.featureForm &&
                    drawer.featureForm.model &&
                    typeof drawer.featureForm.model.applyFeatureModel === "function")
                    drawer.featureForm.model.applyFeatureModel()
            } catch (applyError) {}

            drawer.close()
            returnToTableTimer.restart()

        } catch (cancelError) {
            console.log("QField Table v0.12.10 annulation : " + cancelError)
            try { drawer.close() } catch (closeError) {}
            returnToTableTimer.restart()
        }
    }


    function qmlObjectSummary(obj, label) {
        if (!obj)
            return label + " : NULL\n"

        var lines = []
        lines.push(label + " : OK")
        try { lines.push("  objectName = " + obj.objectName) } catch(e1) {}
        try { lines.push("  state = " + obj.state) } catch(e2) {}
        try { lines.push("  visible = " + obj.visible) } catch(e3) {}
        try { lines.push("  enabled = " + obj.enabled) } catch(e4) {}
        try { lines.push("  opened = " + obj.opened) } catch(e5) {}
        try { lines.push("  toolbarVisible = " + obj.toolbarVisible) } catch(e6) {}
        try { lines.push("  setupOnly = " + obj.setupOnly) } catch(e7) {}
        try { lines.push("  embedded = " + obj.embedded) } catch(e8) {}
        try { lines.push("  isAdding = " + obj.isAdding) } catch(e9) {}
        try { lines.push("  fullScreenView = " + obj.fullScreenView) } catch(e10) {}
        try { lines.push("  parent.objectName = " + (obj.parent ? obj.parent.objectName : "")) } catch(e11) {}
        return lines.join("\n") + "\n"
    }

    function collectNativeEditDiagnostic(feature) {
        var d = overlayFeatureFormDrawer
        var f = d ? d.featureForm : null
        var m = d ? d.featureModel : null
        var am = f ? f.model : null

        var text = "QField Table v0.12.10 — diagnostic formulaire natif\n\n"
        text += qmlObjectSummary(d, "OverlayFeatureFormDrawer")
        text += "\n" + qmlObjectSummary(f, "FeatureForm")
        text += "\n" + qmlObjectSummary(m, "FeatureModel")
        text += "\n" + qmlObjectSummary(am, "AttributeFormModel")

        text += "\nENTITÉ\n"
        try { text += "  id = " + feature.id + "\n" } catch(e1) {}
        try { text += "  valid = " + feature.valid + "\n" } catch(e2) {}
        try { text += "  geometry null = " + (!feature.geometry) + "\n" } catch(e3) {}
        try {
            var bb = feature.geometry.boundingBox
            text += "  bbox = " + bb.xMinimum + ", " + bb.yMinimum +
                    " / " + bb.xMaximum + ", " + bb.yMaximum + "\n"
        } catch(e4) {
            text += "  bbox = ERREUR: " + e4 + "\n"
        }

        text += "\nAPI DISPONIBLES\n"
        try { text += "  iface.setMapExtent = " + (iface.setMapExtent ? "oui" : "non") + "\n" } catch(e5) {}
        try { text += "  FeatureModel.save = " + (m && m.save ? "oui" : "non") + "\n" } catch(e6) {}
        try { text += "  FeatureForm.requestCancel = " + (f && f.requestCancel ? "oui" : "non") + "\n" } catch(e7) {}

        nativeEditDiagnostic = text
        console.log(text)
        return text
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
        distinctValues = []
        visibleDistinctValues = []
        selectedDistinctKeys = ({})
        applyView()
    }

    function openBrowser() {
        // Une simple fermeture du dialogue ne détruit pas le plugin.
        // Après une édition effectuée via le flux natif de QField, on relit le
        // jeu actuellement chargé afin de récupérer les valeurs modifiées.
        if (refreshAfterNativeEdit && selectedLayer && columns.length > 0) {
            refreshAfterNativeEdit = false
            reloadFeaturesOnly()
        } else if (needsProjectRefresh || !selectedLayer || vectorLayers.length === 0 || columns.length === 0 || flatRows.length === 0) {
            needsProjectRefresh = false
            refreshLayers()
        }
        browserDialog.open()
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            loadAutosaveSettings()
            if (!loadPersistentBatchJournal() && batchJournalPersistenceError.length > 0)
                console.log("QField Table — journal non chargé : " + batchJournalPersistenceError)
        })
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.12.10 chargé")
    }



    // Capture la roulette directement SUR le canevas QField.
    // C'est plus fiable qu'un MouseArea parenté à mainWindow.contentItem,
    // car le MapCanvas est lui-même un élément d'interface de premier plan.
    MouseArea {
        id: mapCanvasWheelCatcher
        parent: iface.mapCanvas()
        anchors.fill: parent
        visible: false
        z: 10000000

        // Aucun clic n'est capturé : uniquement la roulette.
        acceptedButtons: Qt.NoButton
        hoverEnabled: true

        onWheel: function(wheel) {
            plugin.scrollNativeFormByWheel(wheel)
            wheel.accepted = true
        }
    }

    // Verrouille le canevas pendant l'édition. Le FeatureForm natif est
    // affiché dans un QQuickPopupItem, donc il demeure au-dessus de ce bloqueur.
    // La molette utilisée sur le formulaire continue ainsi à faire défiler
    // le formulaire, tandis que la carte ne zoome plus.
    MouseArea {
        id: nativeMapBlocker
        parent: plugin.mainWindow ? plugin.mainWindow.contentItem : plugin
        anchors.fill: parent
        visible: false
        z: 999998

        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false

        onPressed: function(mouse) { mouse.accepted = true }
        onReleased: function(mouse) { mouse.accepted = true }
        onClicked: function(mouse) { mouse.accepted = true }
        onDoubleClicked: function(mouse) { mouse.accepted = true }
        onPositionChanged: function(mouse) { mouse.accepted = true }
        onWheel: function(wheel) { wheel.accepted = false }
    }

    // Intercepte uniquement la roulette au-dessus du formulaire.
    // Les clics restent transmis aux widgets grâce à Qt.NoButton.
    MouseArea {
        id: nativeFormWheelCatcher

        parent: plugin.overlayFeatureFormDrawer &&
                plugin.overlayFeatureFormDrawer.featureForm
                ? plugin.overlayFeatureFormDrawer.featureForm.parent
                : plugin

        anchors.fill: parent
        visible: false
        z: 999998

        acceptedButtons: Qt.NoButton
        hoverEnabled: false

        onWheel: function(wheel) {
            plugin.scrollNativeFormByWheel(wheel)
        }
    }

    // Barre de secours explicite : elle est placée au niveau de la fenêtre
    // principale, au-dessus du drawer QField. Elle garantit qu'Enregistrer et
    // Annuler restent disponibles même si la version de QField ne montre pas
    // sa barre native pour un formulaire ouvert par un plugin.
    Rectangle {
        id: nativeEditBar

        // Le diagnostic v0.10.2 a montré que FeatureForm vit dans un
        // QQuickPopupItem. En nous plaçant dans ce même parent, la barre ne
        // peut plus être masquée derrière le popup.
        parent: plugin.overlayFeatureFormDrawer &&
                plugin.overlayFeatureFormDrawer.featureForm
                ? plugin.overlayFeatureFormDrawer.featureForm.parent
                : plugin

        visible: false
        z: 10000000
        height: 46
        width: 340
        radius: 8

        anchors.right: parent ? parent.right : undefined
        anchors.top: parent ? parent.top : undefined
        anchors.rightMargin: 62
        anchors.topMargin: 8

        Row {
            anchors.centerIn: parent
            spacing: 10

            Button {
                text: qsTr("Annuler")
                onClicked: plugin.cancelNativeFeatureForm()
            }

            Button {
                text: qsTr("Enregistrer")
                font.bold: true
                onClicked: plugin.saveNativeFeatureForm()
            }

            Button {
                text: qsTr("Fermer")
                onClicked: plugin.closeNativeFeatureFormAndReturn()
            }
        }
    }



    Connections {
        target: iface
        function onLoadProjectEnded() {
            Qt.callLater(function() {
                plugin.loadAutosaveSettings()
                plugin.loadPersistentBatchJournal()
            })

            // Si le projet change, le cache courant n’est plus valide.
            // On recharge immédiatement seulement lorsque la table est ouverte;
            // sinon le prochain clic sur l’icône fera le rechargement.
            needsProjectRefresh = true
            if (browserDialog.visible) {
                needsProjectRefresh = false
                refreshLayers()
            }
        }
    }

    // QGIS/QField natif : retourne les libellés configurés par les widgets
    // (Value Relation, Value Map, etc.) via represent_value().
    ExpressionEvaluator {
        id: displayExpressionEvaluator
        project: qgisProject
        layer: plugin.selectedLayer
        mapSettings: iface.mapCanvas().mapSettings
        mode: ExpressionEvaluator.ExpressionMode
    }

    Timer {
        id: schemaPollTimer
        interval: 250
        repeat: true
        running: false
        property int attempts: 0
        onTriggered: {
            if (!plugin.schemaCollectorEnabled ||
                !plugin.schemaLayer ||
                !plugin.schemaFeature) {
                stop()
                attempts = 0
                return
            }

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
                plugin.diagnosticMessage =
                    qsTr("Le FeatureModel n'a exposé aucun attribut après 5 secondes pour la couche « %1 ».")
                    .arg(plugin.layerName(plugin.schemaLayer))
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

    Connections {
        target: iface.mapCanvas()
        ignoreUnknownSignals: true

        function onAboutToWheelZoom() {
            plugin.captureNativeMapWheel()
        }
    }

    Connections {
        target: plugin.overlayFeatureFormDrawer
                ? plugin.overlayFeatureFormDrawer.featureForm
                : null
        ignoreUnknownSignals: true

        function onValueChanged() {
            plugin.nativeAutosaveValueChanged()
        }
    }

    Connections {
        target: plugin.overlayFeatureFormDrawer
        ignoreUnknownSignals: true

        function onClosed() {
            plugin.restoreNativeMapAfterForm()
            nativeAutosaveTimer.stop()
            plugin.nativeEditSessionActive = false
            plugin.nativeEditBar.visible = false
            plugin.nativeMapBlocker.visible = false

            var canvas = iface.mapCanvas()
            if (canvas)
                canvas.interactive = plugin.nativePreviousMapInteractive

            if (plugin.returnToTableAfterNativeClose) {
                // Si le signal natif arrive avant le timer explicite,
                // utiliser ce chemin et empêcher un deuxième retour.
                returnToTableTimer.stop()
                plugin.returnToAttributeTableNow()

            } else if (plugin.refreshAfterNativeEdit &&
                       plugin.selectedLayer) {

                Qt.callLater(function() {
                    plugin.reloadFeaturesOnly()
                })
            }
        }
    }

    Connections {
        target: plugin.overlayFeatureFormDrawer
                ? plugin.overlayFeatureFormDrawer.featureForm
                : null
        ignoreUnknownSignals: true

        function onConfirmed() {
            if (plugin.refreshAfterNativeEdit && plugin.selectedLayer)
                Qt.callLater(function() { plugin.reloadFeaturesOnly() })
        }

        function onCancelled() {
            nativeAutosaveTimer.stop()
            plugin.nativeEditSessionActive = false
            plugin.nativeEditBar.visible = false
            plugin.nativeMapBlocker.visible = false

            var canvas = iface.mapCanvas()
            if (canvas)
                canvas.interactive = plugin.nativePreviousMapInteractive

            // Le signal cancelled arrive après validation de la boîte
            // « Annuler l'édition ». Fermer le drawer si QField ne l'a
            // pas déjà fait, puis rouvrir directement la table.
            try {
                if (plugin.overlayFeatureFormDrawer)
                    plugin.overlayFeatureFormDrawer.close()
            } catch (drawerCloseError) {}

            if (plugin.returnToTableAfterNativeClose) {
                plugin.returnToTableAfterNativeClose = false
                returnToTableTimer.stop()

                Qt.callLater(function() {
                    plugin.openBrowser()
                })
            }
        }
    }







    Timer {
        id: nativeWheelProxyTimer
        interval: 35
        repeat: false
        onTriggered: plugin.applyNativeMapWheelToForm()
    }

    Timer {
        id: returnToTableTimer
        interval: 280
        repeat: false
        onTriggered: plugin.returnToAttributeTableNow()
    }

    Timer {
        id: sharedViewApplyTimer
        interval: 150
        repeat: true
        onTriggered: plugin.continuePendingSharedViewApplication()
    }

    Timer {
        id: nativeAutosaveTimer
        interval: plugin.nativeAutosaveDelay
        repeat: false
        onTriggered: plugin.nativeAutosaveCurrentForm()
    }

    Timer {
        id: nativeJumpTimer
        interval: 220
        repeat: false
        onTriggered: plugin.jumpToPendingNativeFeature()
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
    ListModel { id: sharedViewsListModel }

    QfToolButton {
        id: pluginButton
        iconSource: "icon.svg"
        iconColor: Theme.mainColor
        bgcolor: Theme.darkGray
        round: true
        onClicked: plugin.openBrowser()
    }

    Dialog {
        id: autosaveSettingsDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Réglages de l’autosauvegarde")
        width: Math.min(520, parent ? parent.width * 0.90 : 520)
        standardButtons: Dialog.NoButton

        onOpened: {
            autosaveEnabledSwitch.checked = plugin.nativeAutosaveEnabled
            autosaveDelaySpin.value =
                    Math.round(plugin.nativeAutosaveDelay / 1000)
        }

        contentItem: ColumnLayout {
            spacing: 14

            Switch {
                id: autosaveEnabledSwitch
                text: qsTr("Activer l’autosauvegarde")
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: qsTr("Délai après la dernière modification")
                    Layout.fillWidth: true
                }

                SpinBox {
                    id: autosaveDelaySpin
                    from: 1
                    to: 60
                    stepSize: 1
                    editable: true
                    enabled: autosaveEnabledSwitch.checked
                }

                Label {
                    text: qsTr("seconde(s)")
                    enabled: autosaveEnabledSwitch.checked
                }
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.70
                text: qsTr("Le délai est relancé à chaque modification. Une contrainte forte invalide empêche toujours l’autosauvegarde.")
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Annuler")
                    onClicked: autosaveSettingsDialog.close()
                }

                Button {
                    text: qsTr("Appliquer")
                    font.bold: true
                    onClicked: {
                        plugin.nativeAutosaveEnabled =
                                autosaveEnabledSwitch.checked

                        plugin.nativeAutosaveDelay =
                                autosaveDelaySpin.value * 1000

                        if (!plugin.nativeAutosaveEnabled)
                            nativeAutosaveTimer.stop()

                        plugin.saveAutosaveSettings()
                        autosaveSettingsDialog.close()
                    }
                }
            }
        }
    }

    QfDialog {
        id: browserDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("QField Table — v0.12.10")
        standardButtons: Dialog.Close
        width: parent ? Math.max(900, parent.width * 0.96) : 1400
        height: parent ? Math.max(700, parent.height * 0.94) : 900
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0
        contentItem: ColumnLayout {
            spacing: 5

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
                Button {
                    text: qsTr("Chargement…")
                    enabled: plugin.columns.length > 0
                    onClicked: loadDialog.open()
                }
                Button {
                    text: qsTr("Actualiser")
                    onClicked: {
                        plugin.needsProjectRefresh = false
                        plugin.refreshLayers()
                    }
                }
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
                Button {
                    text: qsTr("☑ Tout filtré")
                    enabled: plugin.filteredRows.length > 0
                    onClicked: plugin.selectAllFilteredRows()
                }
                Button {
                    text: qsTr("☐ Aucun")
                    enabled: plugin.batchSelectionCount() > 0
                    onClicked: plugin.clearBatchSelection()
                }
                Button {
                    text: qsTr("Modifier en lot… (%1)").arg(plugin.batchSelectionCount())
                    enabled: plugin.batchSelectionCount() > 0
                    onClicked: plugin.openBatchEditDialog()
                }
                Button {
                    text: qsTr("Journal (%1)").arg(plugin.batchJournal.length)
                    enabled: plugin.batchJournal.length > 0
                    onClicked: batchJournalDialog.open()
                }
                Button {
                    text: plugin.autosaveStatusText()
                    onClicked: autosaveSettingsDialog.open()
                }

                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: qsTr("Filtres actifs : %1").arg(Object.keys(plugin.activeColumnFilters).length)
                    font.bold: true
                }

                Label {
                    Layout.fillWidth: true
                    text: qsTr("Cliquez sur ▼ dans l’en-tête d’une colonne. Les filtres appliqués à plusieurs colonnes sont combinés avec ET.")
                    opacity: 0.72
                    elide: Text.ElideRight
                }

                Button {
                    text: qsTr("Effacer tous les filtres")
                    enabled: Object.keys(plugin.activeColumnFilters).length > 0
                    onClicked: plugin.clearAllFilters()
                }
                Button {
                    text: qsTr("Vues partagées…")
                    onClicked: {
                        plugin.loadSharedViews()
                        sharedViewsDialog.open()
                    }
                }
                Button {
                    text: qsTr("Partager code…")
                    onClicked: plugin.makeSharedViewCode()
                }
                Button {
                    text: qsTr("▦ Colonnes…")
                    onClicked: plugin.openColumnManager()
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

                property var referenceFeature: plugin.schemaFeature

                FeatureModel {


                    id: batchSaveModel


                    project: qgisProject


                    currentLayer: plugin.selectedLayer


                    modelMode: FeatureModel.SingleFeatureModel


                }



                FeatureModel {
                    id: relationCreateModel
                    project: qgisProject
                    currentLayer: plugin.batchRelationLayer
                    modelMode: FeatureModel.SingleFeatureModel
                }

                FeatureModel {
                    id: journalSaveModel
                    project: qgisProject
                    currentLayer: plugin.batchJournalLayer
                    modelMode: FeatureModel.SingleFeatureModel
                }

                FeatureModel {
                    id: sharedViewSaveModel
                    project: qgisProject
                    currentLayer: plugin.sharedViewsLayer
                    modelMode: FeatureModel.SingleFeatureModel
                }

                FeatureListModel {
                    id: batchRelationModel
                    currentLayer: plugin.batchRelationLayer
                    keyField: plugin.batchRelationKeyField
                    displayValueField: plugin.batchRelationValueField
                    filterExpression: plugin.batchRelationFilterExpression
                    orderByValue: true
                    addNull: false
                }

                Item {
                    id: batchRelationCollector
                    property bool enabled: true
                    width: 1
                    height: 1
                    visible: false

                    Repeater {
                        model: batchRelationCollector.enabled ? batchRelationModel : null
                        delegate: Item {
                            width: 1
                            height: 1

                            // FeatureListModel role names are exposed directly
                            // to the delegate: KeyField, DisplayString,
                            // GroupField and FeatureId.
                            property var relationRaw:
                                typeof KeyField !== "undefined" ? KeyField : ""
                            property var relationLabel:
                                typeof DisplayString !== "undefined"
                                ? DisplayString
                                : relationRaw

                            function publishRelationValue() {
                                if (relationRaw !== undefined &&
                                    relationRaw !== null &&
                                    String(relationRaw).length > 0) {
                                    plugin.registerBatchRelationOption(
                                        relationRaw,
                                        relationLabel
                                    )
                                }
                            }

                            Component.onCompleted: publishRelationValue()
                            onRelationRawChanged: publishRelationValue()
                            onRelationLabelChanged: publishRelationValue()
                        }
                    }
                }

                FeatureModel {
                    id: referenceFeatureModel
                    project: qgisProject
                    currentLayer: plugin.schemaLayer
                    feature: schemaCollector.referenceFeature
                    modelMode: FeatureModel.SingleFeatureModel
                }

                AttributeFormModel {
                    id: projectAttributeFormModel
                    featureModel: referenceFeatureModel
                }

                Item {
                    id: projectWidgetConfigCollector
                    width: 1
                    height: 1
                    visible: false

                    Repeater {
                        model: plugin.schemaCollectorEnabled
                               ? projectAttributeFormModel
                               : null

                        delegate: Item {
                            width: 1
                            height: 1

                            property var formFieldIndex:
                                model.FieldIndex !== undefined ? model.FieldIndex : -1
                            property string formFieldName:
                                model.Name !== undefined ? String(model.Name) : ""
                            property var formEditorWidget:
                                model.EditorWidget !== undefined ? model.EditorWidget : ""
                            property var formEditorWidgetConfig:
                                model.EditorWidgetConfig !== undefined
                                ? model.EditorWidgetConfig : ({})

                            function publishConfig() {
                                if (Number(formFieldIndex) >= 0) {
                                    plugin.registerProjectWidgetConfig(
                                        formFieldIndex,
                                        formFieldName,
                                        formEditorWidget,
                                        formEditorWidgetConfig
                                    )
                                }
                            }

                            Component.onCompleted: publishConfig()
                            onFormEditorWidgetChanged: publishConfig()
                            onFormEditorWidgetConfigChanged: publishConfig()
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    Repeater {
                        model: plugin.schemaCollectorEnabled
                               ? referenceFeatureModel
                               : null
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
                Layout.preferredHeight: 52
                clip: true

                Rectangle { anchors.fill: parent; color: "#f8f8f8" }

                Row {
                    anchors.fill: parent

                    Row {
                        id: frozenHeaderRow
                        width: plugin.frozenWidth()
                        height: parent.height

                        Rectangle {
                            width: 126
                            height: parent.height
                            border.width: 1
                            border.color: Theme.lightGray
                            color: "#f8f8f8"
                            Label {
                                anchors.fill: parent
                                anchors.margins: 6
                                font.bold: true
                                text: qsTr("Lot / Entité")
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Repeater {
                            model: Math.min(plugin.frozenColumnCount, plugin.displayedColumns.length)
                            delegate: Rectangle {
                                required property int index
                                property var columnData: plugin.displayedColumns[index]
                                width: columnData ? plugin.effectiveColumnWidth(columnData) : 140
                                height: frozenHeaderRow.height
                                border.width: 1
                                border.color: Theme.lightGray
                                color: "#f8f8f8"

                                // Le texte et la zone de tri s'arrêtent avant
                                // le bouton de filtre.
                                Label {
                                    anchors.left: parent.left
                                    anchors.right: filterButton.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 3
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    verticalAlignment: Text.AlignVCenter
                                    text: columnData
                                          ? (columnData.alias || columnData.fieldName || qsTr("Champ"))
                                            + (plugin.sortColumn === columnData.originalIndex
                                               ? (plugin.sortAscending ? " ▲" : " ▼") : "")
                                          : ""
                                }

                                MouseArea {
                                    id: sortMouse
                                    anchors.left: parent.left
                                    anchors.right: filterButton.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    hoverEnabled: true
                                    onClicked: if (columnData) plugin.toggleSort(columnData.originalIndex)

                                    ToolTip.visible: containsMouse
                                    ToolTip.text: columnData
                                                  ? qsTr("%1 — cliquer pour trier").arg(columnData.fieldName)
                                                  : ""
                                }

                                Rectangle {
                                    id: filterButton
                                    width: 36
                                    anchors.right: resizeGrip.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    border.width: 1
                                    border.color: Theme.lightGray
                                    color: columnData && plugin.hasActiveFilter(columnData.originalIndex)
                                           ? "#d8ebd8" : "#eeeeee"
                                    z: 10

                                    Label {
                                        anchors.centerIn: parent
                                        text: columnData && plugin.hasActiveFilter(columnData.originalIndex)
                                              ? "●▼" : "▼"
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        propagateComposedEvents: false
                                        onClicked: if (columnData)
                                                       plugin.openHeaderFilter(columnData.originalIndex)
                                    }
                                }

                                Rectangle {
                                    id: resizeGrip
                                    width: 4
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    color: resizeMouse.containsMouse || resizeMouse.pressed
                                           ? Theme.mainColor : "#bcbcbc"
                                    z: 11
                                    property real startWidth: 0
                                    property real startSceneX: 0

                                    MouseArea {
                                        id: resizeMouse
                                        width: 16
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        hoverEnabled: true
                                        cursorShape: Qt.SizeHorCursor
                                        preventStealing: true
                                        propagateComposedEvents: false

                                        onPressed: function(mouse) {
                                            resizeGrip.startWidth = columnData ? columnData.width : 140
                                            var p = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                                            resizeGrip.startSceneX = p.x
                                            if (columnData)
                                                plugin.beginColumnResize(columnData.originalIndex,
                                                                         resizeGrip.startWidth)
                                        }

                                        onPositionChanged: function(mouse) {
                                            if (!pressed || !columnData) return
                                            var p = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                                            var previewWidth = resizeGrip.startWidth +
                                                               (p.x - resizeGrip.startSceneX)
                                            plugin.previewColumnResize(columnData.originalIndex,
                                                                       previewWidth)
                                        }

                                        onReleased: function(mouse) {
                                            if (!columnData) return
                                            var p = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                                            var finalWidth = resizeGrip.startWidth +
                                                             (p.x - resizeGrip.startSceneX)
                                            plugin.commitColumnResize(columnData.originalIndex,
                                                                      finalWidth)
                                        }

                                        onCanceled: plugin.cancelColumnResize()
                                    }
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
                                model: Math.max(0, plugin.displayedColumns.length - plugin.frozenColumnCount)
                                delegate: Rectangle {
                                required property int index
                                property int actualIndex: index + plugin.frozenColumnCount
                                property var columnData: plugin.displayedColumns[actualIndex]
                                width: columnData ? plugin.effectiveColumnWidth(columnData) : 140
                                height: scrollingHeaderViewport.height
                                border.width: 1
                                border.color: Theme.lightGray
                                color: "#f8f8f8"

                                // Le texte et la zone de tri s'arrêtent avant
                                // le bouton de filtre.
                                Label {
                                    anchors.left: parent.left
                                    anchors.right: filterButton.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 3
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    verticalAlignment: Text.AlignVCenter
                                    text: columnData
                                          ? (columnData.alias || columnData.fieldName || qsTr("Champ"))
                                            + (plugin.sortColumn === columnData.originalIndex
                                               ? (plugin.sortAscending ? " ▲" : " ▼") : "")
                                          : ""
                                }

                                MouseArea {
                                    id: sortMouse
                                    anchors.left: parent.left
                                    anchors.right: filterButton.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    hoverEnabled: true
                                    onClicked: if (columnData) plugin.toggleSort(columnData.originalIndex)

                                    ToolTip.visible: containsMouse
                                    ToolTip.text: columnData
                                                  ? qsTr("%1 — cliquer pour trier").arg(columnData.fieldName)
                                                  : ""
                                }

                                Rectangle {
                                    id: filterButton
                                    width: 36
                                    anchors.right: resizeGrip.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    border.width: 1
                                    border.color: Theme.lightGray
                                    color: columnData && plugin.hasActiveFilter(columnData.originalIndex)
                                           ? "#d8ebd8" : "#eeeeee"
                                    z: 10

                                    Label {
                                        anchors.centerIn: parent
                                        text: columnData && plugin.hasActiveFilter(columnData.originalIndex)
                                              ? "●▼" : "▼"
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        propagateComposedEvents: false
                                        onClicked: if (columnData)
                                                       plugin.openHeaderFilter(columnData.originalIndex)
                                    }
                                }

                                Rectangle {
                                    id: resizeGrip
                                    width: 4
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    color: resizeMouse.containsMouse || resizeMouse.pressed
                                           ? Theme.mainColor : "#bcbcbc"
                                    z: 11
                                    property real startWidth: 0
                                    property real startSceneX: 0

                                    MouseArea {
                                        id: resizeMouse
                                        width: 16
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        hoverEnabled: true
                                        cursorShape: Qt.SizeHorCursor
                                        preventStealing: true
                                        propagateComposedEvents: false

                                        onPressed: function(mouse) {
                                            resizeGrip.startWidth = columnData ? columnData.width : 140
                                            var p = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                                            resizeGrip.startSceneX = p.x
                                            if (columnData)
                                                plugin.beginColumnResize(columnData.originalIndex,
                                                                         resizeGrip.startWidth)
                                        }

                                        onPositionChanged: function(mouse) {
                                            if (!pressed || !columnData) return
                                            var p = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                                            var previewWidth = resizeGrip.startWidth +
                                                               (p.x - resizeGrip.startSceneX)
                                            plugin.previewColumnResize(columnData.originalIndex,
                                                                       previewWidth)
                                        }

                                        onReleased: function(mouse) {
                                            if (!columnData) return
                                            var p = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                                            var finalWidth = resizeGrip.startWidth +
                                                             (p.x - resizeGrip.startSceneX)
                                            plugin.commitColumnResize(columnData.originalIndex,
                                                                      finalWidth)
                                        }

                                        onCanceled: plugin.cancelColumnResize()
                                    }
                                }
                            }
                            }
                        }
                    }
                }
            }

            // v0.12.10 : ListView virtualisé. Contrairement au Repeater des versions
            // précédentes, seules les lignes présentes à l’écran (et un petit tampon)
            // sont instanciées. C’est le changement principal de performance.
            ListView {
                id: bodyList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: plugin.filteredRows
                spacing: 0
                cacheBuffer: 240
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: bodyList.width
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
                            id: frozenCellsRowV64
                            width: plugin.frozenWidth()
                            height: parent.height

                            Rectangle {
                                width: 126
                                height: parent.height
                                border.width: 1
                                border.color: Theme.lightGray
                                color: plugin.selectedFeatureId === String(modelData.featureId) && plugin.selectedCellColumn === -1
                                       ? "#dff2c7" : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 3

                                    CheckBox {
                                        checked: plugin.isBatchSelected(modelData.featureId)
                                        onToggled: plugin.setBatchSelected(modelData.featureId, checked)
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Sélection pour modification en lot")
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.featureId
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                ToolTip.visible: entityCellMouseV64.containsMouse
                                ToolTip.text: String(modelData.featureId)

                                MouseArea {
                                    id: entityCellMouseV64
                                    anchors.left: parent.left
                                    anchors.leftMargin: 42
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    hoverEnabled: true
                                    pressAndHoldInterval: 500
                                    onClicked: plugin.selectCell(modelData.featureId, -1, modelData.featureId)
                                    onPressAndHold: plugin.selectCell(modelData.featureId, -1, modelData.featureId)
                                }
                            }

                            Repeater {
                                model: Math.min(plugin.frozenColumnCount, plugin.displayedColumns.length)
                                delegate: Rectangle {
                                    required property int index
                                    property var columnData: plugin.displayedColumns[index]
                                    property string cellValue: columnData ? String(plugin.rowValue(modelData, columnData.originalIndex)) : ""
                                    width: columnData ? plugin.effectiveColumnWidth(columnData) : 140
                                    height: frozenCellsRowV64.height
                                    border.width: 1
                                    border.color: Theme.lightGray
                                    color: plugin.selectedFeatureId === String(modelData.featureId) && plugin.selectedCellColumn === columnData.originalIndex
                                           ? "#dff2c7" : "transparent"
                                    Label {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                        text: cellValue
                                    }
                                    ToolTip.visible: frozenCellMouseV64.containsMouse
                                    ToolTip.text: cellValue
                                    MouseArea {
                                        id: frozenCellMouseV64
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        pressAndHoldInterval: 500
                                        onClicked: plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
                                        onPressAndHold: plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
                                    }
                                }
                            }
                        }

                        Item {
                            id: scrollingCellsViewportV64
                            width: Math.max(0, bodyList.width - frozenCellsRowV64.width)
                            height: parent.height
                            clip: true

                            Row {
                                x: -plugin.horizontalOffset
                                height: parent.height
                                Repeater {
                                    model: Math.max(0, plugin.displayedColumns.length - plugin.frozenColumnCount)
                                    delegate: Rectangle {
                                        required property int index
                                        property int actualIndex: index + plugin.frozenColumnCount
                                        property var columnData: plugin.displayedColumns[actualIndex]
                                        property string cellValue: columnData ? String(plugin.rowValue(modelData, columnData.originalIndex)) : ""
                                        width: columnData ? plugin.effectiveColumnWidth(columnData) : 140
                                        height: scrollingCellsViewportV64.height
                                        border.width: 1
                                        border.color: Theme.lightGray
                                        color: plugin.selectedFeatureId === String(modelData.featureId) && plugin.selectedCellColumn === columnData.originalIndex
                                               ? "#dff2c7" : "transparent"
                                        Label {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            text: cellValue
                                        }
                                        ToolTip.visible: scrollingCellMouseV64.containsMouse
                                        ToolTip.text: cellValue
                                        MouseArea {
                                            id: scrollingCellMouseV64
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            pressAndHoldInterval: 500
                                            onClicked: plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
                                            onPressAndHold: plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
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
                visible: plugin.displayedColumns.length > plugin.frozenColumnCount

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
                id: inspectorHandle
                Layout.fillWidth: true
                Layout.preferredHeight: plugin.selectedFeatureId.length > 0 && !plugin.inspectorCollapsed ? 12 : 0
                visible: plugin.selectedFeatureId.length > 0 && !plugin.inspectorCollapsed
                color: "transparent"

                Rectangle {
                    anchors.centerIn: parent
                    width: 90
                    height: 4
                    radius: 2
                    color: Theme.lightGray
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeVerCursor
                    property real startY: 0
                    property real startHeight: 0
                    onPressed: {
                        var point = inspectorHandle.mapToItem(browserDialog.contentItem, mouse.x, mouse.y)
                        startY = point.y
                        startHeight = plugin.inspectorHeight
                    }
                    onPositionChanged: {
                        if (!pressed) return
                        var point = inspectorHandle.mapToItem(browserDialog.contentItem, mouse.x, mouse.y)
                        var maximum = Math.max(plugin.inspectorMinHeight, browserDialog.height * 0.55)
                        plugin.inspectorHeight = Math.max(plugin.inspectorMinHeight,
                                                          Math.min(maximum, startHeight - (point.y - startY)))
                    }
                    onReleased: plugin.saveColumnConfiguration()
                    onCanceled: plugin.saveColumnConfiguration()
                }
            }

            Rectangle {
                id: inspectorPanel
                Layout.fillWidth: true
                Layout.preferredHeight: plugin.selectedFeatureId.length > 0
                                        ? (plugin.inspectorCollapsed ? 42 : plugin.inspectorHeight)
                                        : 44
                color: "#fafafa"
                border.width: 1
                border.color: Theme.lightGray
                radius: 3

                // État replié: garde seulement une petite barre pour rouvrir l'inspecteur.
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: plugin.selectedFeatureId.length > 0 && plugin.inspectorCollapsed
                    Label {
                        Layout.fillWidth: true
                        font.bold: true
                        text: qsTr("Inspecteur masqué — Entité %1").arg(plugin.selectedFeatureId)
                        elide: Text.ElideRight
                    }
                    Button {
                        text: qsTr("▸ Afficher l'inspecteur")
                        onClicked: {
                            plugin.inspectorCollapsed = false
                            plugin.saveColumnConfiguration()
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 5
                    visible: !plugin.inspectorCollapsed || plugin.selectedFeatureId.length === 0

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
                            text: qsTr("Modifier dans QField")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Zoomer sur l’entité et ouvrir directement son formulaire natif complet dans QField")
                            onClicked: plugin.handOffToNativeQField(plugin.selectedFeatureId)
                        }
                        Button {
                            visible: plugin.selectedFeatureId.length > 0
                            text: qsTr("Copier")
                            enabled: plugin.selectedCellValue.length > 0
                            onClicked: plugin.copySelectedValue()
                        }
                        Button {
                            visible: plugin.selectedFeatureId.length > 0
                            text: "✕"
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Masquer l'inspecteur")
                            onClicked: {
                                plugin.inspectorCollapsed = true
                                plugin.saveColumnConfiguration()
                            }
                        }
                    }

                    ScrollView {
                        id: fullValueScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: plugin.selectedFeatureId.length > 0
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        TextArea {
                            id: fullValueArea
                            width: fullValueScroll.availableWidth
                            height: Math.max(
                                fullValueScroll.availableHeight,
                                contentHeight + topPadding + bottomPadding
                            )
                            readOnly: true
                            selectByMouse: true
                            persistentSelection: true
                            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                            text: plugin.selectedCellValue.length > 0
                                  ? plugin.selectedCellValue
                                  : qsTr("(valeur vide)")
                            color: plugin.selectedCellValue.length > 0 ? Theme.mainTextColor : Theme.secondaryTextColor
                            padding: 12
                            topPadding: 12
                            bottomPadding: 12
                            leftPadding: 12
                            rightPadding: 12
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

    QfDialog {
        id: loadDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Chargement des enregistrements")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(700, parent.width * 0.62) : 820
        height: parent ? Math.max(500, parent.height * 0.65) : 600
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 10

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("La table contient %1 enregistrement(s). Le préfiltre est appliqué avant la construction de la table, ce qui permet de limiter le temps de chargement.").arg(plugin.totalFeatureCount)
            }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: qsTr("Charger les 100 premiers")
                    onClicked: plugin.loadFirstHundred()
                }
                Button {
                    text: qsTr("Charger tous (%1)").arg(plugin.totalFeatureCount)
                    onClicked: plugin.loadAllFeatures()
                }
                Item { Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightGray }

            Label { text: qsTr("Préfiltrer avant le chargement"); font.bold: true }
            ComboBox {
                id: preFilterColumnCombo
                Layout.fillWidth: true
                model: plugin.columns
                textRole: "alias"
                displayText: plugin.preFilterColumn >= 0 && plugin.preFilterColumn < plugin.columns.length
                             ? (plugin.columns[plugin.preFilterColumn].alias || plugin.columns[plugin.preFilterColumn].fieldName)
                             : qsTr("Choisir un champ…")
                onActivated: plugin.preFilterColumn = currentIndex
            }
            RowLayout {
                Layout.fillWidth: true
                ComboBox {
                    id: preFilterModeCombo
                    Layout.preferredWidth: 190
                    model: [qsTr("Contient"), qsTr("Égale"), qsTr("Est vide"), qsTr("N'est pas vide")]
                    onActivated: {
                        plugin.preFilterMode = currentIndex === 1 ? "equals" : currentIndex === 2 ? "empty" : currentIndex === 3 ? "notempty" : "contains"
                    }
                }
                TextField {
                    id: preFilterTextField
                    Layout.fillWidth: true
                    enabled: plugin.preFilterMode !== "empty" && plugin.preFilterMode !== "notempty"
                    placeholderText: qsTr("Valeur du préfiltre…")
                    text: plugin.preFilterText
                    onTextChanged: plugin.preFilterText = text
                }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: qsTr("Exemple : choisir Municipalité + Égale + 38065 charge uniquement les enregistrements correspondants. Le préfiltre porte sur l’ensemble de la couche, pas seulement sur les 100 lignes déjà chargées.")
            }

            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Annuler"); onClicked: loadDialog.close() }
                Button { text: qsTr("Charger avec le préfiltre"); onClicked: plugin.loadWithPreFilter() }
            }
        }
    }

    QfDialog {
        id: createRelationDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Créer une valeur relationnelle")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(520, parent.width * 0.38) : 600
        height: 360
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 10

            Label {
                Layout.fillWidth: true
                text: plugin.batchRelationLayer
                      ? qsTr("Table : %1").arg(plugin.layerName(plugin.batchRelationLayer))
                      : ""
                font.bold: true
            }

            Label { text: qsTr("Clé à enregistrer (%1)").arg(plugin.batchRelationKeyField) }
            TextField {
                Layout.fillWidth: true
                placeholderText: qsTr("Nouvelle clé unique")
                text: plugin.batchNewRelationKey
                onTextChanged: plugin.batchNewRelationKey = text
            }

            Label { text: qsTr("Titre / libellé (%1)").arg(plugin.batchRelationValueField) }
            TextField {
                Layout.fillWidth: true
                placeholderText: qsTr("Titre visible dans QField Table")
                text: plugin.batchNewRelationLabel
                onTextChanged: plugin.batchNewRelationLabel = text
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: qsTr("Les valeurs par défaut de la table liée seront appliquées. Si cette table possède d'autres champs obligatoires, la création sera refusée plutôt que d'insérer une entrée incomplète.")
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Annuler"); onClicked: createRelationDialog.close() }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Créer")
                    enabled: plugin.batchNewRelationKey.trim().length > 0 &&
                             plugin.batchNewRelationLabel.trim().length > 0
                    onClicked: plugin.createRelationEntry()
                }
            }
        }
    }

    QfDialog {
        id: batchJournalDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Historique des modifications en lot")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(900, parent.width * 0.78) : 1000
        height: parent ? Math.max(560, parent.height * 0.72) : 650
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: qsTr("%1 entrée(s) dans l’historique de ce projet").arg(plugin.batchJournal.length)
                font.bold: true
                font.pixelSize: 17
            }
            Label {
                Layout.fillWidth: true
                text: plugin.batchJournalBackend === "geopackage"
                      ? qsTr("Stockage : table qfield_table_journal du projet")
                      : qsTr("Stockage de secours : %1").arg(plugin.batchJournalFilePath)
                wrapMode: Text.WordWrap
                opacity: 0.65
                font.pixelSize: 11
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.batchJournalPersistenceError.length > 0
                text: qsTr("Journal non sauvegardé : %1").arg(plugin.batchJournalPersistenceError)
                wrapMode: Text.WordWrap
                color: "#b00020"
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    model: plugin.batchJournal
                    spacing: 5

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: journalColumn.implicitHeight + 16
                        border.width: 1
                        border.color: Theme.lightGray
                        color: "transparent"

                        Column {
                            id: journalColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 3

                            Label {
                                width: parent.width
                                font.bold: true
                                text: modelData.timestamp + " — " +
                                      (modelData.user && String(modelData.user).length > 0
                                       ? modelData.user + " — " : "") +
                                      modelData.featureId + " — " + modelData.fieldLabel +
                                      " — " + (modelData.success ? qsTr("OK") : qsTr("ÉCHEC"))
                            }
                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: qsTr("Avant : %1").arg(modelData.oldDisplay)
                            }
                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: qsTr("Après : %1").arg(modelData.newDisplay)
                            }
                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                opacity: 0.65
                                text: qsTr("Brut : %1  →  %2").arg(modelData.oldRaw).arg(modelData.newRaw)
                            }
                            Label {
                                width: parent.width
                                visible: String(modelData.note || "").length > 0
                                wrapMode: Text.Wrap
                                text: modelData.note
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: qsTr("Copier le journal")
                    enabled: plugin.batchJournal.length > 0
                    onClicked: plugin.copyBatchJournal()
                }
                Button {
                    text: qsTr("Recharger l'historique")
                    onClicked: plugin.loadPersistentBatchJournal()
                }
                Button {
                    text: qsTr("Copier en CSV")
                    enabled: plugin.batchJournal.length > 0
                    onClicked: plugin.copyBatchJournalCsv()
                }
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Fermer"); onClicked: batchJournalDialog.close() }
            }
        }
    }

    QfDialog {
        id: projectXmlDiagnosticDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Diagnostic du projet QGIS")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(900, parent.width * 0.80) : 1050
        height: parent ? Math.max(620, parent.height * 0.78) : 720
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: qsTr("Ce diagnostic ne modifie aucune donnée. Il montre seulement ce que QField Table retrouve dans le .qgs interne.")
                wrapMode: Text.WordWrap
                font.bold: true
            }

            TextArea {
                id: projectXmlDiagnosticArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                text: plugin.projectXmlDiagnosticText
            }

            RowLayout {
                Layout.fillWidth: true

                Button {
                    text: qsTr("Copier")
                    onClicked: {
                        projectXmlDiagnosticArea.selectAll()
                        projectXmlDiagnosticArea.copy()
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Fermer")
                    onClicked: projectXmlDiagnosticDialog.close()
                }
            }
        }
    }

    QfDialog {
        id: batchEditDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Modification en lot")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(620, parent.width * 0.46) : 700
        height: parent ? Math.max(480, parent.height * 0.58) : 560
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        onOpened: {
            batchFieldCombo.currentIndex = 0
            if (plugin.batchFieldItems.length > 0)
                plugin.batchFieldChanged(0)
            batchOperationCombo.currentIndex =
                plugin.batchOperation === "remove" ? 1 :
                plugin.batchOperation === "replaceall" ? 2 : 0
            batchRelationCombo.currentIndex = -1
            batchValueMapCombo.currentIndex = plugin.batchValueMapItems.length > 0 ? 0 : -1
            batchValueInput.text = ""
        }

        contentItem: ColumnLayout {
            spacing: 10

            Label {
                Layout.fillWidth: true
                text: qsTr("%1 enregistrement(s) sélectionné(s)").arg(plugin.batchSelectionCount())
                font.bold: true
                font.pixelSize: 17
            }

            Label { text: qsTr("Champ à modifier") }

            ComboBox {
                id: batchFieldCombo
                Layout.fillWidth: true
                model: plugin.batchFieldItems
                textRole: "label"
                onActivated: plugin.batchFieldChanged(currentIndex)
            }

            Label {
                visible: plugin.batchFieldColumn >= 0 &&
                         plugin.batchIsMultiValueRelation
                text: qsTr("Opération sur le tableau multiple")
            }

            ComboBox {
                id: batchOperationCombo
                Layout.fillWidth: true
                visible: plugin.batchFieldColumn >= 0 &&
                         plugin.batchIsMultiValueRelation
                model: [
                    qsTr("Ajouter une valeur"),
                    qsTr("Retirer une valeur"),
                    qsTr("Remplacer toutes les valeurs")
                ]
                onActivated: {
                    plugin.batchOperation =
                        currentIndex === 1 ? "remove" :
                        currentIndex === 2 ? "replaceall" : "add"
                }
            }

            Label {
                text: plugin.batchIsValueRelation
                      ? qsTr("Valeur relationnelle")
                      : (plugin.batchIsValueMap ? qsTr("Valeur de la liste")
                                               : qsTr("Nouvelle valeur"))
            }



            RowLayout {
                Layout.fillWidth: true
                visible: plugin.batchFieldColumn >= 0 &&
                         plugin.batchIsValueRelation

                ComboBox {
                    id: batchRelationCombo
                    Layout.fillWidth: true
                    model: plugin.batchRelationItems
                    textRole: "label"

                    displayText: currentIndex >= 0 &&
                                 currentIndex < plugin.batchRelationItems.length
                                 ? plugin.batchRelationItems[currentIndex].label
                                 : qsTr("Choisir une valeur relationnelle…")

                    function synchronizeRawValue() {
                        if (currentIndex >= 0 &&
                            currentIndex < plugin.batchRelationItems.length) {
                            plugin.batchRelationRawValue =
                                String(plugin.batchRelationItems[currentIndex].rawValue)
                        } else {
                            plugin.batchRelationRawValue = ""
                        }
                    }

                    onActivated: synchronizeRawValue()
                    onCurrentIndexChanged: synchronizeRawValue()
                    onModelChanged: Qt.callLater(function() {
                        if (plugin.batchRelationItems.length > 0) {
                            batchRelationCombo.currentIndex = 0
                            batchRelationCombo.synchronizeRawValue()
                        } else {
                            batchRelationCombo.currentIndex = -1
                            plugin.batchRelationRawValue = ""
                        }
                    })
                }


            }

            ComboBox {
                id: batchValueMapCombo
                Layout.fillWidth: true
                visible: plugin.batchIsValueMap
                model: plugin.batchValueMapItems
                textRole: "label"

                displayText: currentIndex >= 0 &&
                             currentIndex < plugin.batchValueMapItems.length
                             ? plugin.batchValueMapItems[currentIndex].label
                             : qsTr("Choisir une valeur…")

                function synchronizeValue() {
                    if (currentIndex >= 0 &&
                        currentIndex < plugin.batchValueMapItems.length)
                        plugin.batchValueText =
                            String(plugin.batchValueMapItems[currentIndex].value)
                }

                onActivated: synchronizeValue()
                onCurrentIndexChanged: synchronizeValue()
                onModelChanged: Qt.callLater(function() {
                    if (plugin.batchValueMapItems.length > 0) {
                        batchValueMapCombo.currentIndex = 0
                        batchValueMapCombo.synchronizeValue()
                    }
                })
            }

            TextField {
                id: batchValueInput
                Layout.fillWidth: true
                visible: !plugin.batchIsValueMap &&
                         !(plugin.batchFieldColumn >= 0 &&
                           plugin.batchIsValueRelation &&
                           plugin.batchRelationLayer !== null)
                placeholderText: plugin.batchIsValueRelation
                                 ? qsTr("Clé brute (secours)")
                                 : qsTr("Valeur à appliquer")
                onTextChanged: plugin.batchValueText = text
            }



            Label {
                Layout.fillWidth: true
                visible: plugin.batchRelationLayer !== null
                text: qsTr("%1 valeur(s) disponible(s).")
                      .arg(plugin.batchRelationItems.length)
                font.bold: true
                color: plugin.batchRelationItems.length > 0
                       ? Theme.mainTextColor
                       : "#a06000"
            }

            RowLayout {
                Layout.fillWidth: true
                visible: plugin.projectXmlDiagnosticText.length > 0

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Diagnostic projet…")
                    onClicked: projectXmlDiagnosticDialog.open()
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Annuler"); onClicked: batchEditDialog.close() }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Continuer…")
                    enabled: plugin.batchFieldColumn >= 0 &&
                             (
                               (plugin.batchIsValueRelation &&
                                (plugin.batchRelationRawValue.length > 0 ||
                                 plugin.batchValueText.trim().length > 0))
                               ||
                               (!plugin.batchIsValueRelation)
                             )
                    onClicked: {
                        if (plugin.batchIsValueRelation)
                            batchRelationCombo.synchronizeRawValue()
                        batchConfirmDialog.open()
                    }
                }
            }
        }
    }

    QfDialog {
        id: batchConfirmDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Confirmer la modification en lot")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(560, parent.width * 0.40) : 640
        height: 330
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 10

            Label {
                Layout.fillWidth: true
                text: qsTr("%1 enregistrement(s) seront modifié(s).")
                      .arg(plugin.batchSelectionCount())
                font.bold: true
                font.pixelSize: 18
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: plugin.batchFieldColumn >= 0 && plugin.batchFieldColumn < plugin.columns.length
                      ? qsTr("Champ : %1")
                        .arg(plugin.columns[plugin.batchFieldColumn].alias ||
                             plugin.columns[plugin.batchFieldColumn].fieldName)
                      : ""
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: plugin.batchIsMultiValueRelation
                      ? qsTr("Opération : %1\nValeur : %2")
                        .arg(plugin.batchOperation === "add" ? qsTr("Ajouter") :
                             plugin.batchOperation === "remove" ? qsTr("Retirer") :
                             qsTr("Remplacer toutes les valeurs"))
                        .arg(plugin.relationLabelForRaw(
                             plugin.batchRelationRawValue.length > 0
                             ? plugin.batchRelationRawValue
                             : plugin.batchValueText))
                      : (plugin.batchIsValueRelation
                         ? qsTr("Nouvelle valeur : %1")
                           .arg(plugin.relationLabelForRaw(
                                plugin.batchRelationRawValue.length > 0
                                ? plugin.batchRelationRawValue
                                : plugin.batchValueText))
                         : qsTr("Nouvelle valeur : %1")
                           .arg(plugin.batchIsValueMap
                                ? plugin.batchValueMapLabel(plugin.batchValueText)
                                : plugin.batchValueText))
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Cette opération écrit réellement dans la couche. Vérifiez la sélection avant de continuer.")
                wrapMode: Text.WordWrap
                color: "#a06000"
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Retour"); onClicked: batchConfirmDialog.close() }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Confirmer et modifier")
                    enabled: !plugin.batchInProgress
                    onClicked: plugin.executeBatchEdit()
                }
            }
        }
    }

    QfDialog {
        id: batchResultDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Résultat de la modification en lot")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(520, parent.width * 0.38) : 600
        height: 330
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 10

            Label {
                Layout.fillWidth: true
                text: qsTr("%1 enregistrement(s) modifié(s) avec succès.")
                      .arg(plugin.batchSuccessCount)
                font.bold: true
                font.pixelSize: 18
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.batchFailedIds.length > 0
                text: qsTr("%1 échec(s) : %2")
                      .arg(plugin.batchFailedIds.length)
                      .arg(plugin.batchFailedIds.join(", "))
                wrapMode: Text.WordWrap
                color: "#a03030"
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.batchFailedIds.length === 0
                text: qsTr("La table a été actualisée avec les valeurs enregistrées.")
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Voir le journal")
                    enabled: plugin.batchJournal.length > 0
                    onClicked: batchJournalDialog.open()
                }
                Button {
                    text: qsTr("Fermer")
                    onClicked: {
                        batchResultDialog.close()
                        plugin.clearBatchSelection()
                    }
                }
            }
        }
    }

    QfDialog {
        id: headerFilterDialog
        parent: mainWindow.contentItem
        modal: true
        title: plugin.filterColumn >= 0 && plugin.filterColumn < plugin.columns.length
               ? qsTr("Filtrer — %1").arg(plugin.columns[plugin.filterColumn].alias ||
                                           plugin.columns[plugin.filterColumn].fieldName)
               : qsTr("Filtrer")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(520, parent.width * 0.38) : 600
        height: 300
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        onOpened: {
            headerFilterMode.currentIndex =
                plugin.filterMode === "values" ? 0 :
                plugin.filterMode === "contains" ? 1 :
                plugin.filterMode === "equals" ? 2 :
                plugin.filterMode === "empty" ? 3 : 4
            headerFilterText.text = plugin.filterText
        }

        contentItem: ColumnLayout {
            spacing: 10

            ComboBox {
                id: headerFilterMode
                Layout.fillWidth: true
                model: [
                    qsTr("Valeurs distinctes…"),
                    qsTr("Contient"),
                    qsTr("Égale"),
                    qsTr("Est vide"),
                    qsTr("N'est pas vide")
                ]

                onActivated: {
                    plugin.filterMode =
                        currentIndex === 0 ? "values" :
                        currentIndex === 2 ? "equals" :
                        currentIndex === 3 ? "empty" :
                        currentIndex === 4 ? "notempty" : "contains"
                }
            }

            TextField {
                id: headerFilterText
                Layout.fillWidth: true
                visible: plugin.filterMode === "contains" || plugin.filterMode === "equals"
                placeholderText: qsTr("Valeur à rechercher…")
                onTextChanged: plugin.filterText = text
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.filterMode === "values"
                text: qsTr("Appliquer ouvre la liste des valeurs distinctes avec leurs comptages.")
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: qsTr("Retirer ce filtre")
                    enabled: plugin.filterColumn >= 0 &&
                             plugin.hasActiveFilter(plugin.filterColumn)
                    onClicked: plugin.clearHeaderFilter()
                }
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Annuler"); onClicked: headerFilterDialog.close() }
                Button { text: qsTr("Appliquer"); onClicked: plugin.applyHeaderFilter() }
            }
        }
    }

    QfDialog {
        id: distinctFilterDialog
        parent: mainWindow.contentItem
        modal: true
        title: plugin.filterColumn >= 0 && plugin.filterColumn < plugin.columns.length
               ? qsTr("Filtrer — %1").arg(plugin.columns[plugin.filterColumn].alias || plugin.columns[plugin.filterColumn].fieldName)
               : qsTr("Valeurs distinctes")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(700, parent.width * 0.72) : 820
        height: parent ? Math.max(620, parent.height * 0.82) : 720
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0
        onRejected: plugin.pendingDistinctKeys = plugin.cloneSelection(plugin.selectedDistinctKeys)

        contentItem: ColumnLayout {
            spacing: 8

            TextField {
                id: distinctSearchField
                Layout.fillWidth: true
                placeholderText: qsTr("Rechercher dans les valeurs…")
                onTextChanged: {
                    plugin.distinctSearchText = text
                    plugin.filterDistinctList()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Tout"); onClicked: plugin.setAllPendingDistinct(true) }
                Button { text: qsTr("Aucun"); onClicked: plugin.setAllPendingDistinct(false) }
                Button { text: qsTr("Inverser"); onClicked: plugin.invertPendingDistinct() }
                Item { Layout.fillWidth: true }
                Label {
                    text: qsTr("%1 sélectionnée(s) — %2 résultat(s) sur %3 chargé(s)")
                          .arg(plugin.pendingDistinctCount()).arg(plugin.pendingResultCount()).arg(plugin.flatRows.length)
                    font.bold: true
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightGray }

            ListView {
                id: distinctListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: plugin.visibleDistinctValues
                spacing: 2
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(0, distinctListView.width - 18)
                    height: 42
                    color: index % 2 ? "#f6f6f6" : "transparent"
                    border.width: 1
                    border.color: Theme.lightGray

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        CheckBox {
                            checked: plugin.pendingDistinctKeys[modelData.key] === true
                            onToggled: plugin.updatePendingDistinct(modelData.key, checked)
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.label
                            elide: Text.ElideRight
                            ToolTip.visible: valueMouse.containsMouse
                            ToolTip.text: modelData.label
                            MouseArea { id: valueMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                        }
                        Label {
                            text: String(modelData.count)
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 70
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Comptages calculés sur les %1 enregistrements chargés.").arg(plugin.flatRows.length)
                    opacity: 0.65
                }
                Button { text: qsTr("Annuler"); onClicked: plugin.cancelPendingDistinct() }
                Button { text: qsTr("Appliquer"); onClicked: plugin.applyPendingDistinct() }
            }
        }
    }


    QfDialog {
        id: columnManagerDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Colonnes affichées et ordre")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(1050, parent.width * 0.90) : 1200
        height: parent ? Math.max(700, parent.height * 0.88) : 800
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                TextField {
                    Layout.fillWidth: true
                    placeholderText: qsTr("Rechercher parmi tous les champs…")
                    onTextChanged: {
                        plugin.columnSearchText = text
                        plugin.filterColumnManagerItems()
                    }
                }

                Label {
                    text: qsTr("%1 colonne(s) sélectionnée(s)").arg(plugin.visibleColumnCount())
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Tout"); onClicked: plugin.setAllPendingColumnsVisible(true) }
                Button { text: qsTr("Aucun"); onClicked: plugin.setAllPendingColumnsVisible(false) }
                Button { text: qsTr("Inverser"); onClicked: plugin.invertPendingColumns() }
                Button { text: qsTr("Réinitialiser"); onClicked: plugin.resetPendingColumns() }
                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    border.width: 1
                    border.color: Theme.lightGray
                    color: "transparent"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Label {
                            text: qsTr("Champs disponibles")
                            font.bold: true
                            font.pixelSize: 18
                        }
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Cochez ou décochez les champs à afficher.")
                            opacity: 0.65
                        }

                        ListView {
                            id: columnManagerList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: plugin.visibleColumnManagerItems
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

                            delegate: Rectangle {
                                required property var modelData
                                width: Math.max(0, columnManagerList.width - 18)
                                height: 50
                                border.width: 1
                                border.color: Theme.lightGray
                                color: index % 2 ? "#f7f7f7" : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8

                                    CheckBox {
                                        checked: plugin.pendingColumnVisibility[
                                                     String(modelData.originalIndex)] !== false
                                        onToggled:
                                            plugin.setPendingColumnVisible(
                                                Number(modelData.originalIndex), checked)
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.fieldName
                                            opacity: 0.65
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    border.width: 1
                    border.color: Theme.lightGray
                    color: "transparent"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Label {
                            text: qsTr("Colonnes affichées — ordre")
                            font.bold: true
                            font.pixelSize: 18
                        }
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Seuls les champs cochés apparaissent ici. Faites glisser ≡ pour les réordonner.")
                            opacity: 0.65
                            wrapMode: Text.WordWrap
                        }

                        ListView {
                            id: selectedOrderList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: plugin.selectedColumnManagerItems
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

                            Rectangle {
                                parent: selectedOrderList.contentItem
                                visible: plugin.selectedDragIndicatorY >= 0
                                x: 4
                                y: plugin.selectedDragIndicatorY - 2
                                width: Math.max(0, selectedOrderList.width - 28)
                                height: 4
                                radius: 2
                                color: Theme.mainColor
                                z: 1000
                            }

                            delegate: Rectangle {
                                id: selectedRow
                                required property var modelData
                                width: Math.max(0, selectedOrderList.width - 18)
                                height: 50
                                border.width: 1
                                border.color: Theme.lightGray
                                color: plugin.selectedDragOriginalIndex ===
                                       Number(modelData.originalIndex)
                                       ? "#dcefdc"
                                       : (index % 2 ? "#f7f7f7" : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    Rectangle {
                                        Layout.preferredWidth: 42
                                        Layout.fillHeight: true
                                        color: "transparent"

                                        Label {
                                            anchors.centerIn: parent
                                            text: "≡"
                                            font.pixelSize: 27
                                            color: Theme.mainColor
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            cursorShape: Qt.SizeVerCursor
                                            preventStealing: true
                                            propagateComposedEvents: false

                                            function updateDrop(mx, my) {
                                                var p = mapToItem(
                                                    selectedOrderList.contentItem, mx, my)
                                                plugin.updateSelectedColumnDrag(p.y)
                                            }

                                            onPressed: function(mouse) {
                                                plugin.beginSelectedColumnDrag(
                                                    Number(modelData.originalIndex))
                                                updateDrop(mouse.x, mouse.y)
                                            }
                                            onPositionChanged: function(mouse) {
                                                if (pressed) updateDrop(mouse.x, mouse.y)
                                            }
                                            onReleased: plugin.finishSelectedColumnDrag()
                                            onCanceled: plugin.cancelSelectedColumnDrag()
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.fieldName
                                            opacity: 0.65
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Button {
                                        text: "▲"
                                        onClicked:
                                            plugin.movePendingColumn(
                                                Number(modelData.originalIndex), -1)
                                    }
                                    Button {
                                        text: "▼"
                                        onClicked:
                                            plugin.movePendingColumn(
                                                Number(modelData.originalIndex), 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Annuler"); onClicked: plugin.cancelPendingColumns() }
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Appliquer"); onClicked: plugin.applyPendingColumns() }
            }
        }
    }


    Dialog {
        id: saveSharedViewDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Enregistrer une vue partagée")
        standardButtons: Dialog.NoButton
        width: parent ? Math.min(640, parent.width * 0.90) : 640

        onOpened: {
            sharedViewTitleInput.text = ""
            sharedViewMessageInput.text = ""
            sharedViewInitialStatus.currentIndex = 0
            plugin.sharedViewsError = ""
        }

        contentItem: ColumnLayout {
            spacing: 10

            Label {
                text: qsTr("Titre")
                font.bold: true
            }

            TextField {
                id: sharedViewTitleInput
                Layout.fillWidth: true
                placeholderText: qsTr("Ex. Vérifier les adresses incomplètes")
            }

            Label {
                text: qsTr("Message / consignes")
                font.bold: true
            }

            TextArea {
                id: sharedViewMessageInput
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                wrapMode: TextEdit.Wrap
                placeholderText:
                    qsTr("Décrivez les vérifications ou modifications à effectuer.")
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: qsTr("Statut initial")
                    Layout.fillWidth: true
                }

                ComboBox {
                    id: sharedViewInitialStatus
                    model: ["À faire", "En cours", "Terminé", "Archivé"]
                }
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.sharedViewsError.length > 0
                text: plugin.sharedViewsError
                color: Theme.errorColor
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Annuler")
                    onClicked: saveSharedViewDialog.close()
                }

                Button {
                    text: qsTr("Enregistrer")
                    font.bold: true
                    onClicked: {
                        if (plugin.createSharedView(
                                    sharedViewTitleInput.text,
                                    sharedViewMessageInput.text,
                                    sharedViewInitialStatus.currentText)) {
                            saveSharedViewDialog.close()
                            plugin.loadSharedViews()
                            sharedViewsDialog.open()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: sharedViewsDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Vues partagées")
        standardButtons: Dialog.NoButton
        width: parent ? Math.min(760, parent.width * 0.92) : 760

        onOpened: {
            plugin.loadSharedViews()
            Qt.callLater(function() {
                plugin.synchronizeSharedViewSelection()
            })
        }

        contentItem: ColumnLayout {
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                ComboBox {
                    id: sharedViewsCombo
                    Layout.fillWidth: true
                    model: sharedViewsListModel
                    textRole: "label"

                    onCurrentIndexChanged: {
                        Qt.callLater(function() {
                            plugin.synchronizeSharedViewSelection()
                        })
                    }
                }

                Button {
                    text: qsTr("Recharger")
                    onClicked: {
                        plugin.loadSharedViews()
                        Qt.callLater(function() {
                            plugin.synchronizeSharedViewSelection()
                        })
                    }
                }
            }


            Label {
                Layout.fillWidth: true
                text: qsTr("%1 vue(s) partagée(s) disponible(s)")
                      .arg(sharedViewsListModel.count)
                font.bold: true
            }

            Label {
                Layout.fillWidth: true
                text: {
                    var item = plugin.selectedSharedView()
                    return item
                           ? qsTr("Couche : %1   •   Auteur : %2")
                             .arg(item.layerName)
                             .arg(item.author)
                           : ""
                }
                opacity: 0.70
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                text: {
                    var item = plugin.selectedSharedView()
                    return item ? String(item.message || "") : ""
                }
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: qsTr("Statut")
                }

                ComboBox {
                    id: sharedViewStatusCombo
                    model: ["À faire", "En cours", "Terminé", "Archivé"]

                    onActivated: {
                        plugin.updateSelectedSharedViewStatus(currentText)
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Appliquer la vue")
                    enabled: sharedViewsListModel.count > 0
                    onClicked: {
                        if (plugin.applySelectedSharedView())
                            sharedViewsDialog.close()
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.sharedViewsError.length > 0
                text: plugin.sharedViewsError
                color: Theme.errorColor
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                Button {
                    text: qsTr("+ Nouvelle vue")
                    onClicked: {
                        sharedViewsDialog.close()
                        saveSharedViewDialog.open()
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Fermer")
                    onClicked: sharedViewsDialog.close()
                }
            }
        }
    }

    Dialog {
        id: shareDialog
        parent: mainWindow.contentItem
        modal: true
        title: qsTr("Partager / importer une vue")
        standardButtons: Dialog.NoButton
        width: parent ? Math.max(700,parent.width*0.70) : 800
        height: parent ? Math.max(520,parent.height*0.68) : 620
        x: parent ? (parent.width-width)/2 : 0
        y: parent ? (parent.height-height)/2 : 0
        contentItem: ColumnLayout {
            spacing: 8
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Ce code contient les filtres actifs ainsi que les colonnes affichées et leur ordre. Copiez-le pour le transmettre à un autre utilisateur, ou remplacez le contenu par un code reçu puis cliquez sur Importer.")
            }
            TextArea {
                id: shareText
                Layout.fillWidth: true
                Layout.fillHeight: true
                wrapMode: TextEdit.NoWrap
                selectByMouse: true
            }
            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Copier"); onClicked: { shareText.selectAll(); shareText.copy() } }
                Button { text: qsTr("Importer"); onClicked: { if(plugin.importSharedViewCode(shareText.text)) shareDialog.close() } }
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Fermer"); onClicked: shareDialog.close() }
            }
        }
    }

}
