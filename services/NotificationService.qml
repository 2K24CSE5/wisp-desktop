pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
  id: root

  property bool centerOpen: false
  property bool doNotDisturb: false
  property var activePopups: []
  property var collapsedApps: ({})
  property var notificationTimes: []
  property int timeRevision: 0

  readonly property alias notifications: server.trackedNotifications
  readonly property int unreadCount: server.trackedNotifications.values.length
  readonly property bool hasPopups: !centerOpen && activePopups.length > 0
  readonly property bool shouldShowWindow: centerOpen || activePopups.length > 0

  readonly property var notificationGroups: {
    const groups = [];
    const list = server.trackedNotifications.values;
    for (let i = 0; i < list.length; i++) {
      const notif = list[i];
      const appName = notif.appName || "System";
      let group = groups.find(entry => entry.appName === appName);
      if (!group) {
        group = {
          appName: appName,
          appIcon: notif.appIcon || "",
          notifications: []
        };
        groups.push(group);
      } else if (!group.appIcon && notif.appIcon) {
        group.appIcon = notif.appIcon;
      }
      group.notifications.push(notif);
    }
    return groups;
  }

  function isCritical(notif): bool {
    return Boolean(notif && notif.urgency === 2);
  }

  function popupTimeoutMs(notif): int {
    const seconds = (notif && notif.expireTimeout > 0) ? notif.expireTimeout : 5;
    return seconds * 1000;
  }

  function toggleDoNotDisturb(): void {
    root.doNotDisturb = !root.doNotDisturb;
  }

  function toggleApp(appName: string): void {
    const updated = Object.assign({}, root.collapsedApps);
    updated[appName] = !updated[appName];
    root.collapsedApps = updated;
  }

  function isAppCollapsed(appName: string): bool {
    return Boolean(root.collapsedApps[appName]);
  }

  function relativeTime(notif): string {
    root.timeRevision;
    const entry = root.notificationTimes.find(item => item.notification === notif);
    const minutes = entry ? Math.floor((Date.now() - entry.receivedAt) / 60000) : 0;
    if (minutes < 1)
      return "now";
    if (minutes < 60)
      return minutes + "m";
    const hours = Math.floor(minutes / 60);
    if (hours < 24)
      return hours + "h";
    return Math.floor(hours / 24) + "d";
  }

  function openCenter(): void {
    root.centerOpen = true;
    root.activePopups = [];
  }

  function closeCenter(): void {
    root.centerOpen = false;
  }

  function toggleCenter(): void {
    if (root.centerOpen) {
      root.closeCenter();
    } else {
      root.openCenter();
    }
  }

  function dismissNotification(notif): void {
    if (notif)
      notif.dismiss();
  }

  function dismissPopup(notif): void {
    root.activePopups = root.activePopups.filter(n => n !== notif);
  }

  function invokeAction(notif, actionItem, dismissToastAfter: bool): void {
    if (actionItem && typeof actionItem.invoke === "function")
      actionItem.invoke();
    if (dismissToastAfter && notif)
      root.dismissPopup(notif);
  }

  function dismissAll(): void {
    const list = [...server.trackedNotifications.values];
    for (let i = 0; i < list.length; i++) {
      list[i].dismiss();
    }
    root.activePopups = [];
  }

  NotificationServer {
    id: server
    bodySupported: true
    bodyMarkupSupported: false
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true
    keepOnReload: true

    onNotification: notif => {
      notif.tracked = true;
      root.notificationTimes = [...root.notificationTimes.filter(item => item.notification !== notif),
        {
          notification: notif,
          receivedAt: Date.now()
        }
      ];

      if (!root.doNotDisturb && !root.centerOpen && !notif.transient) {
        root.activePopups = [notif, ...root.activePopups];
      }

      notif.closed.connect(() => {
        root.dismissPopup(notif);
        root.notificationTimes = root.notificationTimes.filter(item => item.notification !== notif);
      });
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.timeRevision++
  }
}
