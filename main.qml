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
    // Formulaire natif de QField. On le réutilise au lieu de recréer un formulaire dans le plugin.
    property var overlayFeatureFormDrawer: iface.findItemByObjectName("overlayFeatureFormDrawer")
    property bool waitingForFeatureForm: false
    property string editingFeatureId: ""
    property real savedTableContentY: 0
    property real savedTableHorizontalOffset: 0

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
    property var distinctValues: []
    property var visibleDistinctValues: []
    property var selectedDistinctKeys: ({})
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
        } catch (e1) { console.log("QField Table v0.6.1 mapLayers: " + e1) }

        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) for (var j = 0; j < canvasLayers.length; ++j) appendCandidate(canvasLayers[j], seen)
        } catch (e2) { console.log("QField Table v0.6.1 canvas layers: " + e2) }

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
        distinctValues = []
        visibleDistinctValues = []
        selectedDistinctKeys = ({})
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
            console.log("QField Table v0.6.1 iterator: " + error)
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
        restoreColumnConfiguration()
        refreshDisplayedColumns()
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
            console.log("QField Table v0.6.1 configuration invalide: " + e)
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
            console.log("QField Table v0.6.1 lecture propriété couche: " + e)
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
            console.log("QField Table v0.6.1 sauvegarde propriété couche: " + e)
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
            visibility[String(k)] = hidden[columnPersistentName(k)] !== true

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
                visibility[String(c)] = true
            }
            columnOrder = order
            columnVisibility = visibility
        } else {
            var normalized = ({})
            for (var j = 0; j < columns.length; ++j)
                normalized[String(j)] = columnVisibility[String(j)] !== false
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
            if (!source) continue
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
        for (var key in columnVisibility) pendingColumnVisibility[key] = columnVisibility[key] !== false
        columnSearchText = ""
        filterColumnManagerItems()
        columnManagerDialog.open()
    }

    function filterColumnManagerItems() {
        var needle = String(columnSearchText || "").toLowerCase().trim()
        var result = []
        for (var p = 0; p < pendingColumnOrder.length; ++p) {
            var originalIndex = Number(pendingColumnOrder[p])
            var col = columns[originalIndex]
            if (!col) continue
            var label = col.alias || col.fieldName || qsTr("Champ")
            var haystack = (String(label) + " " + String(col.fieldName || "")).toLowerCase()
            if (needle.length === 0 || haystack.indexOf(needle) >= 0)
                result.push({ "originalIndex": originalIndex, "position": p, "label": label, "fieldName": col.fieldName || "" })
        }
        visibleColumnManagerItems = result
    }

    function setPendingColumnVisible(originalIndex, checked) {
        var copy = ({})
        for (var key in pendingColumnVisibility) copy[key] = pendingColumnVisibility[key] !== false
        copy[String(originalIndex)] = checked
        pendingColumnVisibility = copy
    }

    function setAllPendingColumnsVisible(checked) {
        var copy = ({})
        for (var i = 0; i < columns.length; ++i) copy[String(i)] = checked
        pendingColumnVisibility = copy
    }

    function invertPendingColumns() {
        var copy = ({})
        for (var i = 0; i < columns.length; ++i) copy[String(i)] = pendingColumnVisibility[String(i)] === false
        pendingColumnVisibility = copy
    }

    function movePendingColumn(originalIndex, direction) {
        var order = cloneArray(pendingColumnOrder)
        var position = order.indexOf(originalIndex)
        if (position < 0) position = order.indexOf(String(originalIndex))
        var target = position + direction
        if (position < 0 || target < 0 || target >= order.length) return
        var tmp = order[position]
        order[position] = order[target]
        order[target] = tmp
        pendingColumnOrder = order
        filterColumnManagerItems()
    }

    function resetPendingColumns() {
        var order = []
        var visibility = ({})
        for (var i = 0; i < columns.length; ++i) { order.push(i); visibility[String(i)] = true }
        pendingColumnOrder = order
        pendingColumnVisibility = visibility
        filterColumnManagerItems()
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
        var value = row.values[filterColumn]
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
            var value = flatRows[i].values[filterColumn]
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
                for (var c = 0; c < row.values.length; ++c) {
                    if (String(row.values[c]).toLowerCase().indexOf(term) >= 0) { globalMatch = true; break }
                }
            }
            if (globalMatch && pendingDistinctKeys[distinctKey(row.values[filterColumn])] === true) count++
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

    function findFreshFeature(featureIdValue) {
        if (!selectedLayer) return null
        var wanted = String(featureIdValue)
        try {
            var iterator = LayerUtils.createFeatureIterator(selectedLayer)
            while (iterator.hasNext()) {
                var feature = iterator.next()
                if (featureId(feature) === wanted) return feature
            }
        } catch (error) {
            console.log("QField Table v0.6.1 findFreshFeature: " + error)
        }
        return null
    }

    function refreshFeatureRow(featureIdValue) {
        var freshFeature = findFreshFeature(featureIdValue)
        if (!freshFeature || columns.length === 0) return

        // Remplace aussi l'objet QgsFeature conservé dans l'aperçu.
        var featureCopy = previewFeatures.slice(0)
        for (var p = 0; p < featureCopy.length; ++p) {
            if (featureId(featureCopy[p]) === String(featureIdValue)) {
                featureCopy[p] = freshFeature
                previewFeatures = featureCopy
                break
            }
        }

        var newValues = []
        for (var c = 0; c < columns.length; ++c)
            newValues.push(readAttribute(freshFeature, columns[c]))

        var rowsCopy = flatRows.slice(0)
        var replaced = false
        for (var r = 0; r < rowsCopy.length; ++r) {
            if (String(rowsCopy[r].featureId) === String(featureIdValue)) {
                rowsCopy[r] = { "featureId": String(featureIdValue), "values": newValues }
                replaced = true
                break
            }
        }
        if (replaced) flatRows = rowsCopy
        applyView()

        // Actualise aussi la valeur actuellement affichée dans l'inspecteur.
        if (selectedFeatureId === String(featureIdValue) && selectedCellColumn >= 0 && selectedCellColumn < newValues.length)
            selectedCellValue = formatValue(newValues[selectedCellColumn])
    }

    function openFeatureForm(featureIdValue) {
        if (!selectedLayer) return
        var idText = String(featureIdValue || selectedFeatureId)
        if (!idText || idText.length === 0) return

        var freshFeature = findFreshFeature(idText)
        if (!freshFeature) {
            diagnosticMessage = qsTr("Impossible de retrouver l’entité %1 dans la couche.").arg(idText)
            return
        }

        if (!overlayFeatureFormDrawer) {
            diagnosticMessage = qsTr("Le formulaire natif de QField n’est pas accessible dans cette version.")
            return
        }

        try {
            savedTableHorizontalOffset = horizontalOffset
            try { savedTableContentY = rowsFlick.contentY } catch (scrollError) { savedTableContentY = 0 }
            editingFeatureId = idText
            waitingForFeatureForm = true

            // Le FeatureModel du tiroir accepte explicitement currentLayer et feature.
            overlayFeatureFormDrawer.featureModel.currentLayer = selectedLayer
            try { overlayFeatureFormDrawer.featureModel.project = qgisProject } catch (projectError) {}
            overlayFeatureFormDrawer.featureModel.feature = freshFeature
            overlayFeatureFormDrawer.state = "Edit"

            // Libère la fenêtre de la table pendant que le formulaire natif est affiché.
            browserDialog.close()
            overlayFeatureFormDrawer.open()
        } catch (error) {
            waitingForFeatureForm = false
            diagnosticMessage = qsTr("Impossible d’ouvrir le formulaire : %1").arg(String(error))
            console.log("QField Table v0.6.1 openFeatureForm: " + error)
            browserDialog.open()
        }
    }

    function finishFeatureFormRoundTrip() {
        if (!waitingForFeatureForm) return
        var idText = editingFeatureId
        waitingForFeatureForm = false
        editingFeatureId = ""

        refreshFeatureRow(idText)
        horizontalOffset = savedTableHorizontalOffset
        browserDialog.open()
        restoreTablePositionTimer.restart()
    }

    function saveAndReturnFromFeatureForm() {
        if (!waitingForFeatureForm || !overlayFeatureFormDrawer || !overlayFeatureFormDrawer.featureForm) return
        try {
            overlayFeatureFormDrawer.featureForm.confirm()
        } catch (error) {
            diagnosticMessage = qsTr("Impossible d’enregistrer le formulaire : %1").arg(String(error))
            console.log("QField Table v0.6.1 confirm feature form: " + error)
        }
    }

    function cancelAndReturnFromFeatureForm() {
        if (!waitingForFeatureForm || !overlayFeatureFormDrawer || !overlayFeatureFormDrawer.featureForm) return
        try {
            // requestCancel() respecte le comportement QField : confirmation si nécessaire,
            // ou annulation immédiate lorsque l’autosauvegarde est active.
            overlayFeatureFormDrawer.featureForm.requestCancel()
        } catch (error) {
            // Solution de secours : fermer le tiroir. QField gérera alors son cycle normal.
            try { overlayFeatureFormDrawer.close() } catch (closeError) {}
            console.log("QField Table v0.6.1 cancel feature form: " + error)
        }
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
        if (columnFilterText) columnFilterText.text = ""
        if (filterModeCombo) filterModeCombo.currentIndex = 1
        applyView()
    }

    function openBrowser() {
        // Une simple fermeture du dialogue ne détruit pas le plugin.
        // On conserve donc le modèle déjà construit afin d’éviter de vider
        // les colonnes alors que les délégués du FeatureModel existent encore.
        if (needsProjectRefresh || !selectedLayer || vectorLayers.length === 0 || columns.length === 0 || flatRows.length === 0) {
            needsProjectRefresh = false
            refreshLayers()
        }
        browserDialog.open()
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.6.1 chargé")
    }

    Connections {
        target: iface
        function onLoadProjectEnded() {
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

    Timer {
        id: restoreTablePositionTimer
        interval: 80
        repeat: false
        onTriggered: {
            plugin.horizontalOffset = plugin.savedTableHorizontalOffset
            try { rowsFlick.contentY = plugin.savedTableContentY } catch (e) {}
        }
    }

    Connections {
        target: plugin.overlayFeatureFormDrawer
        ignoreUnknownSignals: true
        function onOpenedChanged() {
            if (plugin.waitingForFeatureForm && plugin.overlayFeatureFormDrawer && !plugin.overlayFeatureFormDrawer.opened)
                plugin.finishFeatureFormRoundTrip()
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
        title: qsTr("QField Table — v0.6.1")
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
                        if (plugin.filterMode === "values") plugin.rebuildDistinctValues()
                        plugin.applyView()
                    }
                }
                ComboBox {
                    id: filterModeCombo
                    Layout.preferredWidth: 170
                    model: [qsTr("Valeurs distinctes…"), qsTr("Contient"), qsTr("Égale"), qsTr("Est vide"), qsTr("N'est pas vide")]
                    currentIndex: 1
                    onActivated: {
                        if (currentIndex === 0) {
                            plugin.openDistinctFilter()
                        } else {
                            plugin.filterMode = currentIndex === 2 ? "equals" : currentIndex === 3 ? "empty" : currentIndex === 4 ? "notempty" : "contains"
                            plugin.applyView()
                        }
                    }
                }
                TextField {
                    id: columnFilterText
                    Layout.fillWidth: true
                    visible: plugin.filterMode !== "values"
                    enabled: plugin.filterMode === "contains" || plugin.filterMode === "equals"
                    placeholderText: qsTr("Valeur à rechercher…")
                    onTextChanged: {
                        plugin.filterText = text
                        searchTimer.restart()
                    }
                }
                Button {
                    visible: plugin.filterMode === "values"
                    Layout.fillWidth: true
                    text: qsTr("%1 valeur(s) sélectionnée(s) — %2 résultat(s)")
                          .arg(plugin.selectedDistinctCount()).arg(plugin.filteredRows.length)
                    onClicked: plugin.reopenDistinctFilter()
                }
                Button { text: qsTr("Effacer"); onClicked: plugin.clearColumnFilter() }
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
                            model: Math.min(plugin.frozenColumnCount, plugin.displayedColumns.length)
                            delegate: Rectangle {
                                required property int index
                                property var columnData: plugin.displayedColumns[index]
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
                                                       + (plugin.sortColumn === columnData.originalIndex ? (plugin.sortAscending ? " ▲" : " ▼") : "") : ""
                                }
                                ToolTip.visible: frozenHeaderMouse.containsMouse
                                ToolTip.text: columnData ? qsTr("%1 — cliquer pour trier").arg(columnData.fieldName) : ""
                                MouseArea {
                                    id: frozenHeaderMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: plugin.toggleSort(columnData.originalIndex)
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
                                                           + (plugin.sortColumn === columnData.originalIndex ? (plugin.sortAscending ? " ▲" : " ▼") : "") : ""
                                    }
                                    ToolTip.visible: scrollingHeaderMouse.containsMouse
                                    ToolTip.text: columnData ? qsTr("%1 — cliquer pour trier").arg(columnData.fieldName) : ""
                                    MouseArea {
                                        id: scrollingHeaderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: plugin.toggleSort(columnData.originalIndex)
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
                                            onDoubleClicked: {
                                                plugin.selectCell(modelData.featureId, -1, modelData.featureId)
                                                plugin.openFeatureForm(modelData.featureId)
                                            }
                                            onPressAndHold: plugin.selectCell(modelData.featureId, -1, modelData.featureId)
                                        }
                                    }

                                    Repeater {
                                        model: Math.min(plugin.frozenColumnCount, plugin.displayedColumns.length)
                                        delegate: Rectangle {
                                            required property int index
                                            property var columnData: plugin.displayedColumns[index]
                                            property string cellValue: columnData && modelData.values[columnData.originalIndex] !== undefined ? String(modelData.values[columnData.originalIndex]) : ""
                                            width: columnData ? columnData.width : 140
                                            height: frozenCellsRow.height
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
                                            ToolTip.visible: frozenCellMouse.containsMouse
                                            ToolTip.text: cellValue
                                            MouseArea {
                                                id: frozenCellMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                pressAndHoldInterval: 500
                                                onClicked: plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
                                                onDoubleClicked: {
                                                    plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
                                                    plugin.openFeatureForm(modelData.featureId)
                                                }
                                                onPressAndHold: plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
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
                                            model: Math.max(0, plugin.displayedColumns.length - plugin.frozenColumnCount)
                                            delegate: Rectangle {
                                                required property int index
                                                property int actualIndex: index + plugin.frozenColumnCount
                                                property var columnData: plugin.displayedColumns[actualIndex]
                                                property string cellValue: columnData && modelData.values[columnData.originalIndex] !== undefined ? String(modelData.values[columnData.originalIndex]) : ""
                                                width: columnData ? columnData.width : 140
                                                height: scrollingCellsViewport.height
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
                                                ToolTip.visible: scrollingCellMouse.containsMouse
                                                ToolTip.text: cellValue
                                                MouseArea {
                                                    id: scrollingCellMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    pressAndHoldInterval: 500
                                                    onClicked: plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
                                                onDoubleClicked: {
                                                    plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
                                                    plugin.openFeatureForm(modelData.featureId)
                                                }
                                                    onPressAndHold: plugin.selectCell(modelData.featureId, columnData.originalIndex, cellValue)
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
                            text: qsTr("Modifier")
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Ouvrir le formulaire QField de cette entité")
                            onClicked: plugin.openFeatureForm(plugin.selectedFeatureId)
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

    // Barre de retour affichée uniquement lorsqu’un formulaire QField a été ouvert
    // depuis QField Table. Le formulaire natif reste entièrement utilisé pour l’édition.
    Rectangle {
        id: featureFormReturnBar
        parent: plugin.mainWindow ? plugin.mainWindow.contentItem : plugin
        z: 1000000
        visible: plugin.waitingForFeatureForm
                 && plugin.overlayFeatureFormDrawer
                 && plugin.overlayFeatureFormDrawer.opened
        width: returnButtons.implicitWidth + 20
        height: returnButtons.implicitHeight + 16
        radius: 6
        color: Theme.mainBackgroundColor
        border.width: 1
        border.color: Theme.lightGray
        anchors.right: parent ? parent.right : undefined
        anchors.bottom: parent ? parent.bottom : undefined
        anchors.rightMargin: 18
        anchors.bottomMargin: 18

        RowLayout {
            id: returnButtons
            anchors.centerIn: parent
            spacing: 8

            Button {
                text: qsTr("Annuler et revenir")
                onClicked: plugin.cancelAndReturnFromFeatureForm()
            }

            Button {
                text: qsTr("Enregistrer et revenir")
                highlighted: true
                onClicked: plugin.saveAndReturnFromFeatureForm()
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
        width: parent ? Math.max(760, parent.width * 0.76) : 900
        height: parent ? Math.max(650, parent.height * 0.84) : 760
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        contentItem: ColumnLayout {
            spacing: 8

            TextField {
                Layout.fillWidth: true
                placeholderText: qsTr("Rechercher un champ ou un nom technique…")
                onTextChanged: {
                    plugin.columnSearchText = text
                    plugin.filterColumnManagerItems()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Tout"); onClicked: plugin.setAllPendingColumnsVisible(true) }
                Button { text: qsTr("Aucun"); onClicked: plugin.setAllPendingColumnsVisible(false) }
                Button { text: qsTr("Inverser"); onClicked: plugin.invertPendingColumns() }
                Button { text: qsTr("Réinitialiser"); onClicked: plugin.resetPendingColumns() }
                Item { Layout.fillWidth: true }
                Label {
                    text: qsTr("%1 colonne(s) affichée(s) sur %2").arg(plugin.visibleColumnCount()).arg(plugin.columns.length)
                    font.bold: true
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Faites glisser la poignée ≡ pour déplacer un champ. Les flèches restent disponibles. La fenêtre reprend toujours la configuration actuelle. Cliquez sur Appliquer pour conserver l’ordre et la visibilité pour cette couche et ce projet.")
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                visible: plugin.columnSearchText.trim().length > 0
                text: qsTr("Effacez la recherche pour utiliser le glisser-déposer; les flèches restent actives.")
                color: Theme.warningColor
                wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.lightGray }

            ListView {
                id: columnManagerList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: plugin.visibleColumnManagerItems
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

                Rectangle {
                    parent: columnManagerList.contentItem
                    visible: plugin.columnDragIndicatorY >= 0
                    x: 4
                    y: plugin.columnDragIndicatorY - 2
                    width: Math.max(0, columnManagerList.width - 28)
                    height: 4
                    radius: 2
                    color: Theme.mainColor
                    z: 1000
                }

                delegate: Rectangle {
                    id: columnManagerRow
                    required property var modelData
                    width: Math.max(0, columnManagerList.width - 18)
                    height: 50
                    color: plugin.draggedColumnOriginalIndex === Number(modelData.originalIndex) ? "#dcefdc" : (index % 2 ? "#f6f6f6" : "transparent")
                    border.width: 1
                    border.color: Theme.lightGray

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.fillHeight: true
                            color: "transparent"
                            Label {
                                anchors.centerIn: parent
                                text: "≡"
                                font.pixelSize: 26
                                color: Theme.mainColor
                            }
                            MouseArea {
                                id: columnDragArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.SizeVerCursor
                                preventStealing: true
                                propagateComposedEvents: false

                                function updateDropPosition(mouseX, mouseY) {
                                    var point = mapToItem(columnManagerList.contentItem, mouseX, mouseY)
                                    plugin.updateColumnDrag(point.y)
                                }

                                onPressed: function(mouse) {
                                    mouse.accepted = true
                                    plugin.beginColumnDrag(modelData.originalIndex)
                                    if (plugin.draggedColumnOriginalIndex >= 0)
                                        updateDropPosition(mouse.x, mouse.y)
                                }
                                onPositionChanged: function(mouse) {
                                    if (plugin.draggedColumnOriginalIndex === Number(modelData.originalIndex)) {
                                        mouse.accepted = true
                                        updateDropPosition(mouse.x, mouse.y)
                                    }
                                }
                                onReleased: function(mouse) {
                                    mouse.accepted = true
                                    if (plugin.draggedColumnOriginalIndex === Number(modelData.originalIndex)) {
                                        updateDropPosition(mouse.x, mouse.y)
                                        plugin.finishColumnDrag()
                                    }
                                }
                                onCanceled: plugin.cancelColumnDrag()
                            }
                            ToolTip.visible: dragHandleHover.containsMouse
                            ToolTip.text: qsTr("Glisser pour déplacer")
                            MouseArea { id: dragHandleHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                        }

                        CheckBox {
                            checked: plugin.pendingColumnVisibility[String(modelData.originalIndex)] !== false
                            onToggled: plugin.setPendingColumnVisible(modelData.originalIndex, checked)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: modelData.label
                                font.bold: true
                                elide: Text.ElideRight
                                ToolTip.visible: columnNameMouse.containsMouse
                                ToolTip.text: modelData.label
                                MouseArea { id: columnNameMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.fieldName
                                opacity: 0.6
                                elide: Text.ElideRight
                            }
                        }

                        Label {
                            text: String(modelData.position + 1)
                            Layout.preferredWidth: 45
                            horizontalAlignment: Text.AlignRight
                            opacity: 0.65
                        }
                        Button {
                            text: "▲"
                            enabled: modelData.position > 0
                            onClicked: plugin.movePendingColumn(modelData.originalIndex, -1)
                        }
                        Button {
                            text: "▼"
                            enabled: modelData.position < plugin.pendingColumnOrder.length - 1
                            onClicked: plugin.movePendingColumn(modelData.originalIndex, 1)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Annuler"); onClicked: plugin.cancelPendingColumns() }
                Button { text: qsTr("Appliquer"); onClicked: plugin.applyPendingColumns() }
            }
        }
    }

}
