import QtQuick
import QtQuick.Layouts
import qs.configs
import qs.services

ColumnLayout {
  id: root

  property real uiScale: 1.0
  property bool clearingAll: false
  property var dismissingIds: ({})
  readonly property int activeDismissingCount: Object.keys(dismissingIds).length
  readonly property bool isEmpty: NotificationService.unreadCount === 0

  spacing: Math.round(14 * uiScale)

  Connections {
    target: NotificationService
    function onUnreadCountChanged(): void {
      if (NotificationService.unreadCount === 0) {
        root.dismissingIds = ({});
        root.clearingAll = false;
      }
    }
  }

  Timer {
    id: clearAllTimer
    interval: 150
    onTriggered: {
      NotificationService.dismissAll();
      root.dismissingIds = ({});
      root.clearingAll = false;
    }
  }

  // Header Bar
  RowLayout {
    Layout.fillWidth: true
    spacing: Math.round(10 * root.uiScale)

    Text {
      text: "Notifications"
      font.family: Config.textFont
      font.pixelSize: Math.max(17, Math.round(20 * root.uiScale))
      font.weight: Font.Bold
      color: Color.text
      Layout.fillWidth: true
      Layout.leftMargin: Math.round(4 * root.uiScale)
    }

    // DND Circular Toggle Button
    Rectangle {
      Layout.preferredWidth: Math.round(38 * root.uiScale)
      Layout.preferredHeight: Math.round(38 * root.uiScale)
      radius: width / 2
      color: NotificationService.doNotDisturb ? Color.primary : (dndMouse.containsMouse ? Color.overlay : Color.surface)
      scale: dndMouse.pressed ? 0.92 : 1.0

      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: 140
          easing.type: Easing.OutQuad
        }
      }

      Text {
        anchors.centerIn: parent
        text: NotificationService.doNotDisturb ? "notifications_off" : "notifications_active"
        font.family: Config.iconFont
        font.pixelSize: Math.round(20 * root.uiScale)
        color: NotificationService.doNotDisturb ? Color.background : Color.text
      }

      MouseArea {
        id: dndMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationService.toggleDoNotDisturb()
      }
    }

    // Expressive Clear All Pill
    Rectangle {
      visible: !root.isEmpty && !root.clearingAll
      implicitWidth: clearRow.implicitWidth + Math.round(24 * root.uiScale)
      Layout.preferredHeight: Math.round(38 * root.uiScale)
      radius: height / 2
      color: clearMouse.containsMouse ? Color.primary : Color.surface
      scale: clearMouse.pressed ? 0.94 : 1.0

      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: 140
          easing.type: Easing.OutQuad
        }
      }

      RowLayout {
        id: clearRow
        anchors.centerIn: parent
        spacing: Math.round(6 * root.uiScale)

        Text {
          text: "clear_all"
          font.family: Config.iconFont
          font.pixelSize: Math.round(18 * root.uiScale)
          color: clearMouse.containsMouse ? Color.background : Color.primary
        }

        Text {
          text: "Clear all"
          font.family: Config.textFont
          font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
          font.weight: Font.DemiBold
          color: clearMouse.containsMouse ? Color.background : Color.text
        }
      }

      MouseArea {
        id: clearMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (!root.clearingAll) {
            root.clearingAll = true;
            clearAllTimer.restart();
          }
        }
      }
    }
  }

  // Empty State
  Item {
    visible: root.isEmpty
    Layout.fillWidth: true
    Layout.preferredHeight: Math.round(180 * root.uiScale)
    opacity: root.isEmpty ? 1.0 : 0.0

    Behavior on opacity {
      NumberAnimation {
        duration: 160
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Math.round(10 * root.uiScale)

      Rectangle {
        Layout.alignment: Qt.AlignHCenter
        width: Math.round(54 * root.uiScale)
        height: Math.round(54 * root.uiScale)
        radius: width / 2
        color: Color.surface

        Text {
          anchors.centerIn: parent
          text: NotificationService.doNotDisturb ? "notifications_off" : "notifications_none"
          font.family: Config.iconFont
          font.pixelSize: Math.round(28 * root.uiScale)
          color: Color.muted
        }
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: NotificationService.doNotDisturb ? "Do Not Disturb is on" : "All caught up"
        font.family: Config.textFont
        font.pixelSize: Math.max(14, Math.round(16 * root.uiScale))
        font.weight: Font.DemiBold
        color: Color.text
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "No new notifications"
        font.family: Config.textFont
        font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
        color: Color.muted
      }
    }
  }

  // Grouped Notification Feed
  Flickable {
    id: groupFlickable
    visible: !root.isEmpty
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(Math.round(560 * root.uiScale), Math.max(1, groupsColumn.implicitHeight))
    clip: true
    contentWidth: width
    contentHeight: groupsColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    opacity: root.clearingAll ? 0.0 : 1.0
    Behavior on opacity {
      NumberAnimation {
        duration: 140
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      id: groupsColumn
      width: groupFlickable.width
      spacing: Math.round(10 * root.uiScale)

      Repeater {
        model: NotificationService.notificationGroups

        Rectangle {
          id: groupCard
          required property var modelData
          readonly property bool collapsed: NotificationService.isAppCollapsed(modelData.appName)
          readonly property int remainingInGroup: {
            let count = 0;
            const list = modelData.notifications;
            for (let i = 0; i < list.length; i++) {
              if (list[i] && !root.dismissingIds[list[i].id]) {
                count++;
              }
            }
            return count;
          }
          readonly property bool groupDismissing: modelData.notifications.length > 0 && remainingInGroup === 0

          Layout.fillWidth: true
          implicitHeight: groupDismissing ? 0 : groupContent.implicitHeight
          opacity: groupDismissing ? 0.0 : 1.0
          radius: Math.round(22 * root.uiScale)
          color: Color.surface
          clip: true

          Behavior on implicitHeight {
            NumberAnimation {
              duration: 180
              easing.type: Easing.OutCubic
            }
          }

          Behavior on opacity {
            NumberAnimation {
              duration: 130
              easing.type: Easing.OutCubic
            }
          }

          ColumnLayout {
            id: groupContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // App Group Header
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: Math.round(52 * root.uiScale)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * root.uiScale)
                anchors.rightMargin: Math.round(14 * root.uiScale)
                spacing: Math.round(12 * root.uiScale)

                Rectangle {
                  Layout.preferredWidth: Math.round(34 * root.uiScale)
                  Layout.preferredHeight: Math.round(34 * root.uiScale)
                  radius: Math.round(11 * root.uiScale)
                  color: Color.overlay

                  Image {
                    id: groupIconImg
                    anchors.centerIn: parent
                    width: Math.round(22 * root.uiScale)
                    height: Math.round(22 * root.uiScale)
                    source: groupCard.modelData.appIcon ? ("image://icon/" + groupCard.modelData.appIcon) : ""
                    sourceSize: Qt.size(28, 28)
                    smooth: true
                    visible: status === Image.Ready
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: groupIconImg.status !== Image.Ready
                    text: "notifications"
                    font.family: Config.iconFont
                    font.pixelSize: Math.round(18 * root.uiScale)
                    color: Color.primary
                  }
                }

                Text {
                  text: groupCard.modelData.appName
                  font.family: Config.textFont
                  font.pixelSize: Math.max(14, Math.round(15 * root.uiScale))
                  font.weight: Font.DemiBold
                  color: Color.text
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Rectangle {
                  Layout.preferredHeight: Math.round(24 * root.uiScale)
                  Layout.preferredWidth: groupCountText.implicitWidth + Math.round(14 * root.uiScale)
                  radius: height / 2
                  color: Color.overlay

                  Text {
                    id: groupCountText
                    anchors.centerIn: parent
                    text: groupCard.remainingInGroup
                    font.family: Config.textFont
                    font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
                    font.weight: Font.Bold
                    color: Color.secondary
                  }
                }

                Text {
                  text: groupCard.collapsed ? "expand_more" : "expand_less"
                  font.family: Config.iconFont
                  font.pixelSize: Math.round(20 * root.uiScale)
                  color: Color.muted
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.toggleApp(groupCard.modelData.appName)
              }
            }

            // Individual Notifications in Group
            ColumnLayout {
              visible: !groupCard.collapsed
              Layout.fillWidth: true
              spacing: 0

              Repeater {
                model: groupCard.modelData.notifications

                Item {
                  id: notificationRow
                  required property var modelData
                  required property int index
                  readonly property int notifId: modelData ? modelData.id : -1
                  readonly property bool dismissing: Boolean(root.dismissingIds[notifId])

                  Layout.fillWidth: true
                  implicitHeight: dismissing ? 0 : (notificationContent.implicitHeight + Math.round(20 * root.uiScale))
                  opacity: dismissing ? 0.0 : 1.0
                  clip: true

                  Behavior on implicitHeight {
                    NumberAnimation {
                      duration: 150
                      easing.type: Easing.OutCubic
                    }
                  }

                  Behavior on opacity {
                    NumberAnimation {
                      duration: 120
                      easing.type: Easing.OutCubic
                    }
                  }

                  Timer {
                    id: rowDismissTimer
                    property var targetNotif: null
                    interval: 150
                    onTriggered: {
                      const target = targetNotif;
                      targetNotif = null;
                      if (target) {
                        const next = Object.assign({}, root.dismissingIds);
                        delete next[target.id];
                        root.dismissingIds = next;
                        NotificationService.dismissNotification(target);
                      }
                    }
                  }

                  Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Math.round(14 * root.uiScale)
                    anchors.rightMargin: Math.round(14 * root.uiScale)
                    height: 1
                    color: Color.overlay
                    opacity: notificationRow.index === 0 ? 0.85 : 0.55
                  }

                  ColumnLayout {
                    id: notificationContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Math.round(16 * root.uiScale)
                    anchors.rightMargin: Math.round(14 * root.uiScale)
                    anchors.topMargin: Math.round(11 * root.uiScale)
                    spacing: Math.round(5 * root.uiScale)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Math.round(8 * root.uiScale)

                      Text {
                        visible: notificationRow.modelData.summary.length > 0
                        text: notificationRow.modelData.summary
                        textFormat: Text.PlainText
                        font.family: Config.textFont
                        font.pixelSize: Math.max(14, Math.round(15 * root.uiScale))
                        font.weight: Font.Medium
                        color: Color.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        text: NotificationService.relativeTime(notificationRow.modelData)
                        font.family: Config.textFont
                        font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
                        color: Color.muted
                      }

                      Rectangle {
                        Layout.preferredWidth: Math.round(26 * root.uiScale)
                        Layout.preferredHeight: Math.round(26 * root.uiScale)
                        radius: width / 2
                        color: closeMouse.containsMouse ? Color.overlay : "transparent"

                        Text {
                          anchors.centerIn: parent
                          text: "close"
                          font.family: Config.iconFont
                          font.pixelSize: Math.round(16 * root.uiScale)
                          color: closeMouse.containsMouse ? Color.text : Color.muted
                        }

                        MouseArea {
                          id: closeMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (notificationRow.dismissing || root.clearingAll || notificationRow.notifId < 0)
                              return;
                            if (NotificationService.unreadCount - root.activeDismissingCount <= 1) {
                              root.clearingAll = true;
                              clearAllTimer.restart();
                            } else {
                              const next = Object.assign({}, root.dismissingIds);
                              next[notificationRow.notifId] = true;
                              root.dismissingIds = next;
                              rowDismissTimer.targetNotif = notificationRow.modelData;
                              rowDismissTimer.restart();
                            }
                          }
                        }
                      }
                    }

                    Text {
                      visible: notificationRow.modelData.body.length > 0
                      text: notificationRow.modelData.body
                      textFormat: Text.PlainText
                      font.family: Config.textFont
                      font.pixelSize: Math.max(12, Math.round(13 * root.uiScale))
                      color: Color.muted
                      wrapMode: Text.WordWrap
                      maximumLineCount: 3
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    RowLayout {
                      visible: notificationRow.modelData.actions.length > 0
                      Layout.topMargin: Math.round(5 * root.uiScale)
                      spacing: Math.round(8 * root.uiScale)

                      Repeater {
                        model: notificationRow.modelData.actions

                        Rectangle {
                          required property var modelData
                          implicitWidth: actionLabel.implicitWidth + Math.round(20 * root.uiScale)
                          implicitHeight: Math.round(28 * root.uiScale)
                          radius: height / 2
                          color: actionMouse.containsMouse ? Color.primary : Color.overlay

                          Behavior on color {
                            ColorAnimation {
                              duration: 140
                            }
                          }

                          Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            font.family: Config.textFont
                            font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
                            font.weight: Font.Medium
                            color: actionMouse.containsMouse ? Color.background : Color.primary
                          }

                          MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.invokeAction(notificationRow.modelData, modelData, false)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
