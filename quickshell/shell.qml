import Quickshell
import "./config"
import "./components"
import "./services" as Services

ShellRoot {
    Bar {
        id: bar
        panel: controlPanel
    }
    ControlPanel {
        id: controlPanel
    }
}
