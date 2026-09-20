import QtQuick
import "../config"

// Rectangle thémé standard (radius + border + fond), avec état de survol
// animé optionnel. Remplace le pattern répété partout dans ControlPanel.qml :
// Rectangle { radius: Variables.radiusO; color: Colors.surface1; border... }
Rectangle {
    id: root

    property bool hoverable: false
    property color baseColor: Colors.surface1
    property color hoverColor: Colors.surface2

    // Exposé pour qu'un enfant externe (ex: un bouton "fermer" qui
    // n'apparaît qu'au survol de la card) puisse s'y accrocher via
    // `card.hovered`, puisque l'id interne cardMouse n'est pas visible
    // depuis l'extérieur du composant.
    readonly property alias hovered: cardMouse.containsMouse

    radius: Variables.radiusO
    color: root.hoverable && cardMouse.containsMouse ? root.hoverColor : root.baseColor
    border.width: 2
    border.color: Colors.surface2

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: root.hoverable
        acceptedButtons: Qt.NoButton // ne vole pas les clics des enfants, juste le hover
    }
}
