pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool hasBattery: false
  property int percentage: 0
  property string status: ""
  property bool charging: false
  property bool full: false
  property bool low: hasBattery && !charging && percentage <= 20
  property bool warning: hasBattery && !charging && percentage > 20 && percentage <= 35

  function refresh(): void {
    batCheck.running = true;
  }

  Process {
    id: batCheck
    command: ["sh", "-c", "bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); if [ -n \"$bat\" ]; then echo \"1|$(cat \"$bat/capacity\")|$(cat \"$bat/status\")\"; else echo \"0|0|\"; fi"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split("|");
        root.hasBattery = parts[0] === "1";
        root.percentage = parseInt(parts[1], 10) || 0;
        const rawStatus = parts.length > 2 ? parts[2].trim() : "";
        root.status = rawStatus;
        root.full = (rawStatus === "Full");
        root.charging = (rawStatus === "Charging" || rawStatus === "Full");
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 5000
    running: true
    repeat: true
    onTriggered: batCheck.running = true
  }
}
