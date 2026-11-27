import QtQuick
import QtQuick.Layouts
import qs.configs
import qs.services

ColumnLayout {
  id: root

  property real uiScale: 1.0
  property var popups: []
  property bool active: true
  property int activeCount: groupModel.count

  // Monotonic per-notification expiry timestamps (ms) so incoming toasts never reset existing countdowns
  property var expiryMap: ({})
  property int nextKey: 1

  // Array of { appName, appIcon, notifications: [notif...], isClosing: bool }
  property var groupedEntries: []

  function keyFor(notif) {
    if (!notif)
      return "";
    if (!notif._wispToastKey) {
      notif._wispToastKey = "t_" + (root.nextKey++);
    }
    return notif._wispToastKey;
  }

  function syncPopups() {
    const incoming = (active && popups) ? popups : [];
    const incomingKeys = new Set();
    const now = Date.now();

    // Group incoming active popups by appName while preserving order
    const byApp = new Map();
    const appOrder = [];

    for (let i = 0; i < incoming.length; i++) {
      const n = incoming[i];
      const k = keyFor(n);
      incomingKeys.add(k);

      if (root.expiryMap[k] === undefined) {
        root.expiryMap[k] = now + NotificationService.popupTimeoutMs(n);
      }

      const appName = (n.appName && n.appName.length > 0) ? n.appName : "System";
      if (!byApp.has(appName)) {
        byApp.set(appName, {
          appName: appName,
          appIcon: n.appIcon || "",
          notifications: []
        });
        appOrder.push(appName);
      }
      const grp = byApp.get(appName);
      if (!grp.appIcon && n.appIcon) {
        grp.appIcon = n.appIcon;
      }
      grp.notifications.push(n);
    }

    // Prune expired keys no longer present
    const existingKeys = Object.keys(root.expiryMap);
    for (let i = 0; i < existingKeys.length; i++) {
      if (!incomingKeys.has(existingKeys[i])) {
        delete root.expiryMap[existingKeys[i]];
      }
    }

    // Reconcile groupModel in place so active cards don't flicker
    const seenApps = new Set();
    for (let i = groupModel.count - 1; i >= 0; i--) {
      const item = groupModel.get(i);
      if (byApp.has(item.appName)) {
        seenApps.add(item.appName);
        if (item.isClosing) {
          groupModel.setProperty(i, "isClosing", false);
        }
      } else if (!item.isClosing) {
        groupModel.setProperty(i, "isClosing", true);
      }
    }

    for (let i = 0; i < appOrder.length; i++) {
      const name = appOrder[i];
      if (!seenApps.has(name)) {
        groupModel.append({
          appName: name,
          isClosing: false
        });
      }
    }

    // Update plain JS lookup map for each group's notifications
    const nextLookup = {};
    for (let i = 0; i < appOrder.length; i++) {
      const name = appOrder[i];
      nextLookup[name] = byApp.get(name);
    }
    root.groupLookup = nextLookup;
  }

  property var groupLookup: ({})

  function notificationsFor(appName) {
    const entry = root.groupLookup[appName];
    return entry ? entry.notifications : [];
  }

  function iconFor(appName) {
    const entry = root.groupLookup[appName];
    return entry ? entry.appIcon : "";
  }

  function dismissGroup(appName) {
    const list = notificationsFor(appName).slice();
    for (let i = 0; i < list.length; i++) {
      NotificationService.dismissPopup(list[i]);
    }
  }

  function removeGroupByName(appName) {
    for (let i = groupModel.count - 1; i >= 0; i--) {
      if (groupModel.get(i).appName === appName) {
        groupModel.remove(i, 1);
        break;
      }
    }
  }

  function clearAll() {
    groupModel.clear();
    groupLookup = ({});
    expiryMap = ({});
  }

  onPopupsChanged: syncPopups()
  onActiveChanged: syncPopups()
  Component.onCompleted: syncPopups()

  // Monotonic sweep timer: auto-dismisses each notification at its own exact expiry timestamp
  Timer {
    id: expirySweepTimer
    interval: 150
    repeat: true
    running: root.active && root.popups && root.popups.length > 0
    onTriggered: {
      const now = Date.now();
      const current = root.popups ? root.popups.slice() : [];
      for (let i = 0; i < current.length; i++) {
        const n = current[i];
        if (!n || NotificationService.isCritical(n))
          continue;
        const k = root.keyFor(n);
        const exp = root.expiryMap[k];
        if (exp !== undefined && now >= exp) {
          delete root.expiryMap[k];
          NotificationService.dismissPopup(n);
        }
      }
    }
  }

  ListModel {
    id: groupModel
  }

  spacing: Math.round(10 * uiScale)

  Repeater {
    model: groupModel

    Item {
      id: groupSlot
      required property string appName
      required property bool isClosing

      readonly property var items: root.notificationsFor(appName)
      readonly property string appIcon: root.iconFor(appName)
      readonly property bool hasCritical: {
        for (let i = 0; i < items.length; i++) {
          if (NotificationService.isCritical(items[i]))
            return true;
        }
        return false;
      }
      readonly property real fullHeight: groupCard.implicitHeight

      Layout.fillWidth: true
      Layout.preferredHeight: isClosing ? 0 : fullHeight
      clip: true

      Behavior on Layout.preferredHeight {
        NumberAnimation {
          duration: 220
          easing.type: Easing.OutCubic
        }
      }

      Timer {
        running: groupSlot.isClosing
        interval: 230
        onTriggered: root.removeGroupByName(groupSlot.appName)
      }

      Rectangle {
        id: groupCard
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: groupContent.implicitHeight
        radius: Math.round(22 * root.uiScale)
        color: Color.surface
        clip: true
        opacity: groupSlot.isClosing ? 0.0 : 1.0
        scale: groupSlot.isClosing ? 0.96 : 1.0
        transformOrigin: Item.TopRight

        Behavior on opacity {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }

        Behavior on scale {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        // Left Urgency Accent Pill when any notification in the group is critical
        Rectangle {
          visible: groupSlot.hasCritical
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
                color: groupSlot.hasCritical ? Color.error : Color.overlay

                Image {
                  id: groupIconImg
                  anchors.centerIn: parent
                  width: Math.round(20 * root.uiScale)
                  height: Math.round(20 * root.uiScale)
                  source: groupSlot.appIcon ? ("image://icon/" + groupSlot.appIcon) : ""
                  sourceSize: Qt.size(24, 24)
                  smooth: true
                  visible: status === Image.Ready && !groupSlot.hasCritical
                }

                Text {
                  anchors.centerIn: parent
                  visible: groupIconImg.status !== Image.Ready || groupSlot.hasCritical
                  text: groupSlot.hasCritical ? "priority_high" : "notifications"
                  font.family: Config.iconFont
                  font.pixelSize: Math.round(17 * root.uiScale)
                  color: groupSlot.hasCritical ? Color.background : Color.primary
                }
              }

              Text {
                text: groupSlot.appName
                font.family: Config.textFont
                font.pixelSize: Math.max(13, Math.round(14 * root.uiScale))
                font.weight: Font.DemiBold
                color: groupSlot.hasCritical ? Color.error : Color.secondary
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              // Count badge when multiple toasts are grouped for this app
              Rectangle {
                visible: groupSlot.items.length > 1
                Layout.preferredHeight: Math.round(22 * root.uiScale)
                Layout.preferredWidth: groupCountText.implicitWidth + Math.round(12 * root.uiScale)
                radius: height / 2
                color: Color.overlay

                Text {
                  id: groupCountText
                  anchors.centerIn: parent
                  text: groupSlot.items.length
                  font.family: Config.textFont
                  font.pixelSize: Math.max(11, Math.round(12 * root.uiScale))
                  font.weight: Font.Bold
                  color: Color.secondary
                }
              }

              // Dismiss entire app toast group
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
                  onClicked: root.dismissGroup(groupSlot.appName)
                }
              }
            }
          }

          // Grouped Notification Rows
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
              model: groupSlot.items

              Item {
                id: toastRow
                required property var modelData
                required property int index
                readonly property bool rowCritical: NotificationService.isCritical(modelData)

                Layout.fillWidth: true
                implicitHeight: rowContent.implicitHeight + Math.round(20 * root.uiScale)

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

                    // Individual dismiss button shown when multiple notifications are in the group
                    Rectangle {
                      visible: groupSlot.items.length > 1
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
                        onClicked: NotificationService.dismissPopup(toastRow.modelData)
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
}
