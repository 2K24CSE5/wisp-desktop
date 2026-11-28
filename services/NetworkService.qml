pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool wifiEnabled: true
  property bool connected: false
  property string ssid: ""
  property int signalStrength: 0
  property string deviceName: ""
  property bool scanning: false
  property var networks: []

  function refresh(): void {
    statusCheck.running = true;
  }

  function scan(): void {
    if (root.scanning)
      return;
    root.scanning = true;
    scanProcess.running = true;
  }

  function toggleWifi(): void {
    setWifiEnabled(!root.wifiEnabled);
  }

  function setWifiEnabled(enabled: bool): void {
    root.wifiEnabled = enabled;
    if (!enabled) {
      root.connected = false;
      root.ssid = "";
      root.signalStrength = 0;
      root.networks = [];
    }
    Quickshell.execDetached(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
    delayedRefresh.restart();
  }

  function connect(targetSsid: string, password: string): void {
    if (!targetSsid)
      return;
    if (password && password.length > 0) {
      Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", targetSsid, "password", password]);
    } else {
      Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", targetSsid]);
    }
    delayedRefresh.restart();
  }

  function disconnect(): void {
    if (root.deviceName.length > 0) {
      Quickshell.execDetached(["nmcli", "dev", "disconnect", root.deviceName]);
      delayedRefresh.restart();
    }
  }

  Process {
    id: statusCheck
    command: ["sh", "-c", "radio=$(nmcli radio wifi 2>/dev/null | tr -d '[:space:]'); active=$(nmcli -t -f ACTIVE,SSID,SIGNAL,DEVICE dev wifi 2>/dev/null | grep '^yes:' | head -n1); echo \"$radio|$active\""]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        const pipeIdx = line.indexOf("|");
        if (pipeIdx === -1)
          return;

        const radio = line.slice(0, pipeIdx);
        const active = line.slice(pipeIdx + 1);
        root.wifiEnabled = (radio === "enabled");

        if (root.wifiEnabled && active.startsWith("yes:")) {
          const parts = active.split(":");
          root.connected = true;
          root.ssid = parts[1] || "";
          root.signalStrength = parseInt(parts[2], 10) || 0;
          root.deviceName = parts[3] || "";
        } else {
          root.connected = false;
          root.ssid = "";
          root.signalStrength = 0;
        }
      }
    }
  }

  Process {
    id: scanProcess
    command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
    running: false

    property var buffer: []

    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (!line)
          return;
        const parts = line.split(":");
        const ssid = parts[1] || "";
        if (!ssid)
          return;

        const isActive = parts[0] === "yes";
        const signal = parseInt(parts[2], 10) || 0;
        const security = parts[3] || "";

        const existingIdx = scanProcess.buffer.findIndex(item => item.ssid === ssid);
        if (existingIdx !== -1) {
          if (isActive || signal > scanProcess.buffer[existingIdx].signal) {
            scanProcess.buffer[existingIdx] = {
              ssid: ssid,
              signal: signal,
              security: security,
              active: isActive
            };
          }
        } else {
          scanProcess.buffer.push({
            ssid: ssid,
            signal: signal,
            security: security,
            active: isActive
          });
        }
      }
    }

    onExited: {
      const sorted = scanProcess.buffer.slice().sort((a, b) => {
        if (a.active !== b.active)
          return a.active ? -1 : 1;
        return b.signal - a.signal;
      });
      root.networks = sorted;
      scanProcess.buffer = [];
      root.scanning = false;
      root.refresh();
    }
  }

  Timer {
    id: pollTimer
    interval: 5000
    running: true
    repeat: true
    onTriggered: statusCheck.running = true
  }

  Timer {
    id: delayedRefresh
    interval: 1500
    repeat: false
    onTriggered: {
      statusCheck.running = true;
      if (root.wifiEnabled)
        root.scan();
    }
  }
}
