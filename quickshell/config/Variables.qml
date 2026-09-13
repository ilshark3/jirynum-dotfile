pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

QtObject {
    property int barHeight: 45;
    property int sectionsHeight: barHeight - 10;
    property int radiusO: 15;
    property int rightHeight: sectionsHeight -4;
    property bool panelOpen: false
    property int panelWidth: 450
    property int panelOffset: panelOpen ? panelWidth + 5 : 0

    property var sink: Pipewire.defaultAudioSink
    property real level: sink?.audio?.volume ?? 0

    property string profilePicture: "file:///home/ilshark3_tests/Pictures/pfps/anim-g.jpg"
}