import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.configs

ColumnLayout {
  id: root

  property real uiScale: 1.0

  readonly property var dev: UPower.displayDevice
  readonly property int pct: dev ? Math.round(dev.percentage * 100) : 0
  readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
  readonly property real energyRate: dev ? Math.abs(dev.changeRate) : 0
  readonly property real healthPct: (dev && dev.energyFullDesign > 0) ? Math.round((dev.energyFull / dev.energyFullDesign) * 100) : 0

  function formatDuration(seconds: real): string {
    if (!seconds || seconds <= 0)
      return "Calculating…";
    const totalMins = Math.round(seconds / 60);
    const hrs = Math.floor(totalMins / 60);
    const mins = totalMins % 60;
    if (hrs > 0)
      return hrs + "h " + mins + "m";
    return mins + "m";
  }

  spacing: Math.round(14 * uiScale)

  // Header
  RowLayout {
    Layout.fillWidth: true
    spacing: Math.round(10 * root.uiScale)

    Text {
      text: "Battery & Power"
      font.family: Config.textFont
      font.pixelSize: Math.max(17, Math.round(20 * root.uiScale))
      font.weight: Font.Bold
      color: Color.text
      Layout.fillWidth: true
    }

    Rectangle {
      implicitWidth: stateLabel.implicitWidth + Math.round(18 * root.uiScale)
      Layout.preferredHeight: Math.round(28 * root.uiScale)
      radius: height / 2
      color: root.charging ? Color.primary : Color.surface

      Text {
        id: stateLabel
        anchors.centerIn: parent
        text: {
          if (!root.dev)
            return "Unavailable";
          if (root.dev.state === UPowerDeviceState.FullyCharged)
            return "Full";
          if (root.dev.state === UPowerDeviceState.Charging)
            return "Charging";
          return "Discharging";
        }
        font.family: Config.textFont
        font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
        font.weight: Font.DemiBold
        color: root.charging ? Color.background : Color.secondary
      }
    }
  }

  // Hero Charge Progress Card
  Rectangle {
    Layout.fillWidth: true
    implicitHeight: heroCol.implicitHeight + Math.round(28 * root.uiScale)
    radius: Math.round(22 * root.uiScale)
    color: Color.surface

    ColumnLayout {
      id: heroCol
      anchors.fill: parent
      anchors.margins: Math.round(14 * root.uiScale)
      spacing: Math.round(10 * root.uiScale)

      RowLayout {
        Layout.fillWidth: true

        Text {
          text: root.pct + "%"
          font.family: Config.textFont
          font.pixelSize: Math.max(24, Math.round(28 * root.uiScale))
          font.weight: Font.Bold
          color: Color.text
          Layout.fillWidth: true
        }

        Text {
          text: root.charging ? ("Full in " + root.formatDuration(root.dev ? root.dev.timeToFull : 0)) : ("Remaining " + root.formatDuration(root.dev ? root.dev.timeToEmpty : 0))
          font.family: Config.textFont
          font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
          color: Color.muted
        }
      }

      // Expressive Progress Track
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(12 * root.uiScale)
        radius: height / 2
        color: Color.overlay
        clip: true

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.pct / 100)))
          radius: height / 2
          color: (!root.charging && root.pct <= 20) ? Color.error : Color.primary

          Behavior on width {
            NumberAnimation {
              duration: 240
              easing.type: Easing.OutCubic
            }
          }
        }
      }

      // Telemetry Metrics Row
      RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(12 * root.uiScale)

        Text {
          visible: root.energyRate > 0.1
          text: root.energyRate.toFixed(1) + " W"
          font.family: Config.textFont
          font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
          font.weight: Font.Medium
          color: Color.secondary
        }

        Item {
          Layout.fillWidth: true
        }

        Text {
          visible: root.healthPct > 0
          text: "Health " + root.healthPct + "%"
          font.family: Config.textFont
          font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
          font.weight: Font.Medium
          color: Color.muted
        }
      }
    }
  }

  // Power Profile Selector (PowerSaver / Balanced / Performance)
  ColumnLayout {
    visible: PowerProfiles.hasPerformanceProfile || true
    Layout.fillWidth: true
    spacing: Math.round(8 * root.uiScale)

    Text {
      text: "Power Profile"
      font.family: Config.textFont
      font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
      font.weight: Font.DemiBold
      color: Color.muted
      Layout.leftMargin: Math.round(4 * root.uiScale)
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(8 * root.uiScale)

      Repeater {
        model: [
          {
            label: "Saver",
            icon: "eco",
            profile: PowerProfile.PowerSaver,
            supported: true
          },
          {
            label: "Balanced",
            icon: "balance",
            profile: PowerProfile.Balanced,
            supported: true
          },
          {
            label: "Performance",
            icon: "bolt",
            profile: PowerProfile.Performance,
            supported: PowerProfiles.hasPerformanceProfile
          }
        ]

        Rectangle {
          required property var modelData
          readonly property bool selected: PowerProfiles.profile === modelData.profile

          visible: modelData.supported
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(44 * root.uiScale)
          radius: Math.round(16 * root.uiScale)
          color: selected ? Color.primary : (profMouse.containsMouse ? Color.overlay : Color.surface)

          Behavior on color {
            ColorAnimation {
              duration: 140
            }
          }

          RowLayout {
            anchors.centerIn: parent
            spacing: Math.round(6 * root.uiScale)

            Text {
              text: modelData.icon
              font.family: Config.iconFont
              font.pixelSize: Math.round(17 * root.uiScale)
              color: selected ? Color.background : Color.primary
            }

            Text {
              text: modelData.label
              font.family: Config.textFont
              font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
              font.weight: Font.DemiBold
              color: selected ? Color.background : Color.text
            }
          }

          MouseArea {
            id: profMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: PowerProfiles.profile = modelData.profile
          }
        }
      }
    }
  }
}
