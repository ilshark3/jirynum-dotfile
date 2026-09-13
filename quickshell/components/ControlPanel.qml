import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Dialogs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

import Qt5Compat.GraphicalEffects

import "."
import "../config"

// Main Control Panel window component
PanelWindow {
    id: controlPanel

    visible: Variables.panelOpen
    exclusiveZone: -1
    color: "transparent"
    implicitWidth: Variables.panelWidth

    margins {
        top: 5
        bottom: 5
        right: 5
    }

    anchors {
        top: true
        right: true
        bottom: true
    }

    // Toggles the panel visibility
    function toggle() {
        Variables.panelOpen = !Variables.panelOpen
    }

    // Process to pick a profile picture via Zenity
    Process {
        id: pfpPickerProcess
        command: ["zenity", "--file-selection", "--title=Choisir une photo de profil", "--file-filter=Images | *.png *.jpg *.jpeg *.webp"]
        
        stdout: SplitParser {
            id: pfpPickerParser
            onRead: data => {
                let path = data.trim()
                if (path !== "") {
                    Variables.profilePicture = "file://" + path
                }
            }
        }
    }

    // Process to fetch current system username
    Process {
        id: usernameProcess
        command: ["whoami"]
        running: true
        stdout: SplitParser {
            id: usernameParser
            onRead: data => {
                let name = data.trim()
                usernameText.text = name.charAt(0).toUpperCase() + name.slice(1)
            }
        }
    }

    // Process to fetch OS distro name
    Process {
        id: distroProcess
        command: ["sh", "-c", "grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'"]
        running: true
        stdout: SplitParser {
            id: distroParser
            onRead: data => {
                distroText.text = data.trim()
            }
        }
    }

    // Process to trigger Hyprlock screen locking
    Process {
        id: lockProcess
        command: ["hyprlock", "-c", "/home/ilshark3_tests/.config/hypr_tests/hyprlock.conf"]
    }

    // Process to get current brightness
    Process {
        id: getBrightness
        command: ["brightnessctl", "g"]
        running: true
        stdout: SplitParser {
            id: getBrightnessParser
            onRead: data => {
                let current = parseInt(data.trim())
                getMaxBrightness.running = true
                brightnessLevel.tempCurrent = current
            }
        }
    }

    // Process to get maximum brightness
    Process {
        id: getMaxBrightness
        command: ["brightnessctl", "m"]
        stdout: SplitParser {
            id: getMaxBrightnessParser
            onRead: data => {
                let max = parseInt(data.trim())
                if (max > 0) {
                    brightnessLevel.level = brightnessLevel.tempCurrent / max
                }
            }
        }
    }

    // Process to get initial monitor brightness via ddcutil
    Process {
        id: getInitialBrightness
        command: ["ddcutil", "getvcp", "10"]
        running: true
        stdout: SplitParser {
            id: getInitialBrightnessParser
            onRead: data => {
                let match = data.match(/current value =\s*(\d+)/)
                if (match && match[1]) {
                    let currentVal = parseInt(match[1])
                    brightnessLevel.level = currentVal / 100
                }
            }
        }
    }

    // Process to set monitor brightness via ddcutil
    Process {
        id: setBrightness
        function setLevel(pct) {
            let val = Math.round(pct * 100)
            command = ["ddcutil", "setvcp", "10", val]
            running = true
        }
    }

    // Outer background container
    Rectangle {
        id: mainPanelCountainer
        anchors.fill: parent
        color: Colors.base
        radius: Variables.radiusO

        // Main content layout manager
        Item {
            id: mainPanelGestion
            anchors.fill: parent
            anchors.margins: 10

            // User Profile Section
            Row {
                id: profileSection
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                // Profile background card
                Rectangle {
                    id: profile
                    width: Variables.panelWidth - 20
                    height: 100
                    radius: Variables.radiusO
                    color: Colors.surface1
                    border.width: 2
                    border.color: Colors.surface2

                    // Profile image display
                    Image {
                        id: profilPicture
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 6
                        source: Variables.profilePicture
                        fillMode: Image.PreserveAspectCrop
                        visible: true
                        height: 88
                        width: 88
                        sourceSize.height: 88
                        sourceSize.width: 88
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            id: profilePictureEffect
                            maskEnabled: true
                            maskThresholdMin: 0.5
                            maskSource: ShaderEffectSource {
                                id: profilePictureMaskSource
                                sourceItem: Rectangle {
                                    id: profilePictureMaskShape
                                    width: profilPicture.width
                                    height: profilPicture.height
                                    radius: Variables.radiusO
                                }
                            }
                        }
                        MouseArea {
                            id: profilePictureMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { pfpPickerProcess.running = true }
                        }
                    }

                    // User name and distro label container
                    Column {
                        id: userInfo
                        anchors.left: profilPicture.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: usernameText
                            text: "Utilisateur"
                            color: Colors.text
                            font.bold: true
                            font.pixelSize: 15
                            font.family: "JetBrains Mono"
                        }

                        Text {
                            id: distroText
                            text: "Linux"
                            color: Colors.subtext0
                            font.pixelSize: 12
                            font.family: "JetBrains Mono"
                        }
                    }

                    // Logout/Lock button container
                    Rectangle {
                        id: logoutBody
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 88
                        height: 88
                        anchors.margins: 6
                        radius: Variables.radiusO
                        border.width: 2
                        border.color: Colors.surface0
                        color: logoutButton.containsMouse ? "#33000000" : Colors.surface2
                        Behavior on color { ColorAnimation { id: logoutColorAnim; duration: 250 } }

                        Text {
                            id: logoutLogo
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf2f5"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: Colors.subtext1
                        }

                        MouseArea {
                            id: logoutButton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: lockProcess.running = true
                        }
                    }
                }
            }

            // Media Player Section
            Row {
                id: panelMediaPlayer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: profileSection.bottom
                anchors.topMargin: 10
                spacing: 4

                readonly property var activePlayer: Mpris.players.values[0] ?? null

                // Timer to update track position once per second when playing
                Timer {
                    id: positionUpdateTimer
                    interval: 1000
                    repeat: true
                    running: panelMediaPlayer.activePlayer?.playbackState === MprisPlaybackState.Playing
                    onTriggered: {
                        if (panelMediaPlayer.activePlayer) {
                            positionSlider.value = panelMediaPlayer.activePlayer.position
                        }
                    }
                }

                // Media player background card
                Rectangle {
                    id: mediaPlayerBase
                    width: Variables.panelWidth - 20
                    height: 180
                    radius: Variables.radiusO
                    color: Colors.surface1
                    border.width: 2
                    border.color: Colors.surface2
                    clip: true
                    
                    Item {
                        id: backgroundArt
                        anchors.fill: parent
                        visible: panelMediaPlayer.activePlayer !== null
                        property string targetSource: panelMediaPlayer.activePlayer?.trackArtUrl ?? ""
                        property bool useFirstImage: true

                        Item {
                            id: bgImgContainer
                            anchors.fill: parent
                            visible: false   // caché, sert de source

                            Image {
                                id: bgImg1
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                opacity: backgroundArt.useFirstImage ? 1 : 0.6
                                sourceSize.height: height
                                sourceSize.width: width
                                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                            }

                            Image {
                                id: bgImg2
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                opacity: backgroundArt.useFirstImage ? 0.6 : 1
                                sourceSize.height: height
                                sourceSize.width: width
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
                            }
                        }

                        GaussianBlur {
                            id: blurredResult
                            anchors.fill: parent
                            source: bgImgContainer
                            radius: Variables.radiusO
                            samples: 13
                            visible: false
                        }

                        Rectangle {
                            id: maskShape4
                            anchors.fill: parent
                            radius: Variables.radiusO
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: blurredResult
                            maskSource: maskShape4
                        }

                        onTargetSourceChanged: {
                            if (targetSource === "") return
                            if (useFirstImage) {
                                bgImg2.source = targetSource
                                useFirstImage = false
                            } else {
                                bgImg1.source = targetSource
                                useFirstImage = true
                            }
                        }
                    }

                    Rectangle {
                        id: topMediaSection
                        anchors.top: parent
                        anchors.left: parent
                        anchors.right: parent
                        height: parent.height * 0.5

                        // Track Header Row (Cover + Metadata)
                        Rectangle {
                            id: trackHeaderRow
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: parent.height
                            color: "transparent"

                            // Rotating vinyl record container
                            Rectangle {
                                id: imageDisk
                                anchors.right: parent.right 
                                anchors.bottom: parent.bottom 
                                width: 80
                                height: 80
                                radius: 40 
                                color: Colors.surface0
                                border.width: 2
                                border.color: Colors.base
                                clip: true

                                Item {
                                    id: mediaSearch
                                    anchors.fill: parent

                                    property string targetSource: panelMediaPlayer.activePlayer?.trackArtUrl ?? ""
                                    property real currentRotation: 0
                                    property bool useFirstImage: true

                                    NumberAnimation on currentRotation {
                                        id: vinylRotationAnim
                                        from: 0
                                        to: 360
                                        duration: 20000
                                        loops: Animation.Infinite
                                        running: panelMediaPlayer.activePlayer?.playbackState === MprisPlaybackState.Playing
                                    }

                                    Image {
                                        id: diskImg1
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        rotation: mediaSearch.currentRotation
                                        opacity: mediaSearch.useFirstImage ? 1 : 0
                                        Behavior on opacity { NumberAnimation { id: diskImg1Anim; duration: 400; easing.type: Easing.InOutQuad } }
                                    }

                                    Image {
                                        id: diskImg2
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        rotation: mediaSearch.currentRotation
                                        opacity: mediaSearch.useFirstImage ? 0 : 1
                                        Behavior on opacity { NumberAnimation { id: diskImg2Anim; duration: 400; easing.type: Easing.InOutQuad } }
                                    }

                                    onTargetSourceChanged: {
                                        if (targetSource === "") return

                                        if (useFirstImage) {
                                            diskImg2.source = targetSource
                                            useFirstImage = false
                                        } else {
                                            diskImg1.source = targetSource
                                            useFirstImage = true
                                        }
                                    }

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        id: diskMaskEffect
                                        maskEnabled: true
                                        maskThresholdMin: 0.5
                                        maskSource: ShaderEffectSource {
                                            id: diskMaskSource
                                            sourceItem: Rectangle {
                                                id: diskMaskShape
                                                width: mediaSearch.width
                                                height: mediaSearch.height
                                                radius: mediaSearch.width / 2
                                            }
                                        }
                                    }
                                }

                                // Vinyl center hole overlay
                                Rectangle {
                                    id: diskCenterHole
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: Colors.surface1
                                    border.width: 1
                                    border.color: Colors.surface2
                                    anchors.centerIn: parent
                                    z: 3
                                }
                            }
                        }

                        Rectangle {
                            id: mediaTextCountainer
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: parent.height
                            color: "#000000"


                            // Track title & artist text labels
                            Column {
                                id: trackDetailsColumn
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    id: trackTitleText
                                    width: parent.width
                                    text: panelMediaPlayer.activePlayer?.trackTitle ?? "no media is playing"
                                    color: Colors.text
                                    font.bold: true
                                    font.pixelSize: 14
                                    font.family: "JetBrains Mono"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: trackArtistText
                                    width: parent.width
                                    text: {
                                        let p = panelMediaPlayer.activePlayer
                                        if (!p) return ""

                                        if (p.trackArtist && p.trackArtist.length > 0) {
                                            return p.trackArtist
                                        }

                                        if (p.trackArtists && p.trackArtists.length > 0) {
                                            return p.trackArtists.join(", ")
                                        }

                                        if (p.metadata) {
                                            let artist = p.metadata["xesam:artist"] || p.metadata["artist"]
                                            if (artist) {
                                                return Array.isArray(artist) ? artist.join(", ") : artist
                                            }
                                        }

                                        return "can't find the artist"
                                    }
                                    color: Colors.text
                                    font.pixelSize: 12
                                    font.family: "JetBrains Mono"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: centerMediaSection
                        anchors.top: trackHeaderRow.bottom
                        anchors.bottom: bottomMediaSection.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        color: "transparent"

                        Rectangle {
                            id: mediaProgressRow
                            anchors.left: timeCountainer1.right
                            anchors.right: timeCountainer2.left
                            anchors.bottom: parent.bottom
                            anchors.top: parent.top
                            color: parent.color

                            Slider {
                                id: positionSlider
                                width: parent.width
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 25
                                anchors.rightMargin: 25

                                from: 0
                                to: panelMediaPlayer.activePlayer?.length ?? 1
                                value: panelMediaPlayer.activePlayer?.position ?? 0

                                // Updates track position when dragging or clicking
                                onMoved: {
                                    let player = panelMediaPlayer.activePlayer
                                    if (player) {
                                        let offset = positionSlider.value - player.position
                                        if (typeof player.seek === "function") {
                                            player.seek(offset)
                                        } else if (typeof player.setPosition === "function") {
                                            player.setPosition(positionSlider.value)
                                        }
                                    }
                                }

                                background: Rectangle {
                                    id: sliderBg
                                    x: positionSlider.leftPadding
                                    y: positionSlider.topPadding + positionSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 20
                                    implicitHeight: 4
                                    width: positionSlider.availableWidth
                                    height: implicitHeight
                                    radius: 2
                                    color: Colors.surface0

                                    // Filled progress bar
                                    Rectangle {
                                        id: sliderFill
                                        width: positionSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: Colors.surface2
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    id: sliderHandle
                                    x: positionSlider.leftPadding + positionSlider.visualPosition * (positionSlider.availableWidth - width)
                                    y: positionSlider.topPadding + positionSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 10
                                    implicitHeight: 10
                                    radius: 5
                                    color: positionSlider.pressed ? Colors.lavender : Colors.text
                                }

                                // Direct click handler using seek for MPRIS compatibility
                                MouseArea {
                                    id: sliderMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        let player = panelMediaPlayer.activePlayer
                                        if (!player) return

                                        // Calculate target time in seconds
                                        let targetTime = (mouse.x / width) * positionSlider.to
                                        
                                        // Calculate relative difference (offset)
                                        let offset = targetTime - player.position

                                        // Try seeking relatively or absolutely
                                        if (typeof player.seek === "function") {
                                            player.seek(offset)
                                        } else if (typeof player.setPosition === "function") {
                                            player.setPosition(targetTime)
                                        }
                                        
                                        positionSlider.value = targetTime
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: timeCountainer1
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * 0.1
                            color: parent.color

                            Text {
                                id: positionText
                                anchors.centerIn: parent
                                text: centerMediaSection.formatTime(positionSlider.value)
                                color: Colors.text
                                font.pixelSize: 10
                                font.family: "JetBrains Mono"
                            }
                        }

                        Rectangle {
                            id: timeCountainer2
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * 0.1
                            color: parent.color

                            Text {
                                id: lengthText
                                anchors.centerIn: parent
                                text: centerMediaSection.formatTime(panelMediaPlayer.activePlayer?.length ?? 0)
                                color: Colors.text
                                font.pixelSize: 10
                                font.family: "JetBrains Mono"
                            }

                        }

                        // Formats seconds into MM:SS format
                        function formatTime(seconds) {
                            let sec = Math.floor(seconds / (seconds > 100000 ? 1000000 : 1))
                            let m = Math.floor(sec / 60)
                            let s = Math.floor(sec % 60)
                            return m + ":" + (s < 10 ? "0" : "") + s
                        }
                        
                    }

                    Rectangle {
                        id: bottomMediaSection
                        anchors.bottom: parent.bottom 
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * 0.40
                        color: "transparent"

                        // Playback control buttons Row
                        Row {
                            id: mediaControlsRow
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 100
                            spacing: 50

                            // Previous track button
                            Text {
                                id: prevIcon
                                text: "\uf04a"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 30
                                color: panelMediaPlayer.activePlayer?.canGoPrevious ? Colors.yellow : Colors.base

                                MouseArea {
                                    id: prevMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: panelMediaPlayer.activePlayer?.canGoPrevious ?? false
                                    onClicked: panelMediaPlayer.activePlayer.previous()
                                }
                            }

                            // Play/Pause button
                            Rectangle {
                                id: playPauseButton
                                width: 40
                                height: 40
                                radius: Variables.radiusO
                                color: Colors.surface1
                                border.width: 1
                                border.color: Colors.yellow
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: playPauseIcon
                                    anchors.centerIn: parent
                                    text: panelMediaPlayer.activePlayer?.playbackState === MprisPlaybackState.Playing ? "\uf04c" : "\uf04b"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                    color: Colors.surface1
                                }

                                MouseArea {
                                    id: playPauseMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: panelMediaPlayer.activePlayer !== null
                                    onClicked: panelMediaPlayer.activePlayer.togglePlaying()
                                }
                            }

                            // Next track button
                            Text {
                                id: nextIcon
                                text: "\uf04e"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 30
                                color: panelMediaPlayer.activePlayer?.canGoNext ? Colors.yellow : Colors.surface2

                                MouseArea {
                                    id: nextMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: panelMediaPlayer.activePlayer?.canGoNext ?? false
                                    onClicked: panelMediaPlayer.activePlayer.next()
                                }
                            }
                        }
                    }
                }
            }
            
            // Bottom sliders panel
            Rectangle {
                id: bottomPanel
                height: Variables.panelWidth - 20
                color: Colors.surface1
                radius: Variables.radiusO
                anchors.bottom: mainPanelGestion.bottom
                anchors.right: mainPanelGestion.right
                anchors.left: mainPanelGestion.left
                border.width: 2
                border.color: Colors.surface2

                // Audio Volume Slider
                Rectangle {
                    id: soundControl
                    height: parent.height - 30
                    width: 50
                    color: Colors.surface0
                    radius: Variables.radiusO
                    anchors.top: parent.top
                    anchors.left: parent.left
                    border.width: 1
                    border.color: Colors.surface2
                    anchors.margins: 15

                    PwObjectTracker { id: audioTracker; objects: [Variables.sink] }

                    Rectangle {
                        id: maskShape
                        anchors.fill: parent
                        radius: parent.radius
                        visible: false
                    }

                    Item {
                        id: fillSound
                        anchors.fill: parent
                        visible: false

                        Rectangle {
                            id: fillSoundBar
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * Variables.level 
                            color: Colors.mantle
                            radius: Variables.radiusO

                            Behavior on height {
                                NumberAnimation { id: fillSoundAnim; duration: 150; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    OpacityMask {
                        id: soundMask
                        anchors.fill: parent
                        source: fillSound
                        maskSource: maskShape
                    }

                    Text {
                        id: soundVolume
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 12
                        text: Math.round(Variables.level * 100)
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "JetBrains Mono"
                        color: Colors.text
                        z: 2
                    }

                    Text {
                        id: soundLogo
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 12
                        text: Variables.level === 0 ? "\uf026" : "\uf028"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: (soundControl.height * Variables.level) > (soundControl.height - 35) ? Colors.base : Colors.subtext1
                        z: 2
                    }

                    MouseArea {
                        id: soundMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: 3

                        onPressed: (mouse) => updateLevel(mouse.y)
                        onPositionChanged: (mouse) => {
                            if (pressed) updateLevel(mouse.y)
                        }

                        function updateLevel(y) {
                            let ratio = 1 - (y / height)
                            let clamped = Math.max(0, Math.min(1, ratio))

                            if (Variables.sink?.ready && Variables.sink?.audio) {
                                Variables.sink.audio.muted = false
                                Variables.sink.audio.volume = clamped
                            }
                        }
                    }
                }

                // Brightness Slider
                Rectangle {
                    id: brightnessLevel
                    height: parent.height - 30
                    width: 50
                    color: Colors.surface0
                    radius: Variables.radiusO
                    anchors.top: parent.top
                    anchors.left: soundControl.right
                    border.width: 1
                    border.color: Colors.surface2
                    anchors.margins: 15

                    property real level: 0.5
                    property real tempCurrent: 0

                    Rectangle {
                        id: maskShape2
                        anchors.fill: parent
                        radius: parent.radius
                        visible: false
                    }

                    Item {
                        id: fillBrightness
                        anchors.fill: parent
                        visible: false

                        Rectangle {
                            id: fillBrightnessBar
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * brightnessLevel.level
                            color: Colors.yellow
                            radius: Variables.radiusO

                            Behavior on height {
                                NumberAnimation { id: fillBrightnessAnim; duration: 100; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    OpacityMask {
                        id: brightnessMask
                        anchors.fill: parent
                        source: fillBrightness
                        maskSource: maskShape2
                    }

                    Text {
                        id: brightnessLevelText
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 12
                        text: Math.round(brightnessLevel.level * 100)
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "JetBrains Mono"
                        color: Colors.text
                        z: 2
                    }

                    Text {
                        id: brightnessLogo
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 12
                        text: "\uf185"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: (brightnessLevel.height * brightnessLevel.level) > (brightnessLevel.height - 35) ? Colors.base : Colors.text
                        z: 2
                    }

                    MouseArea {
                        id: brightnessPicker
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: 3

                        onPressed: (mouse) => updateBrightness(mouse.y)
                        onPositionChanged: (mouse) => {
                            if (pressed) updateBrightness(mouse.y)
                        }

                        function updateBrightness(y) {
                            let ratio = 1 - (y / height)
                            let clamped = Math.max(0.05, Math.min(1, ratio))
                            brightnessLevel.level = clamped
                            setBrightness.setLevel(clamped)
                        }
                    }
                }
            }

            // Notification section container
            Row {
                id: notificationSection
            }
        }
    }
}