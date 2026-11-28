import QtQuick
import QtQuick.Layouts
import qs.configs
import qs.services
import qs.components

WidgetPill {
  id: root

  readonly property int pct: BatteryService.percentage
  readonly property bool charging: BatteryService.charging
  readonly property bool low: BatteryService.low
  readonly property bool warning: BatteryService.warning
  readonly property color accentColor: {
    if (root.charging)
      return Color.primary;
    if (root.low)
      return Color.error;
    if (root.warning)
      return Color.warning;
    return Color.primary;
  }

  visible: BatteryService.hasBattery
  inner: true
  contentImplicitWidth: batCol.implicitWidth

  ColumnLayout {
    id: batCol
    anchors.centerIn: parent
    spacing: Math.round(-2 * root.uiScale)

    RowLayout {
      spacing: Math.round(2 * root.uiScale)
      Layout.alignment: Qt.AlignRight

      Text {
        visible: root.charging
        text: "\ue3e7"
        font.family: Config.iconFont
        font.pixelSize: Math.max(8, Math.round(9 * root.uiScale))
        color: root.accentColor
        verticalAlignment: Text.AlignVCenter
      }

      Text {
        text: root.charging ? "PWR" : "BAT"
        font.family: Config.textFont
        font.pixelSize: Math.max(7, Math.round(8 * root.uiScale))
        font.bold: true
        color: root.accentColor
        lineHeight: 1.0
        verticalAlignment: Text.AlignVCenter
      }
    }

    Text {
      text: root.pct + "%"
      font.family: Config.textFont
      font.pixelSize: Math.max(10, Math.round(11 * root.uiScale))
      font.weight: Font.DemiBold
      color: Color.text
      lineHeight: 1.0
      Layout.alignment: Qt.AlignHCenter
    }
  }
}
