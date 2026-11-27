import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.configs
import qs.services
import qs.components

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

  Variants {
    model: Quickshell.screens

    Scope {
      id: screenScope
      required property var modelData
      readonly property real frameInset: 0

      // TOP-LEFT WORKSPACE PANEL WINDOW
      PanelWindow {
        id: topBarWindow
        screen: screenScope.modelData

        readonly property var screenWorkspaces: NiriService.workspaces.filter(ws => ws.output === screenScope.modelData.name)

        anchors {
          top: true
          left: true
        }

        margins {
          top: 0
          left: screenScope.frameInset
        }

        implicitWidth: 320
        implicitHeight: 58 + screenScope.frameInset
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        mask: Region {
          item: topLeftTab
        }

        DockedCornerTab {
          id: topLeftTab
          anchors.top: parent.top
          anchors.left: parent.left
          edge: "left"
          verticalEdge: "top"
          frameInset: screenScope.frameInset
          forceExpanded: NiriService.overviewOpen
          collapsedWidthRatio: 0.65

          RowLayout {
            spacing: 6

            Repeater {
              model: topBarWindow.screenWorkspaces

              Rectangle {
                required property var modelData
                readonly property bool isFocused: Boolean(modelData.is_focused)
                readonly property bool isOccupied: modelData.active_window_id !== null && modelData.active_window_id !== undefined

                Layout.preferredWidth: isFocused ? 22 : (isOccupied ? 10 : 7)
                Layout.preferredHeight: 7
                radius: 3.5
                color: isFocused ? Color.primary : (isOccupied ? Color.text : Color.subtle)
                opacity: isFocused ? 1.0 : (isOccupied ? 0.85 : 0.5)

                Behavior on Layout.preferredWidth {
                  NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                  }
                }

                Behavior on color {
                  ColorAnimation {
                    duration: 140
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -3
                  cursorShape: Qt.PointingHandCursor
                  onClicked: NiriService.focusWorkspace(modelData.idx)
                }
              }
            }
          }
        }
      }

      // BOTTOM BAR PANEL WINDOW (Clock & Status)
      PanelWindow {
        id: bottomBarWindow
        screen: screenScope.modelData

        anchors {
          left: true
          right: true
          bottom: true
        }

        margins {
          left: screenScope.frameInset
          right: screenScope.frameInset
          bottom: 0
        }

        implicitHeight: 58 + screenScope.frameInset
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        mask: Region {
          regions: [
            Region {
              item: bottomLeftTab
            },
            Region {
              item: rightTab
            }
          ]
        }

        // BOTTOM-LEFT CORNER TAB: Clock & Date
        DockedCornerTab {
          id: bottomLeftTab
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          edge: "left"
          verticalEdge: "bottom"
          frameInset: screenScope.frameInset
          forceExpanded: NiriService.overviewOpen
          collapsedWidthRatio: 0.55

          RowLayout {
            spacing: 8

            ColumnLayout {
              spacing: -1
              Layout.alignment: Qt.AlignVCenter

              Text {
                text: DateTimeService.dayName
                font.family: Config.textFont
                font.pixelSize: 9
                font.bold: true
                color: Color.primary
                lineHeight: 1.0
              }

              Text {
                text: DateTimeService.shortDate
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
              text: DateTimeService.time12h
              font.family: Config.textFont
              font.pixelSize: 13
              font.bold: true
              color: Color.text
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        // BOTTOM-RIGHT CORNER TAB: Battery + Wi-Fi/Bluetooth
        DockedCornerTab {
          id: rightTab
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          edge: "right"
          verticalEdge: "bottom"
          frameInset: screenScope.frameInset
          forceExpanded: NiriService.overviewOpen
          collapsedWidthRatio: 0.6

          readonly property color batAccentColor: {
            if (root.batCharging)
              return Color.primary;
            if (root.batPercentage <= 20)
              return Color.error;
            if (root.batPercentage <= 35)
              return Color.warning;
            return Color.primary;
          }

          RowLayout {
            spacing: 12

            // Battery Section
            ColumnLayout {
              visible: root.hasBattery
              spacing: -2
              Layout.alignment: Qt.AlignVCenter

              RowLayout {
                spacing: 2
                Layout.alignment: Qt.AlignRight

                Text {
                  visible: root.batCharging
                  text: "bolt"
                  font.family: Config.iconFont
                  font.pixelSize: 9
                  color: rightTab.batAccentColor
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  text: root.batCharging ? "PWR" : "BAT"
                  font.family: Config.textFont
                  font.pixelSize: 8
                  font.bold: true
                  color: rightTab.batAccentColor
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

            // Subtle divider between Battery and Connectivity
            Rectangle {
              visible: root.hasBattery
              implicitWidth: 1
              implicitHeight: 16
              color: Color.subtle
              opacity: 0.7
              Layout.alignment: Qt.AlignVCenter
            }

            // Wi-Fi Icon
            Text {
              text: root.wifiConnected ? "wifi" : "wifi_off"
              font.family: Config.iconFont
              font.pixelSize: 18
              color: root.wifiConnected ? Color.primary : Color.error
              Layout.alignment: Qt.AlignVCenter
            }

            // Bluetooth Icon
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
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }
      }
    }
  }
}
