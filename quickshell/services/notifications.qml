pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property alias list: notifServer.trackedNotifications
    property int count: notifServer.trackedNotifications.count

    NotificationServer {
        id: notifServer

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: (notification) => {
            notification.tracked = true
        }
    }

    function discard(id) {
        for (let i = 0; i < notifServer.trackedNotifications.count; i++) {
            let n = notifServer.trackedNotifications.get(i)
            if (n.id === id) {
                n.dismiss()
                return
            }
        }
    }

    function discardAll() {
        while (notifServer.trackedNotifications.count > 0) {
            notifServer.trackedNotifications.get(0).dismiss()
        }
    }
}