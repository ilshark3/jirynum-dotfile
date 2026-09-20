import QtQuick
import Qt5Compat.GraphicalEffects
import "../config"

// Icône monochrome teintée (Image + ColorOverlay), avec rotation animée
// optionnelle et clic optionnel. Remplace le pattern répété partout dans
// ControlPanel.qml : Image { visible: false } + ColorOverlay + MouseArea.
Item {
    id: root

    // --- API publique ---
    property alias source: img.source
    property color iconColor: Colors.subtext1
    property bool rotated: false          // ex: audioOutInItem.outputMenuOpen
    property real rotatedAngle: 180
    property int rotationDuration: 200
    property bool clickable: true         // false pour une icône purement décorative

    signal clicked()

    // --- Rotation animée sur le composant entier, jamais sur le ColorOverlay ---
    // (tourner directement un ColorOverlay casse son rendu, cf. bug rencontré)
    rotation: root.rotated ? root.rotatedAngle : 0
    transformOrigin: Item.Center

    Behavior on rotation {
        NumberAnimation {
            duration: root.rotationDuration
            easing.type: Easing.OutCubic
        }
    }

    Image {
        id: img
        anchors.fill: parent
        visible: false
        sourceSize.width: width
        sourceSize.height: height
    }

    ColorOverlay {
        anchors.fill: img
        source: img
        color: root.iconColor
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
