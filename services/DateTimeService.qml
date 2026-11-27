pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  readonly property date now: clock.date
  readonly property string dayName: Qt.formatDateTime(clock.date, "dddd")
  readonly property string shortDate: Qt.formatDateTime(clock.date, "MMM d")
  readonly property string time12h: Qt.formatDateTime(clock.date, "hh:mm AP")
  readonly property string time24h: Qt.formatDateTime(clock.date, "HH:mm")
  readonly property string fullDate: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy")
}
