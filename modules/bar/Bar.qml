import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.configs
import qs.services

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

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData

      readonly property real frameInset: WallpaperService.initialInsetFor(modelData)

      anchors {
        left: true
        right: true
        bottom: true
      }

      margins {
        left: frameInset
        right: frameInset
        bottom: 0
      }

      implicitHeight: 58 + frameInset
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      // LEFT CORNER TAB: Clock & Date
      Rectangle {
        id: clockTab
        readonly property bool expanded: NiriService.overviewOpen || clockHover.hovered
        readonly property real fullWidth: clockRow.implicitWidth + 28
        readonly property real lineWidth: Math.round(fullWidth * 0.55)
        property real earRadius: expanded ? 14 : 0
        property color fillColor: expanded ? Color.background : Color.subtle

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: expanded ? (42 + barWindow.frameInset) : 4
        width: expanded ? fullWidth : lineWidth
        topLeftRadius: 0
        topRightRadius: expanded ? 14 : 2
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: fillColor
        clip: true

        Behavior on earRadius {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Behavior on fillColor {
          ColorAnimation {
            duration: 150
          }
        }

        Behavior on height {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Behavior on width {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Behavior on topRightRadius {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        HoverHandler {
          id: clockHover
        }

        RowLayout {
          id: clockRow
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: clockTab.expanded ? -(barWindow.frameInset * 0.5) : 0
          spacing: 8
          opacity: clockTab.expanded ? 1.0 : 0.0

          Behavior on opacity {
            NumberAnimation {
              duration: 140
            }
          }

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

      // Clock top-left concave curve (flares upward along left wallpaper frame)
      Shape {
        anchors.left: clockTab.left
        anchors.bottom: clockTab.top
        anchors.bottomMargin: -1
        width: clockTab.earRadius
        height: clockTab.earRadius + 1
        visible: clockTab.earRadius > 0.2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeWidth: 0
          fillColor: clockTab.fillColor
          startX: 0
          startY: 0
          PathArc {
            x: clockTab.earRadius
            y: clockTab.earRadius
            radiusX: clockTab.earRadius
            radiusY: clockTab.earRadius
            direction: PathArc.Counterclockwise
          }
          PathLine {
            x: clockTab.earRadius
            y: clockTab.earRadius + 1
          }
          PathLine {
            x: 0
            y: clockTab.earRadius + 1
          }
          PathLine {
            x: 0
            y: 0
          }
        }
      }

      // Clock bottom-right concave curve (sits flush on top of the bottom frame)
      Shape {
        anchors.left: clockTab.right
        anchors.leftMargin: -1
        anchors.bottom: clockTab.bottom
        anchors.bottomMargin: barWindow.frameInset
        width: clockTab.earRadius + 1
        height: clockTab.earRadius
        visible: clockTab.earRadius > 0.2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeWidth: 0
          fillColor: clockTab.fillColor
          startX: 1
          startY: 0
          PathArc {
            x: clockTab.earRadius + 1
            y: clockTab.earRadius
            radiusX: clockTab.earRadius
            radiusY: clockTab.earRadius
            direction: PathArc.Counterclockwise
          }
          PathLine {
            x: 0
            y: clockTab.earRadius
          }
          PathLine {
            x: 0
            y: 0
          }
          PathLine {
            x: 1
            y: 0
          }
        }
      }

      // RIGHT CORNER TAB: Battery + Wi-Fi/Bluetooth (mirrored symmetry with clockTab)
      Rectangle {
        id: rightTab
        readonly property bool expanded: NiriService.overviewOpen || rightHover.hovered
        readonly property real fullWidth: rightRow.implicitWidth + 28
        readonly property real lineWidth: Math.round(fullWidth * 0.6)
        property real earRadius: expanded ? 14 : 0
        property color fillColor: expanded ? Color.background : (root.wifiConnected ? Color.subtle : Color.error)

        readonly property color batAccentColor: {
          if (root.batCharging)
            return Color.primary;
          if (root.batPercentage <= 20)
            return Color.error;
          if (root.batPercentage <= 35)
            return Color.warning;
          return Color.primary;
        }

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: expanded ? (42 + barWindow.frameInset) : 4
        width: expanded ? fullWidth : lineWidth
        topLeftRadius: expanded ? 14 : 2
        topRightRadius: 0
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: fillColor
        clip: true

        Behavior on earRadius {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Behavior on fillColor {
          ColorAnimation {
            duration: 150
          }
        }

        Behavior on height {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Behavior on width {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Behavior on topLeftRadius {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        HoverHandler {
          id: rightHover
        }

        RowLayout {
          id: rightRow
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: rightTab.expanded ? -(barWindow.frameInset * 0.5) : 0
          spacing: 12
          opacity: rightTab.expanded ? 1.0 : 0.0

          Behavior on opacity {
            NumberAnimation {
              duration: 140
            }
          }

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

      // Right tab top-right concave curve (flares upward along right wallpaper frame)
      Shape {
        anchors.right: rightTab.right
        anchors.bottom: rightTab.top
        anchors.bottomMargin: -1
        width: rightTab.earRadius
        height: rightTab.earRadius + 1
        visible: rightTab.earRadius > 0.2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeWidth: 0
          fillColor: rightTab.fillColor
          startX: rightTab.earRadius
          startY: 0
          PathArc {
            x: 0
            y: rightTab.earRadius
            radiusX: rightTab.earRadius
            radiusY: rightTab.earRadius
            direction: PathArc.Clockwise
          }
          PathLine {
            x: 0
            y: rightTab.earRadius + 1
          }
          PathLine {
            x: rightTab.earRadius
            y: rightTab.earRadius + 1
          }
          PathLine {
            x: rightTab.earRadius
            y: 0
          }
        }
      }

      // Right tab bottom-left concave curve (sits flush on top of the bottom frame)
      Shape {
        anchors.right: rightTab.left
        anchors.rightMargin: -1
        anchors.bottom: rightTab.bottom
        anchors.bottomMargin: barWindow.frameInset
        width: rightTab.earRadius + 1
        height: rightTab.earRadius
        visible: rightTab.earRadius > 0.2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeWidth: 0
          fillColor: rightTab.fillColor
          startX: rightTab.earRadius
          startY: 0
          PathArc {
            x: 0
            y: rightTab.earRadius
            radiusX: rightTab.earRadius
            radiusY: rightTab.earRadius
            direction: PathArc.Clockwise
          }
          PathLine {
            x: rightTab.earRadius + 1
            y: rightTab.earRadius
          }
          PathLine {
            x: rightTab.earRadius + 1
            y: 0
          }
          PathLine {
            x: rightTab.earRadius
            y: 0
          }
        }
      }
    }
  }
}
