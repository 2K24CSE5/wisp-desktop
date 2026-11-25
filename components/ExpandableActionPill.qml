import QtQuick
import QtQuick.Layouts
import qs.configs

Rectangle {
  id: root

  property real uiScale: 1.0
  property bool expanded: false
  property string triggerIcon: "power_settings_new"
  property string closeIcon: "close"
  property var actions: [] // Array of { icon: string, label: string, action: function }

  readonly property int barHeight: Math.round((48 * uiScale) / 2) * 2
  readonly property int innerInset: Math.max(4, Math.round(barHeight * 0.10))
  readonly property int innerHeight: barHeight - innerInset * 2

  signal toggled(bool isExpanded)

  height: barHeight
  width: row.implicitWidth + innerInset * 2
  radius: height / 2
  color: Color.background
  clip: true

  Behavior on width {
    NumberAnimation {
      duration: 240
      easing.type: Easing.OutBack
      easing.overshoot: 0.7
    }
  }
  Behavior on border.color {
    ColorAnimation {
      duration: 150
    }
  }

  RowLayout {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: root.innerInset
    spacing: Math.round(4 * root.uiScale)

    // Primary Trigger / Close Circle
    Rectangle {
      Layout.preferredWidth: root.innerHeight
      Layout.preferredHeight: root.innerHeight
      radius: width / 2
      color: root.expanded ? Color.primary : (triggerMouse.containsMouse ? Color.surface : "transparent")
      scale: triggerMouse.pressed ? 0.90 : 1.0

      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: 150
          easing.type: Easing.OutQuad
        }
      }

      Text {
        anchors.centerIn: parent
        text: root.expanded ? root.closeIcon : root.triggerIcon
        font.family: Config.iconFont
        font.pixelSize: Math.round(20 * root.uiScale)
        color: root.expanded ? Color.background : (triggerMouse.containsMouse ? Color.primary : Color.text)
      }

      MouseArea {
        id: triggerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.expanded = !root.expanded;
          root.toggled(root.expanded);
        }
      }
    }

    // Expanded Action Chips
    Repeater {
      model: root.actions

      delegate: Rectangle {
        required property var modelData
        required property int index
        visible: root.expanded
        Layout.preferredWidth: chipContent.implicitWidth + Math.round(20 * root.uiScale)
        Layout.preferredHeight: root.innerHeight
        radius: height / 2
        color: chipMouse.containsMouse ? Color.surface : "transparent"
        scale: chipMouse.pressed ? 0.94 : 1.0

        Behavior on color {
          ColorAnimation {
            duration: 140
          }
        }
        Behavior on scale {
          NumberAnimation {
            duration: 140
            easing.type: Easing.OutQuad
          }
        }

        RowLayout {
          id: chipContent
          anchors.centerIn: parent
          spacing: Math.round(6 * root.uiScale)

          Text {
            text: modelData.icon ?? ""
            visible: text.length > 0
            font.family: Config.iconFont
            font.pixelSize: Math.round(18 * root.uiScale)
            color: chipMouse.containsMouse ? Color.primary : Color.secondary
          }

          Text {
            text: modelData.label ?? ""
            font.family: Config.textFont
            font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
            font.weight: Font.Medium
            color: Color.text
          }
        }

        MouseArea {
          id: chipMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.expanded = false;
            root.toggled(false);
            if (typeof modelData.action === "function")
              modelData.action();
          }
        }
      }
    }
  }
}
