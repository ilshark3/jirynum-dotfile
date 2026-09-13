import Quickshell
import "./config"
import "./components"

ShellRoot {
    Bar {
        id: bar
        panel: controlPanel
    }
    ControlPanel {
        id: controlPanel
    }
}