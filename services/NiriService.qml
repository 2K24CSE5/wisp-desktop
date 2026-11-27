pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool overviewOpen: false
  property var workspaces: []

  function focusWorkspace(idx) {
    Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
  }

  function handleEvent(line) {
    const trimmed = line.trim();
    if (!trimmed)
      return;

    try {
      const ev = JSON.parse(trimmed);
      if (ev.OverviewOpenedOrClosed !== undefined) {
        root.overviewOpen = Boolean(ev.OverviewOpenedOrClosed.is_open);
      } else if (ev.WorkspacesChanged !== undefined) {
        const list = ev.WorkspacesChanged.workspaces.slice();
        list.sort((a, b) => a.idx - b.idx);
        root.workspaces = list;
      } else if (ev.WorkspaceActivated !== undefined) {
        const activeId = ev.WorkspaceActivated.id;
        const focused = Boolean(ev.WorkspaceActivated.focused);
        root.workspaces = root.workspaces.map(ws => {
          const copy = Object.assign({}, ws);
          if (ws.id === activeId) {
            copy.is_active = true;
            if (focused)
              copy.is_focused = true;
          } else if (focused) {
            copy.is_focused = false;
            if (ws.output === copy.output)
              copy.is_active = false;
          }
          return copy;
        });
      }
    } catch (e) {}
  }

  Process {
    id: eventStream
    command: ["niri", "msg", "-j", "event-stream"]
    running: true

    stdout: SplitParser {
      onRead: data => root.handleEvent(data)
    }

    onExited: restartTimer.start()
  }

  Timer {
    id: restartTimer
    interval: 1000
    repeat: false
    onTriggered: eventStream.running = true
  }
}
