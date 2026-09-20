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
import Quickshell.Services.Notifications

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

    Process {
        id: savePfpProcess
        command: []
        function savePath(path) {
            command = ["sh", "-c", "mkdir -p ~/.config/quickshell && echo '" + path + "' > ~/.config/quickshell/config/pfp.txt"]
            running = true
        }
    }

    Process {
        id: loadPfpProcess
        command: ["sh", "-c", "cat ~/.config/quickshell/config/pfp.txt 2>/dev/null || true"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let path = data.trim()
                if (path !== "") {
                    Variables.profilePicture = "file://" + path
                }
            }
        }
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
                    savePfpProcess.savePath(path)
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

    Process {
        id: lockProcess
        command: ["sh", "-c", "hyprlock -c ~/.config/hypr/config/hyprlock.conf"]
    }

    Process {
        id: powerOffProcess
        command: ["poweroff"]
    }

    Process {
        id: rebootProcess
        command: ["reboot"]
    }

    Process {
        id: sleepProcess
        command: ["systemctl", "suspend"]
    }

    Process {
        id: logoutProcess
        command: ["pkill", "hyprland"]
    }

   Process {
        id: getBrightness
        command: ["brightnessctl", "g"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let current = parseInt(data.trim())
                getMaxBrightness.running = true
                brightnessLevel.tempCurrent = current
            }
        }
    }

    Process {
        id: detectMonitor

        property string ddcBus: ""

        command: ["ddcutil", "detect"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let match = data.match(/I2C bus:\s+\/dev\/i2c-(\d+)/)

                if (match) {
                    detectMonitor.ddcBus = match[1]
                    console.log("DDC bus détecté :", detectMonitor.ddcBus)
                }
            }
        }
    }

    Process {
        id: detectBrightnessMonitor

        property string ddcBus: ""

        command: ["ddcutil", "detect"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let match = data.match(/I2C bus:\s+\/dev\/i2c-(\d+)/)

                if (match) {
                    detectBrightnessMonitor.ddcBus = match[1]
                    console.log("Brightness: DDC bus détecté -> /dev/i2c-" + match[1])

                    // Une fois le bus trouvé, récupérer la luminosité actuelle
                    getInitialBrightness.running = true
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                console.log("ddcutil detect:", data)
            }
        }
    }

    Process {
        id: getInitialBrightness

        command: {
            if (!detectBrightnessMonitor.ddcBus)
                return []

            return [
                "ddcutil",
                "-b", detectBrightnessMonitor.ddcBus,
                "getvcp", "10"
            ]
        }

        stdout: SplitParser {
            onRead: data => {
                let match = data.match(/current value =\s*(\d+)/)

                if (match && match[1]) {
                    let currentVal = parseInt(match[1])
                    brightnessLevel.level = currentVal / 100
                }
            }
        }
    }

    Process {
        id: setBrightness

        function setLevel(pct) {
            if (!detectBrightnessMonitor.ddcBus)
                return

            let val = Math.round(pct * 100)

            command = [
                "ddcutil",
                "-b", detectBrightnessMonitor.ddcBus,
                "--noverify",
                "setvcp", "10",
                val.toString()
            ]

            running = true
        }
    }

    Process {
        id: cavaProcess

        command: [
            "bash",
            "-c",
            "exec cava -p \"$HOME/.config/cava/quickshell.conf\""
        ]

        running: true

        stdout: SplitParser {
            onRead: data => {
                let values = data.trim().split(";")

                if (values.length < 2)
                    return

                let parsed = []

                for (let i = 0; i < values.length; i++) {
                    let value = parseInt(values[i])

                    if (isNaN(value))
                        value = 0

                    // CAVA = 0-1000
                    // QML = 0.0-1.0
                    parsed.push(Math.max(0, Math.min(1, value / 1000)))
                }

                cavaVisualizer.levels = parsed
            }
        }

        stderr: SplitParser {
            onRead: data => {
                console.log("CAVA:", data)
            }
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
            anchors.margins: 5

            // User Profile Section
            Item {
                id: profileSection
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 100

                // Profile background card
                Rectangle {
                    id: profile
                    anchors.fill: parent
                    radius: Variables.radiusO
                    color: Colors.surface1
                    border.width: 2
                    border.color: Colors.surface2
                    anchors.bottomMargin: 5

                    Item {
                        id: profilPictureContainer
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 5
                        width: 88
                        height: 88

                        Image {
                            id: profilPicture
                            anchors.fill: parent
                            source: Variables.profilePicture
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            sourceSize.width: parent.width
                            sourceSize.height: parent.height
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                id: profilePictureEffect

                                maskEnabled: true
                                maskThresholdMin: 0.5

                                maskSource: ShaderEffectSource {
                                    sourceItem: Rectangle {
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

                                onClicked: {
                                    pfpPickerProcess.running = true
                                }
                            }
                        }

                        Rectangle {
                            id: profilePlaceholder

                            anchors.fill: parent

                            visible: !profilPicture.visible

                            color: Colors.surface2

                            radius: Variables.radiusO

                            border.width: 2
                            border.color: Colors.surface0

                            Image {
                                id: profilePlaceholderIcon
                                anchors.centerIn: parent
                                width: 15
                                height: 15
                                sourceSize.height: width
                                sourceSize.width: height
                                source: "../icons/pfppicker.svg"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MouseArea {
                                id: profilePlaceholderMouseArea

                                anchors.fill: parent

                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    pfpPickerProcess.running = true
                                }
                            }

                            ColorOverlay {
                                anchors.fill: profilePlaceholderIcon
                                source: profilePlaceholderIcon
                                color: Colors.subtext1
                            }
                        }
                    }

                    // User name and distro label container
                    Column {
                        id: userInfo
                        anchors.left: profilPictureContainer.right
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
                        anchors.margins: 5
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
            Item {
                id: panelMediaPlayer
                anchors.top: profileSection.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 180

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
                    anchors.fill: parent
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
                                opacity: backgroundArt.useFirstImage ? 0.5 : 0
                                sourceSize.height: height
                                sourceSize.width: width
                                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                            }

                            Image {
                                id: bgImg2
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                opacity: backgroundArt.useFirstImage ? 0 : 0.5
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
                            samples: 24
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

                        Item {
                            id: cavaVisualizer

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom

                            height: parent.height

                            property var levels: []

                            visible: panelMediaPlayer.activePlayer?.playbackState
                                    === MprisPlaybackState.Playing

                            opacity: visible ? 0.5 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Row {
                                id: cavaBars

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom

                                anchors.leftMargin: 18
                                anchors.rightMargin: 18

                                spacing: 3

                                Repeater {
                                    model: 32

                                    Rectangle {
                                        property real audioLevel:
                                            cavaVisualizer.levels.length > index
                                            ? cavaVisualizer.levels[index]
                                            : 0

                                        width: Math.max(
                                            2,
                                            (cavaBars.width - (31 * cavaBars.spacing)) / 32
                                        )

                                        height: Math.max(
                                            2,
                                            audioLevel * 120
                                        )

                                        anchors.bottom: parent.bottom

                                        color: Colors.base

                                        opacity: 0.85

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: 90
                                                easing.type: Easing.OutQuad
                                            }
                                        }

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 200
                                            }
                                        }
                                    }
                                }
                            }
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
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * 0.5
                        color: "transparent"

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
                                        visible: panelMediaPlayer.activePlayer !== null && mediaSearch.useFirstImage
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        rotation: mediaSearch.currentRotation
                                        opacity: mediaSearch.useFirstImage ? 1 : 0
                                        Behavior on opacity { NumberAnimation { id: diskImg1Anim; duration: 400; easing.type: Easing.InOutQuad } }
                                    }

                                    Image {
                                        id: diskImg2
                                        visible: panelMediaPlayer.activePlayer !== null && !mediaSearch.useFirstImage
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
                                        maskThresholdMin: 0.9
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
                            anchors.left: trackHeaderRow.right
                            color: "transparent"

                            Column {
                                id: trackDetailsColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    id: trackTitleText
                                    anchors.left: parent.left
                                    anchors.leftMargin: 20
                                    text: panelMediaPlayer.activePlayer?.trackTitle ?? "no media is playing"
                                    color: Colors.subtext1
                                    font.bold: true
                                    font.pixelSize: 20
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                    style: Text.Raised
                                    styleColor: "#000000"
                                }

                                Text {
                                    id: trackArtistText
                                    anchors.left: parent.left
                                    anchors.leftMargin: 20
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
                                    color: Colors.subtext0
                                    font.pixelSize: 15
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                    style: Text.Outline
                                    styleColor: "#66000000"
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
                                    radius: Variables.radiusO
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
                        height: parent.height * 0.4
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            anchors.bottom: parent.bottom
                            color: "transparent"
                            anchors.topMargin: 15

                            // Playback control buttons Row
                            Row {
                                id: mediaControlsRow
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: 100
                                spacing: 50

                                // Previous track button
                                Rectangle {
                                    width: 45
                                    height: 40
                                    radius: Variables.radiusO
                                    color: Colors.base
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        id: prevIcon
                                        text: "\uf04a"
                                        anchors.centerIn: parent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 25
                                        color: panelMediaPlayer.activePlayer?.canGoPrevious ? Colors.yellow : Colors.base
                                    }

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
                                    color: Colors.yellow
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: playPauseIcon
                                        anchors.centerIn: parent
                                        text: panelMediaPlayer.activePlayer?.playbackState === MprisPlaybackState.Playing ? "\uf04c" : "\uf04b"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 20
                                        color: Colors.base
                                    }

                                    MouseArea {
                                        id: playPauseMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: panelMediaPlayer.activePlayer !== null
                                        onClicked: panelMediaPlayer.activePlayer.togglePlaying()
                                    }
                                }

                                Rectangle {
                                    width: 45
                                    height: 40
                                    radius: Variables.radiusO
                                    color: Colors.base
                                    anchors.verticalCenter: parent.verticalCenter

                                // Next track button
                                    Text {
                                        id: nextIcon
                                        anchors.centerIn: parent
                                        text: "\uf04e"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 25
                                        color: panelMediaPlayer.activePlayer?.canGoNext ? Colors.yellow : Colors.base
                                    }

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
            }

            Item {
                id: audioOutInItem
                anchors.right: parent.right
                anchors.left: parent.left
                anchors.top: panelMediaPlayer.bottom
                height: 50
                anchors.topMargin: 5

                property bool outputMenuOpen: false
                property bool inputMenuOpen: false

                property var outputDevices: []
                property var inputDevices: []

                property string selectedOutput: Pipewire.defaultAudioSink?.description
                    || Pipewire.defaultAudioSink?.nickname
                    || Pipewire.defaultAudioSink?.name
                    || "No output"

                property string selectedInput: Pipewire.defaultAudioSource?.description
                    || Pipewire.defaultAudioSource?.nickname
                    || Pipewire.defaultAudioSource?.name
                    || "No input"

                function refreshAudioDevices() {
                    let outputs = []
                    let inputs = []

                    for (let i = 0; i < Pipewire.nodes.values.length; i++) {
                        let node = Pipewire.nodes.values[i]

                        if (!node || !node.audio || node.isStream)
                            continue

                        let deviceName = node.nickname
                            || node.description
                            || node.name
                            || "Audio device"

                        if (node.isSink) {
                            outputs.push({
                                node: node,
                                name: deviceName
                            })
                        } else {
                            // Avoid showing PipeWire monitors as microphones
                            if (node.name && node.name.endsWith(".monitor"))
                                continue

                            inputs.push({
                                node: node,
                                name: deviceName
                            })
                        }
                    }

                    outputDevices = outputs
                    inputDevices = inputs
                }

                Connections {
                    target: Pipewire

                    function onDefaultAudioSinkChanged() {
                        audioOutInItem.selectedOutput =
                            Pipewire.defaultAudioSink?.description
                            || Pipewire.defaultAudioSink?.nickname
                            || Pipewire.defaultAudioSink?.name
                            || "No output"
                    }

                    function onDefaultAudioSourceChanged() {
                        audioOutInItem.selectedInput =
                            Pipewire.defaultAudioSource?.description
                            || Pipewire.defaultAudioSource?.nickname
                            || Pipewire.defaultAudioSource?.name
                            || "No input"
                    }

                    function onReadyChanged() {
                        if (Pipewire.ready)
                            audioOutInItem.refreshAudioDevices()
                    }
                }

                Timer {
                    id: audioDeviceRefreshTimer
                    interval: 1000
                    repeat: true
                    running: true

                    onTriggered: {
                        if (Pipewire.ready)
                            audioOutInItem.refreshAudioDevices()
                    }
                }

                Component.onCompleted: {
                    if (Pipewire.ready)
                        refreshAudioDevices()
                }

                Rectangle {
                    id: outPutAudio
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: parent.width /2 -2.5
                    radius: Variables.radiusO
                    color: Colors.surface1
                    border.width: 2
                    border.color: Colors.surface2

                    Item {
                        id: headsetItem
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.2

                        Image {
                            id: headsetImg
                            anchors.centerIn: parent
                            source: "../icons/headset.svg"  
                            width: outPutAudio.width * 0.15
                            height: width
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }
                        
                        ColorOverlay {
                            anchors.fill: headsetImg
                            source: headsetImg
                            color: Colors.subtext1
                        }
                    }

                    Item {
                        id: outputName
                        anchors.right: arrowItem1.left
                        anchors.left: headsetItem.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            text: audioOutInItem.selectedOutput
                            color: Colors.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            font.bold: true
                        }
                    }

                    Item {
                        id: arrowItem1
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.15

                        Image {
                            id: arrowImg1
                            anchors.centerIn: parent
                            source: "../icons/down-arrow.svg"  
                            width: outPutAudio.width * 0.15
                            height: width
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }
                        
                        ColorOverlay {
                            anchors.fill: arrowImg1
                            source: arrowImg1
                            color: Colors.subtext1
                            rotation: audioOutInItem.outputMenuOpen ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                audioOutInItem.outputMenuOpen =
                                    !audioOutInItem.outputMenuOpen

                                if (audioOutInItem.outputMenuOpen)
                                    audioOutInItem.inputMenuOpen = false
                            }
                        }
                    }

                    Rectangle {
                        id: outputDropdown

                        visible: height > 0
                        clip: false
                        anchors.top: parent.bottom
                        anchors.topMargin: 4
                        anchors.left: parent.left
                        z: -1

                        width: parent.width

                        height: audioOutInItem.outputMenuOpen
                            ? Math.min(Math.max(audioOutList.contentHeight + 10, 40), 180)
                            : 0

                        Behavior on height {
                            NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
                        }

                        Behavior on anchors.topMargin {
                            NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
                        }

                        radius: Variables.radiusO
                        color: Colors.surface1
                        border.width: 2
                        border.color: Colors.surface2
                        z: 100

                        ListView {
                            id: audioOutList

                            anchors.fill: parent
                            anchors.margins: 5
                            clip: true
                            spacing: 3

                            model: audioOutInItem.outputDevices

                            delegate: Rectangle {
                                width: audioOutList.width
                                height: 34

                                radius: Variables.radiusO

                                color: mouseArea.containsMouse
                                    ? Colors.surface2
                                    : "transparent"

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
                                    elide: Text.ElideRight
                                    font.bold: true
                                }

                                MouseArea {
                                    id: mouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (modelData.node) {
                                            Pipewire.preferredDefaultAudioSink =
                                                modelData.node

                                            audioOutInItem.selectedOutput =
                                                modelData.name
                                        }

                                        audioOutInItem.outputMenuOpen = false
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                visible:
                                    audioOutInItem.outputDevices.length === 0

                                text: "No audio output"
                                color: Colors.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                Rectangle {
                    id: inPutAudio
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: parent.width /2 -2.5
                    radius: Variables.radiusO
                    color: Colors.surface1
                    border.width: 2
                    border.color: Colors.surface2

                    Item {
                        id: microphoneItem
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.2

                        Image {
                            id: microphoneImg
                            anchors.centerIn: parent
                            source: "../icons/microphone.svg"  
                            width: inPutAudio.width * 0.15
                            height: width
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }
                        
                        ColorOverlay {
                            anchors.fill: microphoneImg
                            source: microphoneImg
                            color: Colors.subtext1
                        }
                    }

                    Item {
                        id: inputName
                        anchors.right: arrowItem2.left
                        anchors.left: microphoneItem.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            text: audioOutInItem.selectedInput
                            color: Colors.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            font.bold: true
                        }
                    }

                    Item {
                        id: arrowItem2
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.15

                        Image {
                            id: arrowImg2
                            anchors.centerIn: parent
                            source: "../icons/down-arrow.svg"  
                            width: inPutAudio.width * 0.15
                            height: width
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }
                        
                        ColorOverlay {
                            id: arrowOverlay2
                            anchors.fill: arrowImg2
                            source: arrowImg2
                            color: Colors.subtext1

                            rotation: audioOutInItem.inputMenuOpen ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                audioOutInItem.inputMenuOpen =
                                    !audioOutInItem.inputMenuOpen

                                if (audioOutInItem.inputMenuOpen)
                                    audioOutInItem.outputMenuOpen = false
                            }
                        }
                    }

                    Rectangle {
                        id: inputDropdown

                        visible: height > 0
                        clip: false

                        anchors.top: parent.bottom
                        anchors.topMargin: 4
                        anchors.right: parent.right

                        width: parent.width
                        height: audioOutInItem.inputMenuOpen
                            ? Math.min(Math.max(audioOutList.contentHeight + 10, 40), 180)
                            : 0

                        Behavior on height {
                            NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
                        }

                        Behavior on anchors.topMargin {
                            NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
                        }

                        radius: Variables.radiusO
                        color: Colors.surface1
                        border.width: 2
                        border.color: Colors.surface2

                        ListView {
                            id: audioInList

                            anchors.fill: parent
                            anchors.margins: 5
                            clip: true
                            spacing: 3

                            model: audioOutInItem.inputDevices

                            delegate: Rectangle {
                                width: audioInList.width
                                height: 34

                                radius: Variables.radiusO

                                color: mouseArea.containsMouse
                                    ? Colors.surface2
                                    : "transparent"

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
                                    elide: Text.ElideRight
                                    font.bold: true
                                }

                                MouseArea {
                                    id: mouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (modelData.node) {
                                            Pipewire.preferredDefaultAudioSource =
                                                modelData.node

                                            audioOutInItem.selectedInput =
                                                modelData.name
                                        }

                                        audioOutInItem.inputMenuOpen = false
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                visible:
                                    audioOutInItem.inputDevices.length === 0

                                text: "No audio input"
                                color: Colors.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            Item {
                id: notificationCenter
                anchors.top: audioOutInItem.bottom
                anchors.right: parent.right
                anchors.left: parent.left
                height: 350
                anchors.topMargin: 5

                Rectangle {
                    id: notifBg
                    anchors.fill: parent
                    radius: Variables.radiusO
                    color: Colors.surface1
                    border.width: 2
                    border.color: Colors.surface2

                    Item {
                        id: notifHeader
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.left: parent.left
                        height: 50

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Recent notifications"
                            font.pixelSize: 15
                            font.family: "JetBrains Mono"
                            font.bold: true
                            color: Colors.text
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.top: parent.verticalCenter
                            anchors.topMargin: 2
                            text: Notifications.list.count + " unread"
                            font.pixelSize: 10
                            font.family: "JetBrains Mono"
                            color: Colors.subtext0
                            visible: true
                        }

                        // Bouton "Clear all"
                        Rectangle {
                            id: clearAllBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: clearAllText.width + 20
                            height: 28
                            radius: Variables.radiusO
                            color: clearAllMouse.containsMouse
                                ? Colors.surface2
                                : "transparent"
                            border.width: 1
                            border.color: Colors.surface2
                            visible: Notifications.list.count > 0

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Text {
                                id: clearAllText
                                anchors.centerIn: parent
                                text: "Clear all"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                                font.bold: true
                                color: Colors.subtext1
                            }

                            MouseArea {
                                id: clearAllMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.NotifService.discardAll()
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: notifBg.radius
                            anchors.rightMargin: notifBg.radius
                            height: 1
                            color: Colors.surface2
                        }
                    }

                    ListView {
                        id: notifList
                        anchors.top: notifHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        spacing: 8
                        clip: true

                        model: Services.NotifService.list

                        delegate: Rectangle {
                            id: notifCard
                            width: notifList.width
                            height: notifContent.implicitHeight + 24
                            radius: Variables.radiusO
                            color: cardMouse.containsMouse
                                ? Colors.surface2
                                : Colors.surface0

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            // Animation d'entrée
                            opacity: 0
                            x: 20
                            Component.onCompleted: {
                                entryAnim.start()
                            }

                            ParallelAnimation {
                                id: entryAnim
                                NumberAnimation {
                                    target: notifCard
                                    property: "opacity"
                                    to: 1
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: notifCard
                                    property: "x"
                                    to: 0
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Barre d'accent (couleur selon urgence)
                            Rectangle {
                                id: urgencyBar
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 3
                                radius: 2
                                color: {
                                    if (model.urgency === "critical") return "#e06c75"
                                    if (model.urgency === "low") return Colors.surface2
                                    return Colors.subtext1 // normal
                                }
                            }

                            Item {
                                id: notifContent
                                anchors.left: urgencyBar.right
                                anchors.right: closeBtn.left
                                anchors.top: parent.top
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                anchors.topMargin: 10
                                implicitHeight: iconRow.height + bodyText.implicitHeight + 6

                                Row {
                                    id: iconRow
                                    width: parent.width
                                    height: 22
                                    spacing: 8

                                    // Icône de l'app
                                    Item {
                                        width: 18
                                        height: 18
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            id: appIconImg
                                            anchors.fill: parent
                                            source: model.appIcon || "../icons/bell.svg"
                                            visible: false
                                            sourceSize.width: 18
                                            sourceSize.height: 18
                                        }

                                        ColorOverlay {
                                            anchors.fill: appIconImg
                                            source: appIconImg
                                            color: Colors.subtext1
                                        }
                                    }

                                    Text {
                                        text: model.appName || "Notification"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Colors.subtext1
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "•  " + (model.time || "now")
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        color: Colors.subtext0
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    id: summaryText
                                    anchors.top: iconRow.bottom
                                    anchors.topMargin: 4
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    text: model.summary || ""
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Colors.text
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    id: bodyText
                                    anchors.top: summaryText.bottom
                                    anchors.topMargin: 2
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    text: model.body || ""
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    color: Colors.subtext0
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }
                            }

                            // Bouton fermer (apparaît au survol)
                            Rectangle {
                                id: closeBtn
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 8
                                anchors.rightMargin: 8
                                width: 20
                                height: 20
                                radius: 10
                                color: closeMouse.containsMouse
                                    ? Colors.surface2
                                    : "transparent"

                                opacity: cardMouse.containsMouse ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 120 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 10
                                    color: Colors.subtext1
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Services.NotifService.discard(model.id)
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                z: -1 // en dessous du closeBtn pour ne pas lui voler le hover
                            }
                        }

                        // État vide
                        Item {
                            anchors.centerIn: parent
                            visible: notifList.count === 0
                            width: 200
                            height: 80

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "🔕"
                                    font.pixelSize: 28
                                    opacity: 0.5
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No notifications"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 12
                                    color: Colors.subtext0
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: powerPanel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: bottomPanel.top

                // Hauteur calculée pour 5 boutons carrés (4 espaces de 5px = 20px)
                height: (width - 20) / 5
                anchors.bottomMargin: 5

                Row {
                    anchors.fill: parent
                    spacing: 5

                    readonly property real btnWidth: (width - (spacing * 4)) / 5

                    // 1. BOUTON ÉTEINDRE
                    Rectangle {
                        id: button1
                        width: parent.btnWidth
                        height: parent.height
                        radius: Variables.radiusO
                        color: Colors.surface1
                        border.width: 2
                        border.color: Colors.surface2

                        MouseArea {
                            id: powerOffButton
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: powerOffProcess.running = true
                        }

                        Image {
                            id: powerOffIcon
                            anchors.centerIn: parent
                            source: "../icons/power.svg"  
                            width: parent.width - 40
                            height: parent.height - 40
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }
                        
                        ColorOverlay {
                            anchors.fill: powerOffIcon
                            source: powerOffIcon
                            color: Colors.subtext1
                        }
                    }

                    // 2. BOUTON REDÉMARRER
                    Rectangle {
                        id: button2
                        width: parent.btnWidth
                        height: parent.height
                        radius: Variables.radiusO
                        color: Colors.surface1
                        border.width: 2
                        border.color: Colors.surface2

                        MouseArea {
                            id: restartButton
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rebootProcess.running = true
                        }

                        Image {
                            id: restartIcon
                            anchors.centerIn: parent
                            source: "../icons/restart.svg"  
                            width: parent.width - 40
                            height: parent.height - 40
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }

                        ColorOverlay {
                            anchors.fill: restartIcon
                            source: restartIcon
                            color: Colors.subtext1
                        }
                    }

                    // 3. BOUTON DÉCONNEXION
                    Rectangle {
                        id: button3
                        width: parent.btnWidth
                        height: parent.height
                        radius: Variables.radiusO
                        color: Colors.surface1
                        border.width: 2
                        border.color: Colors.surface2

                        MouseArea {
                            id: disconnectButton
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: logoutProcess.running = true
                        }

                        Image {
                            id: disconnectIcon
                            anchors.centerIn: parent
                            source: "../icons/logout.svg"  
                            width: parent.width - 40
                            height: parent.height - 40
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }

                        ColorOverlay {
                            anchors.fill: disconnectIcon
                            source: disconnectIcon
                            color: Colors.subtext1
                        }
                    }

                    // 4. BOUTON MISE EN VEILLE (SLEEP)
                    Rectangle {
                        id: button4
                        width: parent.btnWidth
                        height: parent.height
                        radius: Variables.radiusO
                        color: Colors.surface1
                        border.width: 2
                        border.color: Colors.surface2

                        MouseArea {
                            id: sleepButton
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sleepProcess.running = true
                        }

                        Image {
                            id: sleepIcon
                            anchors.centerIn: parent
                            source: "../icons/sleep.svg"  
                            width: parent.width - 40
                            height: parent.height - 40
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }

                        ColorOverlay {
                            anchors.fill: sleepIcon
                            source: sleepIcon
                            color: Colors.subtext1
                        }
                    }

                    // 5. BOUTON RECHARGER HYPRLAND (RELOAD)
                    Rectangle {
                        id: button5
                        width: parent.btnWidth
                        height: parent.height
                        radius: Variables.radiusO
                        color: Colors.surface1
                        border.width: 2
                        border.color: Colors.surface2

                        MouseArea {
                            id: reloadHyprButton
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Process.exec([
                                "sh", 
                                "-c", 
                                "hyprctl reload && notify-send 'Configuration' 'Hyprland et Quickshell rechargés !' -i display && (pkill quickshell; quickshell &)"
                            ])
                        }

                        Image {
                            id: reloadHyprIcon
                            anchors.centerIn: parent
                            source: "../icons/reload.svg"  
                            width: parent.width - 40
                            height: parent.height - 40
                            visible: false    
                            sourceSize.width: width
                            sourceSize.height: height
                        }

                        ColorOverlay {
                            anchors.fill: reloadHyprIcon
                            source: reloadHyprIcon
                            color: Colors.subtext1
                        }
                    }
                }
            }
            
            // Bottom sliders panel
            Rectangle {
                id: bottomPanel
                height: 430
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
                    anchors.bottom: parent.bottom
                    border.width: 1
                    border.color: Colors.surface2
                    anchors.margins: 10

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
                    anchors.bottom: parent.bottom
                    border.width: 1
                    border.color: Colors.surface2
                    anchors.margins: 10

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
                            if (pressed)
                                updateBrightness(mouse.y)
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
        }
    }
}