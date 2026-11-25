import QtQuick
import QtQuick.Layouts
import qs.configs

Rectangle {
  id: root

  property real uiScale: 1.0
  property bool expanded: false
  property bool loading: false
  property string icon: "desktop_windows"
  property string loadingText: "Loading"
  property string emptyText: "No options"
  property string labelRole: "name"
  property var items: []
  property int selectedIndex: -1
  property real maxExpandedWidth: 600

  readonly property int barHeight: Math.round((48 * uiScale) / 2) * 2
  readonly property int innerInset: Math.max(4, Math.round(barHeight * 0.10))
  readonly property int innerHeight: barHeight - innerInset * 2
  readonly property bool canExpand: !loading && items && items.length > 0
  readonly property string currentLabel: {
    if (loading)
      return loadingText;
    if (!items || items.length === 0 || selectedIndex < 0 || selectedIndex >= items.length)
      return emptyText;
    const item = items[selectedIndex];
    return typeof item === "string" ? item : (item[labelRole] ?? emptyText);
  }

  signal toggled(bool isExpanded)
  signal itemSelected(int index, var item)

  height: barHeight
  width: Math.min(maxExpandedWidth, row.implicitWidth + innerInset * 2)
  radius: height / 2
  color: pillMouse.containsMouse && !root.expanded ? Color.surface : Color.background
  clip: true

  Behavior on width {
    NumberAnimation {
      duration: 240
      easing.type: Easing.OutBack
      easing.overshoot: 0.7
    }
  }
  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  // Expand click area when collapsed
  MouseArea {
    id: pillMouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.canExpand && !root.expanded
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.expanded = true;
      root.toggled(true);
    }
  }

  RowLayout {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: root.innerInset
    spacing: Math.round(6 * root.uiScale)

    // Leading Icon (balanced with innerInset on the left)
    Item {
      Layout.preferredWidth: root.innerHeight * 0.78
      Layout.preferredHeight: root.innerHeight

      Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Config.iconFont
        font.pixelSize: Math.round(19 * root.uiScale)
        color: Color.primary
      }
    }

    // Collapsed Active Item Label
    Text {
      visible: !root.expanded
      text: root.currentLabel
      font.family: Config.textFont
      font.pixelSize: Math.max(12, Math.round(14 * root.uiScale))
      font.weight: Font.Medium
      color: Color.text
    }

    // Expanded Option Chips
    Repeater {
      model: root.expanded ? root.items : []

      delegate: Rectangle {
        required property var modelData
        required property int index
        readonly property bool isSelected: index === root.selectedIndex
        readonly property string itemLabel: typeof modelData === "string" ? modelData : (modelData[root.labelRole] ?? "")

        Layout.preferredWidth: optionLabel.implicitWidth + Math.round(20 * root.uiScale)
        Layout.preferredHeight: root.innerHeight
        radius: height / 2
        color: isSelected ? Color.primary : (optionMouse.containsMouse ? Color.surface : "transparent")
        scale: optionMouse.pressed ? 0.94 : 1.0

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

        Text {
          id: optionLabel
          anchors.centerIn: parent
          text: parent.itemLabel
          font.family: Config.textFont
          font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
          font.weight: parent.isSelected ? Font.DemiBold : Font.Medium
          color: parent.isSelected ? Color.background : Color.text
        }

        MouseArea {
          id: optionMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.expanded = false;
            root.toggled(false);
            root.itemSelected(index, modelData);
          }
        }
      }
    }

    // Expand / Collapse Indicator Button
    Rectangle {
      Layout.preferredWidth: root.innerHeight
      Layout.preferredHeight: root.innerHeight
      radius: width / 2
      color: closeMouse.containsMouse && root.expanded ? Color.surface : "transparent"

      Text {
        anchors.centerIn: parent
        text: root.expanded ? "close" : "expand_more"
        font.family: Config.iconFont
        font.pixelSize: Math.round(18 * root.uiScale)
        color: root.expanded ? Color.text : Color.muted
      }

      MouseArea {
        id: closeMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.expanded
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.expanded = false;
          root.toggled(false);
        }
      }
    }
  }
}
