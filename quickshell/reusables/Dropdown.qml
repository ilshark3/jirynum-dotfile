import QtQuick
import "../config"

// Bouton + liste déroulante animée. Remplace le duplicata quasi-identique
// entre outPutAudio et inPutAudio dans ControlPanel.qml (~150 lignes x2).
Item {
    id: root

    // --- API publique ---
    property var model: []              // liste d'objets { name: "...", ... }
    property string displayText: "No selection"
    property string iconSource: ""      // icône de gauche, optionnelle
    property bool open: false
    property string emptyText: "No items"

    signal itemSelected(var item)
    signal toggleRequested()   // le parent décide d'ouvrir/fermer (ex: exclusion mutuelle entre 2 dropdowns)

    height: 50

    // --- Bouton fermé ---
    Card {
        id: closedRow
        anchors.fill: parent

        Item {
            id: iconArea
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.2
            visible: root.iconSource !== ""

            IconButton {
                anchors.centerIn: parent
                width: parent.width * 0.75
                height: width
                source: root.iconSource
                clickable: false
            }
        }

        Text {
            anchors.left: root.iconSource !== "" ? iconArea.right : parent.left
            anchors.leftMargin: root.iconSource !== "" ? 0 : 10
            anchors.right: arrowArea.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            verticalAlignment: Text.AlignVCenter
            text: root.displayText
            color: Colors.text
            font.family: "JetBrains Mono"
            font.pixelSize: 13
            font.bold: true
            elide: Text.ElideRight
        }

        Item {
            id: arrowArea
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.15

            IconButton {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                source: "../icons/down-arrow.svg"
                rotated: root.open
                onClicked: root.toggleRequested()
            }
        }
    }

    // --- Liste déroulante ---
    Card {
        id: listBg
        visible: opacity > 0
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.92
        transformOrigin: Item.Top

        anchors.top: closedRow.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        width: parent.width
        height: Math.min(Math.max(listView.contentHeight + 10, 40), 180)

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        ListView {
            id: listView
            anchors.fill: parent
            anchors.margins: 5
            clip: true
            spacing: 3
            model: root.model

            delegate: Rectangle {
                width: listView.width
                height: 34
                radius: Variables.radiusO
                color: itemMouse.containsMouse ? Colors.surface2 : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: Colors.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                    font.bold: true
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.itemSelected(modelData)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: root.emptyText
                color: Colors.subtext0
                font.family: "JetBrains Mono"
                font.pixelSize: 10
            }
        }
    }
}
