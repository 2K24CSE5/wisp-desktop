import QtQuick
import QtQuick.Layouts
import qs.configs
import qs.services

ColumnLayout {
  id: root

  property real uiScale: 1.0

  spacing: Math.round(10 * uiScale)

  Repeater {
    model: NotificationService.toastGroups

    Rectangle {
      id: groupCard
      required property var modelData
      property bool dismissing: false
      property int dismissingRows: 0
      property string targetAppName: ""
      readonly property var items: modelData.notifications
      readonly property bool groupDismissing: dismissing || (items.length > 0 && dismissingRows >= items.length)
      readonly property bool hasCritical: {
        for (let i = 0; i < items.length; i++) {
          if (NotificationService.isCritical(items[i]))
            return true;
        }
        return false;
      }

      onModelDataChanged: {
        dismissing = false;
        dismissingRows = 0;
        targetAppName = "";
      }

      Layout.fillWidth: true
      implicitHeight: groupDismissing ? 0 : groupContent.implicitHeight
      opacity: groupDismissing ? 0.0 : 1.0
      radius: Math.round(22 * root.uiScale)
      color: Color.surface
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
        id: groupDismissTimer
        interval: 150
        onTriggered: {
          const app = groupCard.targetAppName;
          groupCard.targetAppName = "";
          groupCard.dismissing = false;
          if (app.length > 0) {
            NotificationService.dismissPopupGroup(app);
          }
        }
      }

      // Left Urgency Accent Pill when any notification in the group is critical
      Rectangle {
        visible: groupCard.hasCritical
        width: Math.round(4 * root.uiScale)
        height: Math.round(32 * root.uiScale)
        radius: width / 2
        color: Color.error
        anchors.left: parent.left
        anchors.leftMargin: Math.round(6 * root.uiScale)
        anchors.top: parent.top
        anchors.topMargin: Math.round(10 * root.uiScale)
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
          Layout.preferredHeight: Math.round(48 * root.uiScale)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * root.uiScale)
            anchors.rightMargin: Math.round(12 * root.uiScale)
            spacing: Math.round(10 * root.uiScale)

            Rectangle {
              Layout.preferredWidth: Math.round(32 * root.uiScale)
              Layout.preferredHeight: Math.round(32 * root.uiScale)
              radius: Math.round(10 * root.uiScale)
              color: groupCard.hasCritical ? Color.error : Color.overlay

              Image {
                id: groupIconImg
                anchors.centerIn: parent
                width: Math.round(20 * root.uiScale)
                height: Math.round(20 * root.uiScale)
                source: groupCard.modelData.appIcon ? ("image://icon/" + groupCard.modelData.appIcon) : ""
                sourceSize: Qt.size(24, 24)
                smooth: true
                visible: status === Image.Ready && !groupCard.hasCritical
              }

              Text {
                anchors.centerIn: parent
                visible: groupIconImg.status !== Image.Ready || groupCard.hasCritical
                text: groupCard.hasCritical ? "priority_high" : "notifications"
                font.family: Config.iconFont
                font.pixelSize: Math.round(17 * root.uiScale)
                color: groupCard.hasCritical ? Color.background : Color.primary
              }
            }

            Text {
              text: groupCard.modelData.appName
              font.family: Config.textFont
              font.pixelSize: Math.max(13, Math.round(14 * root.uiScale))
              font.weight: Font.DemiBold
              color: groupCard.hasCritical ? Color.error : Color.secondary
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Rectangle {
              visible: (groupCard.items.length - groupCard.dismissingRows) > 1
              Layout.preferredHeight: Math.round(22 * root.uiScale)
              Layout.preferredWidth: groupCountText.implicitWidth + Math.round(12 * root.uiScale)
              radius: height / 2
              color: Color.overlay

              Text {
                id: groupCountText
                anchors.centerIn: parent
                text: Math.max(0, groupCard.items.length - groupCard.dismissingRows)
                font.family: Config.textFont
                font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
                font.weight: Font.Bold
                color: Color.secondary
              }
            }

            Rectangle {
              Layout.preferredWidth: Math.round(28 * root.uiScale)
              Layout.preferredHeight: Math.round(28 * root.uiScale)
              radius: width / 2
              color: groupCloseMouse.containsMouse ? Color.overlay : "transparent"

              Text {
                anchors.centerIn: parent
                text: "close"
                font.family: Config.iconFont
                font.pixelSize: Math.round(17 * root.uiScale)
                color: groupCloseMouse.containsMouse ? Color.text : Color.muted
              }

              MouseArea {
                id: groupCloseMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!groupCard.dismissing) {
                    groupCard.targetAppName = groupCard.modelData.appName;
                    groupCard.dismissing = true;
                    groupDismissTimer.restart();
                  }
                }
              }
            }
          }
        }

        // Grouped Notification Rows
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Repeater {
            model: groupCard.items

            Item {
              id: toastRow
              required property var modelData
              required property int index
              property bool dismissing: false
              property var targetNotif: null
              readonly property bool rowCritical: NotificationService.isCritical(modelData)

              onModelDataChanged: {
                if (targetNotif && modelData !== targetNotif) {
                  dismissing = false;
                  targetNotif = null;
                }
              }

              Layout.fillWidth: true
              implicitHeight: dismissing ? 0 : (rowContent.implicitHeight + Math.round(20 * root.uiScale))
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
                id: toastRowDismissTimer
                interval: 150
                onTriggered: {
                  const target = toastRow.targetNotif;
                  toastRow.targetNotif = null;
                  toastRow.dismissing = false;
                  if (target) {
                    NotificationService.dismissPopup(target);
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
                opacity: toastRow.index === 0 ? 0.85 : 0.55
              }

              ColumnLayout {
                id: rowContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Math.round(16 * root.uiScale)
                anchors.rightMargin: Math.round(14 * root.uiScale)
                anchors.topMargin: Math.round(10 * root.uiScale)
                spacing: Math.round(5 * root.uiScale)

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Math.round(8 * root.uiScale)

                  Text {
                    visible: toastRow.modelData.summary.length > 0
                    text: toastRow.modelData.summary
                    textFormat: Text.PlainText
                    font.family: Config.textFont
                    font.pixelSize: Math.max(14, Math.round(15 * root.uiScale))
                    font.weight: Font.Medium
                    color: toastRow.rowCritical ? Color.error : Color.text
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Rectangle {
                    visible: groupCard.items.length > 1
                    Layout.preferredWidth: Math.round(24 * root.uiScale)
                    Layout.preferredHeight: Math.round(24 * root.uiScale)
                    radius: width / 2
                    color: itemCloseMouse.containsMouse ? Color.overlay : "transparent"

                    Text {
                      anchors.centerIn: parent
                      text: "close"
                      font.family: Config.iconFont
                      font.pixelSize: Math.round(15 * root.uiScale)
                      color: itemCloseMouse.containsMouse ? Color.text : Color.muted
                    }

                    MouseArea {
                      id: itemCloseMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (!toastRow.dismissing) {
                          toastRow.targetNotif = toastRow.modelData;
                          toastRow.dismissing = true;
                          groupCard.dismissingRows++;
                          toastRowDismissTimer.restart();
                        }
                      }
                    }
                  }
                }

                Text {
                  visible: toastRow.modelData.body.length > 0
                  text: toastRow.modelData.body
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
                  visible: toastRow.modelData.actions.length > 0
                  Layout.topMargin: Math.round(4 * root.uiScale)
                  spacing: Math.round(8 * root.uiScale)

                  Repeater {
                    model: toastRow.modelData.actions

                    Rectangle {
                      required property var modelData
                      implicitWidth: toastActionText.implicitWidth + Math.round(20 * root.uiScale)
                      implicitHeight: Math.round(28 * root.uiScale)
                      radius: height / 2
                      color: toastActionMouse.containsMouse ? Color.primary : Color.overlay

                      Behavior on color {
                        ColorAnimation {
                          duration: 140
                        }
                      }

                      Text {
                        id: toastActionText
                        anchors.centerIn: parent
                        text: modelData.text
                        font.family: Config.textFont
                        font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
                        font.weight: Font.Medium
                        color: toastActionMouse.containsMouse ? Color.background : Color.primary
                      }

                      MouseArea {
                        id: toastActionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.invokeAction(toastRow.modelData, modelData, true)
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
