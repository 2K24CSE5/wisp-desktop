import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.configs

ColumnLayout {
  id: root

  property real uiScale: 1.0
  property int monthOffset: 0

  readonly property date nowDate: clock.date
  readonly property date displayMonth: new Date(nowDate.getFullYear(), nowDate.getMonth() + monthOffset, 1)
  readonly property int displayYear: displayMonth.getFullYear()
  readonly property int displayMonthIdx: displayMonth.getMonth()

  readonly property var calendarCells: {
    const firstDay = new Date(displayYear, displayMonthIdx, 1).getDay();
    const daysInMonth = new Date(displayYear, displayMonthIdx + 1, 0).getDate();
    const daysInPrevMonth = new Date(displayYear, displayMonthIdx, 0).getDate();
    const cells = [];

    for (let i = firstDay - 1; i >= 0; i--) {
      cells.push({
        day: daysInPrevMonth - i,
        inMonth: false,
        isToday: false
      });
    }

    for (let d = 1; d <= daysInMonth; d++) {
      const isToday = (d === nowDate.getDate()) && (displayMonthIdx === nowDate.getMonth()) && (displayYear === nowDate.getFullYear());
      cells.push({
        day: d,
        inMonth: true,
        isToday: isToday
      });
    }

    while (cells.length < 42) {
      cells.push({
        day: cells.length - (firstDay + daysInMonth) + 1,
        inMonth: false,
        isToday: false
      });
    }
    return cells;
  }

  spacing: Math.round(14 * uiScale)

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // Header: Full Date & Today Reset Pill
  RowLayout {
    Layout.fillWidth: true
    spacing: Math.round(8 * root.uiScale)

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Math.round(2 * root.uiScale)

      Text {
        text: Qt.formatDateTime(root.nowDate, "dddd")
        font.family: Config.textFont
        font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
        font.weight: Font.Medium
        color: Color.primary
      }

      Text {
        text: Qt.formatDateTime(root.nowDate, "MMMM d, yyyy")
        font.family: Config.textFont
        font.pixelSize: Math.max(16, Math.round(19 * root.uiScale))
        font.weight: Font.Bold
        color: Color.text
      }
    }

    Rectangle {
      visible: root.monthOffset !== 0
      implicitWidth: todayLabel.implicitWidth + Math.round(20 * root.uiScale)
      Layout.preferredHeight: Math.round(32 * root.uiScale)
      radius: height / 2
      color: todayMouse.containsMouse ? Color.primary : Color.surface

      Text {
        id: todayLabel
        anchors.centerIn: parent
        text: "Today"
        font.family: Config.textFont
        font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
        font.weight: Font.DemiBold
        color: todayMouse.containsMouse ? Color.background : Color.text
      }

      MouseArea {
        id: todayMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.monthOffset = 0
      }
    }
  }

  // Month Switcher Card
  Rectangle {
    Layout.fillWidth: true
    implicitHeight: monthCol.implicitHeight + Math.round(24 * root.uiScale)
    radius: Math.round(22 * root.uiScale)
    color: Color.surface

    ColumnLayout {
      id: monthCol
      anchors.fill: parent
      anchors.margins: Math.round(12 * root.uiScale)
      spacing: Math.round(10 * root.uiScale)

      RowLayout {
        Layout.fillWidth: true

        Rectangle {
          Layout.preferredWidth: Math.round(32 * root.uiScale)
          Layout.preferredHeight: Math.round(32 * root.uiScale)
          radius: width / 2
          color: prevMouse.containsMouse ? Color.overlay : "transparent"

          Text {
            anchors.centerIn: parent
            text: "chevron_left"
            font.family: Config.iconFont
            font.pixelSize: Math.round(20 * root.uiScale)
            color: Color.text
          }

          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.monthOffset--
          }
        }

        Text {
          text: Qt.formatDateTime(root.displayMonth, "MMMM yyyy")
          font.family: Config.textFont
          font.pixelSize: Math.max(13, Math.round(15 * root.uiScale))
          font.weight: Font.DemiBold
          color: Color.text
          horizontalAlignment: Text.AlignHCenter
          Layout.fillWidth: true
        }

        Rectangle {
          Layout.preferredWidth: Math.round(32 * root.uiScale)
          Layout.preferredHeight: Math.round(32 * root.uiScale)
          radius: width / 2
          color: nextMouse.containsMouse ? Color.overlay : "transparent"

          Text {
            anchors.centerIn: parent
            text: "chevron_right"
            font.family: Config.iconFont
            font.pixelSize: Math.round(20 * root.uiScale)
            color: Color.text
          }

          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.monthOffset++
          }
        }
      }

      // Weekday Headers
      GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 0

        Repeater {
          model: ["S", "M", "T", "W", "T", "F", "S"]

          Text {
            required property string modelData
            text: modelData
            font.family: Config.textFont
            font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
            font.weight: Font.Bold
            color: Color.muted
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(24 * root.uiScale)
          }
        }
      }

      // Day Cells
      GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 0
        rowSpacing: Math.round(4 * root.uiScale)

        Repeater {
          model: root.calendarCells

          Item {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(34 * root.uiScale)

            Rectangle {
              anchors.centerIn: parent
              width: Math.round(32 * root.uiScale)
              height: Math.round(32 * root.uiScale)
              radius: width / 2
              color: modelData.isToday ? Color.primary : "transparent"

              Text {
                anchors.centerIn: parent
                text: modelData.day
                font.family: Config.textFont
                font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
                font.weight: modelData.isToday ? Font.Bold : Font.Normal
                color: {
                  if (modelData.isToday)
                    return Color.background;
                  return modelData.inMonth ? Color.text : Color.muted;
                }
                opacity: modelData.inMonth || modelData.isToday ? 1.0 : 0.45
              }
            }
          }
        }
      }
    }
  }
}
