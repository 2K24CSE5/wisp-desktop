import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.configs

Scope {
  id: root

  property bool wifiConnected: true
  property string wifiSsid: ""
  property bool btEnabled: false
  property bool btConnected: false
  property string btDevice: ""
  property bool hasBattery: false
  property int batPercentage: 0
  property bool batCharging: false

  Process {
    id: wifiCheck
    command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const ssid = data.trim();
        root.wifiConnected = ssid.length > 0;
        root.wifiSsid = ssid;
      }
    }
  }

  Process {
    id: btCheck
    command: ["sh", "-c", "powered=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0); dev=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-); echo \"$powered|$dev\""]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split("|");
        root.btEnabled = parts[0] === "1";
        root.btDevice = parts.length > 1 ? parts[1].trim() : "";
        root.btConnected = root.btEnabled && root.btDevice.length > 0;
      }
    }
  }

  Process {
    id: batCheck
    command: ["sh", "-c", "bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); if [ -n \"$bat\" ]; then echo \"1|$(cat \"$bat/capacity\")|$(cat \"$bat/status\")\"; else echo \"0|0|\"; fi"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const parts = data.trim().split("|");
        root.hasBattery = parts[0] === "1";
        root.batPercentage = parseInt(parts[1], 10) || 0;
        const status = parts.length > 2 ? parts[2].trim() : "";
        root.batCharging = status === "Charging" || status === "Full";
      }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: {
      wifiCheck.running = true;
      btCheck.running = true;
      batCheck.running = true;
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors {
        left: true
        right: true
        bottom: true
      }

      margins {
        left: 4
        right: 4
        bottom: 4
      }

      implicitHeight: 46
      color: "transparent"
      exclusionMode: ExclusionMode.Auto

      RowLayout {
        anchors.fill: parent
        spacing: 6

        // LEFT PILL: Clock & Date
        Rectangle {
          id: clockPill
          Layout.preferredHeight: 44
          Layout.preferredWidth: clockRow.implicitWidth + 24
          radius: 16
          color: Color.background

          RowLayout {
            id: clockRow
            anchors.centerIn: parent
            spacing: 8

            ColumnLayout {
              spacing: -1
              Layout.alignment: Qt.AlignVCenter

              Text {
                text: Qt.formatDateTime(clock.date, "dddd")
                font.family: Config.textFont
                font.pixelSize: 9
                font.bold: true
                color: Color.primary
                lineHeight: 1.0
              }

              Text {
                text: Qt.formatDateTime(clock.date, "MMM d")
                font.family: Config.textFont
                font.pixelSize: 10
                color: Color.text
                lineHeight: 1.0
              }
            }

            Rectangle {
              implicitWidth: 1
              implicitHeight: 14
              color: Color.subtle
              opacity: 0.8
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              text: Qt.formatDateTime(clock.date, "hh:mm AP")
              font.family: Config.textFont
              font.pixelSize: 13
              font.bold: true
              color: Color.text
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        // Spacer pushing the right pills to the far right edge
        Item {
          Layout.fillWidth: true
        }

        // RIGHT GROUP: Battery + Wi-Fi/Bluetooth (2px gap, 4px inner radius)
        RowLayout {
          spacing: 2

          // RIGHT PILL 1: Battery
          Rectangle {
            id: batPill
            visible: root.hasBattery
            Layout.preferredHeight: 44
            Layout.preferredWidth: batCol.implicitWidth + 24
            topLeftRadius: 16
            bottomLeftRadius: 16
            topRightRadius: 4
            bottomRightRadius: 4
            color: batMouse.containsMouse ? Color.surface : Color.background

            Behavior on color {
              ColorAnimation {
                duration: 150
              }
            }

            readonly property color accentColor: {
              if (root.batCharging)
                return Color.primary;
              if (root.batPercentage <= 20)
                return Color.error;
              if (root.batPercentage <= 35)
                return Color.warning;
              return Color.primary;
            }

            ColumnLayout {
              id: batCol
              anchors.centerIn: parent
              spacing: -2

              RowLayout {
                spacing: 2
                Layout.alignment: Qt.AlignRight

                Text {
                  visible: root.batCharging
                  text: "bolt"
                  font.family: Config.iconFont
                  font.pixelSize: 9
                  color: batPill.accentColor
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  text: root.batCharging ? "PWR" : "BAT"
                  font.family: Config.textFont
                  font.pixelSize: 8
                  font.bold: true
                  color: batPill.accentColor
                  lineHeight: 1.0
                  verticalAlignment: Text.AlignVCenter
                }
              }

              Text {
                text: root.batPercentage + "%"
                font.family: Config.textFont
                font.pixelSize: 11
                font.bold: true
                color: Color.text
                lineHeight: 1.0
                Layout.alignment: Qt.AlignLeft
              }
            }

            MouseArea {
              id: batMouse
              anchors.fill: parent
              hoverEnabled: true
            }
          }

          // RIGHT PILL 2: Wi-Fi & Bluetooth Status
          Rectangle {
            id: statusPill
            Layout.preferredHeight: 44
            Layout.preferredWidth: statusRow.implicitWidth + 28
            topLeftRadius: root.hasBattery ? 4 : 16
            bottomLeftRadius: root.hasBattery ? 4 : 16
            topRightRadius: 16
            bottomRightRadius: 16
            color: statusMouse.containsMouse ? Color.surface : Color.background

            Behavior on color {
              ColorAnimation {
                duration: 150
              }
            }

            RowLayout {
              id: statusRow
              anchors.centerIn: parent
              spacing: 10

              // Wi-Fi Section
              RowLayout {
                spacing: 6

                Text {
                  text: root.wifiConnected ? "wifi" : "wifi_off"
                  font.family: Config.iconFont
                  font.pixelSize: 18
                  color: root.wifiConnected ? Color.primary : Color.error
                }

                Text {
                  visible: statusMouse.containsMouse && root.wifiSsid !== ""
                  text: root.wifiSsid
                  font.family: Config.textFont
                  font.pixelSize: 12
                  font.weight: Font.Medium
                  color: Color.text
                }
              }

              // Bluetooth Section
              RowLayout {
                spacing: 6

                Text {
                  text: {
                    if (root.btConnected)
                      return "bluetooth_connected";
                    if (root.btEnabled)
                      return "bluetooth";
                    return "bluetooth_disabled";
                  }
                  font.family: Config.iconFont
                  font.pixelSize: 18
                  color: {
                    if (!root.btEnabled)
                      return Color.muted;
                    return root.btConnected ? Color.primary : Color.text;
                  }
                }

                Text {
                  visible: statusMouse.containsMouse && root.btDevice !== ""
                  text: root.btDevice
                  font.family: Config.textFont
                  font.pixelSize: 12
                  font.weight: Font.Medium
                  color: Color.text
                }
              }
            }

            MouseArea {
              id: statusMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                  Quickshell.execDetached(["blueman-manager"]);
                } else {
                  Quickshell.execDetached(["nm-connection-editor"]);
                }
              }
            }
          }
        }
      }
    }
  }
}
