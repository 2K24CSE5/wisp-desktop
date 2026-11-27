pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property bool overviewOpen: false

  Process {
    id: eventStream
    command: ["niri", "msg", "--json", "event-stream"]
    running: true

    onExited: restartTimer.restart()

    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (!line)
          return;

        try {
          const event = JSON.parse(line);
          if (event.OverviewOpenedOrClosed !== undefined) {
            root.overviewOpen = Boolean(event.OverviewOpenedOrClosed.is_open);
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    id: restartTimer
    interval: 1000
    repeat: false
    onTriggered: eventStream.running = true
  }
}
