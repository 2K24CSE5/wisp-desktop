import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.configs
import qs.components

WidgetPill {
  id: root

  contentImplicitWidth: clockRow.implicitWidth

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  RowLayout {
    id: clockRow
    anchors.centerIn: parent
    spacing: Math.round(8 * root.uiScale)

    ColumnLayout {
      spacing: Math.round(-1 * root.uiScale)
      Layout.alignment: Qt.AlignVCenter

      Text {
        text: Qt.formatDateTime(clock.date, "ddd").toUpperCase()
        font.family: Config.textFont
        font.pixelSize: Math.max(8, Math.round(9 * root.uiScale))
        font.bold: true
        color: Color.primary
        lineHeight: 1.0
      }

      Text {
        text: Qt.formatDateTime(clock.date, "d MMM")
        font.family: Config.textFont
        font.pixelSize: Math.max(9, Math.round(10 * root.uiScale))
        font.weight: Font.Medium
        color: Color.text
        lineHeight: 1.0
      }
    }

    Rectangle {
      implicitWidth: 1
      implicitHeight: Math.round(14 * root.uiScale)
      color: Color.subtle
      opacity: 0.85
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      text: Qt.formatDateTime(clock.date, "hh:mm AP")
      font.family: Config.textFont
      font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
      font.bold: true
      color: Color.text
      verticalAlignment: Text.AlignVCenter
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
