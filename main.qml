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
    property var tableFeatures: []
    property int totalFeatureCount: 0
    property string diagnosticMessage: ""

    property int rowHeight: 40
    property int idColumnWidth: 92
    property int dataColumnWidth: 190
    property int headerHeight: 54

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
        tableFeatures = []
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
            console.log("QField Table v0.3: qgisProject.mapLayers() indisponible: " + e1)
        }

        try {
            var canvasLayers = mapCanvas.mapSettings.layers
            if (canvasLayers) {
                for (var j = 0; j < canvasLayers.length; ++j)
                    appendCandidate(canvasLayers[j], seen)
            }
        } catch (e2) {
            console.log("QField Table v0.3: mapSettings.layers indisponible: " + e2)
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
        loadSelectedLayer()
    }

    function featureId(feature) {
        if (!feature) return "?"
        try {
            return String(typeof feature.id === "function" ? feature.id() : feature.id)
        } catch (e) {
            return "?"
        }
    }

    function formatValue(value) {
        if (value === null || value === undefined)
            return ""

        var text = String(value)
        if (text === "Invalid Date")
            return ""
        return text
    }

    function loadSelectedLayer() {
        tableFeatures = []
        totalFeatureCount = 0
        diagnosticMessage = ""

        if (!selectedLayer) return

        var found = []
        try {
            var iterator = LayerUtils.createFeatureIterator(selectedLayer)
            while (iterator.hasNext()) {
                var feature = iterator.next()
                found.push(feature)
            }
            tableFeatures = found
            totalFeatureCount = found.length
        } catch (error) {
            diagnosticMessage = String(error)
            console.log("QField Table v0.3: " + error)
        }

        statusLabel.text = qsTr("Couche : %1 — %2 enregistrement(s)")
                .arg(layerName(selectedLayer))
                .arg(totalFeatureCount)
    }

    function openBrowser() {
        refreshLayers()
        browserDialog.open()
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton)
        console.log("QField Table v0.3 chargé")
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
        title: qsTr("QField Table — v0.3")
        standardButtons: Dialog.Close

        width: Math.min(parent ? parent.width - 20 : 900, 1500)
        height: Math.min(parent ? parent.height - 20 : 720, 980)
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

            Item {
                id: tableArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                FeatureModel {
                    id: headerFeatureModel
                    currentLayer: plugin.selectedLayer
                    feature: plugin.tableFeatures.length > 0 ? plugin.tableFeatures[0] : null
                }

                property real fullTableWidth: plugin.idColumnWidth + headerFeatureModel.count * plugin.dataColumnWidth

                Flickable {
                    id: horizontalFlick
                    anchors.fill: parent
                    clip: true
                    contentWidth: Math.max(width, tableArea.fullTableWidth)
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.horizontal: ScrollBar { }

                    ListView {
                        id: tableList
                        width: Math.max(horizontalFlick.width, tableArea.fullTableWidth)
                        height: horizontalFlick.height
                        model: plugin.tableFeatures
                        clip: true
                        spacing: 0
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar { }

                        headerPositioning: ListView.OverlayHeader
                        header: Rectangle {
                            z: 5
                            width: tableList.width
                            height: plugin.headerHeight
                            color: Theme.mainBackgroundColor
                            border.color: Theme.lightGray

                            Row {
                                anchors.fill: parent

                                Rectangle {
                                    width: plugin.idColumnWidth
                                    height: parent.height
                                    color: Theme.mainBackgroundColor
                                    border.color: Theme.lightGray

                                    Label {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: qsTr("Entité")
                                        font.bold: true
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                Repeater {
                                    model: headerFeatureModel

                                    delegate: Rectangle {
                                        required property int index
                                        width: plugin.dataColumnWidth
                                        height: plugin.headerHeight
                                        color: Theme.mainBackgroundColor
                                        border.color: Theme.lightGray

                                        Label {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            text: model.AttributeName !== undefined ? String(model.AttributeName) : qsTr("Champ %1").arg(index + 1)
                                            font.bold: true
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }

                        delegate: Rectangle {
                            id: tableRow
                            required property var modelData
                            property var featureObject: modelData
                            width: tableList.width
                            height: plugin.rowHeight
                            color: index % 2 === 0 ? Theme.mainBackgroundColor : Theme.mainBackgroundColorAlternate
                            border.color: Theme.lightGray

                            FeatureModel {
                                id: rowFeatureModel
                                currentLayer: plugin.selectedLayer
                                feature: tableRow.featureObject
                            }

                            Row {
                                anchors.fill: parent

                                Rectangle {
                                    width: plugin.idColumnWidth
                                    height: parent.height
                                    color: "transparent"
                                    border.color: Theme.lightGray

                                    Label {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: plugin.featureId(tableRow.featureObject)
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                Repeater {
                                    model: rowFeatureModel

                                    delegate: Rectangle {
                                        width: plugin.dataColumnWidth
                                        height: plugin.rowHeight
                                        color: "transparent"
                                        border.color: Theme.lightGray

                                        Label {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            text: plugin.formatValue(model.AttributeValue)
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                            clip: true

                                            ToolTip.visible: cellMouse.containsMouse && text.length > 0
                                            ToolTip.text: text

                                            MouseArea {
                                                id: cellMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.NoButton
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        footer: Label {
                            width: tableList.width
                            visible: plugin.tableFeatures.length === 0 && plugin.diagnosticMessage.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("Aucun enregistrement à afficher.")
                            padding: 16
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Lecture seule — faites défiler horizontalement pour consulter tous les champs.")
                opacity: 0.7
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
