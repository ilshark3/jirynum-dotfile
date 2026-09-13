import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Services.Pipewire

import Qt5Compat.GraphicalEffects

import "../config"

PanelWindow {
    id: bar
    implicitHeight: Variables.barHeight
    color: "transparent"

    property var panel: null

    anchors {
        top: true
        left: true
        right: true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Rectangle {
        id: mainBarContainer
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5 + Variables.panelOffset 
        anchors.topMargin: 4
        color: Colors.base
        radius: Variables.radiusO

        Item {
            id: mainBarGestion
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6

            Row {
                id: leftSection
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 

                Rectangle {
                    id: workspaces
                    width: 60
                    height: Variables.sectionsHeight
                    color: Colors.surface0
                    radius: Variables.radiusO
                    border.width: 1
                    border.color: Colors.surface1
                }

                Rectangle {
                    id: mediaPlayer
                    width: 60
                    height: Variables.sectionsHeight
                    color: Colors.surface0
                    radius: Variables.radiusO
                    border.width: 1
                    border.color: Colors.surface1
                }
            } 

            Row {
                id: centerSection
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 

                Rectangle {
                    id: clockDate
                    width: Math.max(clockText.width, dateText.width) + 28
                    height: Variables.sectionsHeight
                    color: Colors.surface0
                    radius: Variables.radiusO
                    border.width: 1
                    border.color: Colors.surface1
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            id: clockText
                            anchors.left: parent.left
                            text: Qt.formatDateTime(clock.date, "hh:mm:ss")
                            color: Colors.text
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "JetBrains Mono"
                        }

                        Text {
                            id: dateText
                            anchors.left: parent.left
                            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                            color: Colors.subtext0
                            font.pixelSize: 9
                            font.family: "JetBrains Mono"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ;
                    }
                }

                Rectangle {
                    id: activeApp
                    width: 60
                    height: Variables.sectionsHeight
                    color: Colors.surface0
                    radius: Variables.radiusO
                    border.width: 1
                    border.color: Colors.surface1
                }
            }

            Rectangle {
                id: rightSection
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: rightRow.width + 8
                height: Variables.sectionsHeight
                color: Colors.surface0
                radius: Variables.radiusO
                border.width: 1
                border.color: Colors.surface1
                
                Row {
                    id: rightRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    anchors.centerIn: parent

                    Rectangle {
                        id: soundControl
                        width: Variables.rightHeight + 24
                        height: Variables.rightHeight
                        color: Colors.surface1
                        radius: Variables.radiusO
                    }

                    Rectangle {
                        id: power
                        width: Variables.rightHeight + 4
                        height: Variables.rightHeight
                        radius: Variables.radiusO
                        color: Colors.surface2
                        border.width: 2
                        border.color: Colors.surface2

                        Image {
                            id: powerIcon
                            anchors.centerIn: parent
                            source: "../icons/power.svg"  
                            width: Variables.rightHeight - 15
                            height: Variables.rightHeight - 16
                            visible: false    
                            sourceSize.height: Variables.rightHeight
                            sourceSize.width: Variables.rightHeight
                        }

                        ColorOverlay {
                            anchors.fill: powerIcon
                            source: powerIcon
                            color: Colors.subtext1
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (panel) panel.toggle()
                        }
                    }
                }
            }
        }
    }
}