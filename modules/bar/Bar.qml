import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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

      // TOP BAR PANEL WINDOW (Workspaces & Notifications)
      PanelWindow {
        id: topBarWindow
        screen: screenScope.modelData

        readonly property var screenWorkspaces: NiriService.workspaces.filter(ws => ws.output === screenScope.modelData.name)

        anchors {
          top: true
          left: true
          right: true
        }

        margins {
          top: 0
          left: screenScope.frameInset
          right: screenScope.frameInset
        }

        implicitHeight: 58 + screenScope.frameInset
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        mask: Region {
          regions: [
            Region {
              item: topLeftTab
            },
            Region {
              item: topRightTab
            }
          ]
        }

        // TOP-LEFT CORNER TAB: Workspaces
        DockedCornerTab {
          id: topLeftTab
          anchors.top: parent.top
          anchors.left: parent.left
          edge: "left"
          verticalEdge: "top"
          frameInset: screenScope.frameInset
          forceExpanded: NiriService.overviewOpen

          RowLayout {
            spacing: 7

            Repeater {
              model: topBarWindow.screenWorkspaces

              Rectangle {
                id: wsPill
                required property var modelData
                readonly property bool isFocused: Boolean(modelData.is_focused)
                readonly property bool isOccupied: modelData.active_window_id !== null && modelData.active_window_id !== undefined

                Layout.preferredWidth: isFocused ? 30 : 12
                Layout.preferredHeight: 12
                radius: height / 2
                color: {
                  if (isFocused)
                    return Color.primary;
                  if (wsMouse.containsMouse)
                    return Color.overlay;
                  if (isOccupied)
                    return Color.text;
                  return Color.subtle;
                }
                opacity: isFocused ? 1.0 : (isOccupied ? 0.85 : (wsMouse.containsMouse ? 0.9 : 0.5))
                scale: wsMouse.pressed ? 0.92 : 1.0

                Behavior on Layout.preferredWidth {
                  NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                  }
                }

                Behavior on color {
                  ColorAnimation {
                    duration: 150
                  }
                }

                Behavior on opacity {
                  NumberAnimation {
                    duration: 150
                  }
                }

                Behavior on scale {
                  NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutQuad
                  }
                }

                MouseArea {
                  id: wsMouse
                  anchors.fill: parent
                  anchors.margins: -3
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: NiriService.focusWorkspace(modelData.idx)
                }
              }
            }
          }

          WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
              if (event.angleDelta.y > 0) {
                NiriService.focusPreviousWorkspace();
              } else if (event.angleDelta.y < 0) {
                NiriService.focusNextWorkspace();
              }
            }
          }
        }

        // TOP-RIGHT CORNER TAB: Notifications
        DockedCornerTab {
          id: topRightTab
          anchors.top: parent.top
          anchors.right: parent.right
          edge: "right"
          verticalEdge: "top"
          frameInset: screenScope.frameInset
          forceExpanded: NiriService.overviewOpen || NotificationService.centerOpen

          Item {
            implicitWidth: 20
            implicitHeight: 20

            Text {
              anchors.centerIn: parent
              text: NotificationService.doNotDisturb ? "notifications_off" : "notifications"
              font.family: Config.iconFont
              font.pixelSize: 18
              color: NotificationService.doNotDisturb ? Color.muted : Color.text
            }

            // Unread badge dot
            Rectangle {
              visible: NotificationService.unreadCount > 0 && !NotificationService.doNotDisturb
              width: 6
              height: 6
              radius: 3
              color: Color.error
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.topMargin: 1
              anchors.rightMargin: 1
            }

            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: NotificationService.toggleCenter()
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
