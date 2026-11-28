import QtQuick
import qs.configs
import qs.services
import qs.components

WidgetPill {
  id: root

  inner: true
  horizontalPadding: Math.round(9 * uiScale)
  contentImplicitWidth: Math.round(18 * uiScale)

  Text {
    anchors.centerIn: parent
    text: NotificationService.doNotDisturb ? "notifications_off" : "notifications"
    font.family: Config.iconFont
    font.pixelSize: Math.round(17 * root.uiScale)
    color: NotificationService.doNotDisturb ? Color.muted : Color.text
  }

  Rectangle {
    visible: !root.active && NotificationService.unreadCount > 0 && !NotificationService.doNotDisturb
    width: Math.max(5, Math.round(6 * root.uiScale))
    height: width
    radius: width / 2
    color: Color.error
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: Math.round(6 * root.uiScale)
    anchors.rightMargin: Math.round(6 * root.uiScale)
  }
}
