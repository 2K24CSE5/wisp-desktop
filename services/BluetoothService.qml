pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool enabled: false
  property bool connected: false
  property string connectedDevice: ""
  property string connectedAddress: ""
  property bool scanning: false
  property var devices: []

  function refresh(): void {
    statusCheck.running = true;
  }

  function togglePower(): void {
    setPowered(!root.enabled);
  }

  function setPowered(powered: bool): void {
    root.enabled = powered;
    if (!powered) {
      root.connected = false;
      root.connectedDevice = "";
      root.connectedAddress = "";
      root.scanning = false;
    }
    Quickshell.execDetached(["bluetoothctl", "power", powered ? "on" : "off"]);
    delayedRefresh.restart();
  }

  function startScan(): void {
    if (!root.enabled || root.scanning)
      return;
    root.scanning = true;
    scanProcess.running = true;
  }

  function connectDevice(address: string): void {
    if (!address)
      return;
    Quickshell.execDetached(["bluetoothctl", "connect", address]);
    delayedRefresh.restart();
  }

  function disconnectDevice(address: string): void {
    const target = address || root.connectedAddress;
    if (!target)
      return;
    Quickshell.execDetached(["bluetoothctl", "disconnect", target]);
    delayedRefresh.restart();
  }

  Process {
    id: statusCheck
    command: ["sh", "-c", "powered=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0); conn_line=$(bluetoothctl devices Connected 2>/dev/null | head -n1); addr=$(echo \"$conn_line\" | awk '{print $2}'); name=$(echo \"$conn_line\" | cut -d' ' -f3-); echo \"$powered|$addr|$name\""]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split("|");
        root.enabled = (parts[0] === "1");
        root.connectedAddress = root.enabled ? (parts[1] || "").trim() : "";
        root.connectedDevice = root.enabled ? (parts[2] || "").trim() : "";
        root.connected = root.enabled && root.connectedAddress.length > 0;
        if (root.enabled) {
          deviceListProcess.running = true;
        } else {
          root.devices = [];
        }
      }
    }
  }

  Process {
    id: deviceListProcess
    command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do [ -z \"$mac\" ] && continue; info=$(bluetoothctl info \"$mac\" 2>/dev/null); conn=$(echo \"$info\" | grep -q 'Connected: yes' && echo 1 || echo 0); paired=$(echo \"$info\" | grep -q 'Paired: yes' && echo 1 || echo 0); icon=$(echo \"$info\" | awk -F': ' '/Icon:/{print $2; exit}'); echo \"$mac|$conn|$paired|$icon|$name\"; done"]
    running: false

    property var buffer: []

    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (!line)
          return;
        const parts = line.split("|");
        if (parts.length < 5)
          return;
        deviceListProcess.buffer.push({
          address: parts[0],
          connected: parts[1] === "1",
          paired: parts[2] === "1",
          icon: parts[3] || "bluetooth",
          name: parts.slice(4).join("|")
        });
      }
    }

    onExited: {
      const sorted = deviceListProcess.buffer.slice().sort((a, b) => {
        if (a.connected !== b.connected)
          return a.connected ? -1 : 1;
        if (a.paired !== b.paired)
          return a.paired ? -1 : 1;
        return a.name.localeCompare(b.name);
      });
      root.devices = sorted;
      deviceListProcess.buffer = [];
    }
  }

  Process {
    id: scanProcess
    command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
    running: false
    onExited: {
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
    onTriggered: statusCheck.running = true
  }
}
