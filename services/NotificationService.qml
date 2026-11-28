pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
  id: root

  property bool centerOpen: false
  property bool doNotDisturb: false
  property var activePopups: []
  property var activePopupIds: []
  property var collapsedApps: ({})
  property var notificationTimes: []
  property int timeRevision: 0

  // Tracks IDs currently being dismissed so they never reappear while waiting for async D-Bus close
  property var dismissedIds: ({})

  // Window presentation state managed centrally in service
  property bool windowShown: false
  property bool windowClosing: false
  property bool centerSession: false

  // Toast per-notification expiry state using primitive fields only: { id, critical, expiresAt }
  property var popupExpiries: []

  // Explicitly rebuilt whenever notifications arrive, close, or dismiss
  property var notificationGroups: []
  property int trackedCount: 0

  readonly property alias notifications: server.trackedNotifications
  readonly property int unreadCount: trackedCount
  readonly property bool hasPopups: !centerOpen && activePopupIds.length > 0
  readonly property bool shouldShowWindow: centerOpen || activePopupIds.length > 0
  readonly property bool windowVisible: shouldShowWindow || windowClosing
  readonly property bool fullScreenMode: centerOpen || (windowClosing && centerSession)

  // Declarative toast grouping so Widget.qml sees populated groups on the exact same tick as hasPopups
  readonly property var toastGroups: {
    if (!root.hasPopups)
      return [];
    const byApp = new Map();
    const appOrder = [];
    const seenIds = new Set();
    for (let i = 0; i < root.activePopups.length; i++) {
      const n = root.activePopups[i];
      let notifId = -1;
      let appName = "System";
      let appIcon = "";
      try {
        if (!n)
          continue;
        notifId = n.id;
        appName = (n.appName && n.appName.length > 0) ? n.appName : "System";
        appIcon = n.appIcon || "";
      } catch (e) {
        continue;
      }

      if (seenIds.has(notifId) || root.dismissedIds[notifId] || root.activePopupIds.indexOf(notifId) === -1)
        continue;
      seenIds.add(notifId);

      if (!byApp.has(appName)) {
        byApp.set(appName, {
          appName: appName,
          appIcon: appIcon,
          notifications: []
        });
        appOrder.push(appName);
      }
      const grp = byApp.get(appName);
      if (!grp.appIcon && appIcon) {
        grp.appIcon = appIcon;
      }
      grp.notifications.push(n);
    }
    const groups = [];
    for (let i = 0; i < appOrder.length; i++) {
      groups.push(byApp.get(appOrder[i]));
    }
    return groups;
  }

  function rebuildNotificationGroups(pendingNotif = null): void {
    const groups = [];
    const seenIds = new Set();
    const list = [...server.trackedNotifications.values];

    if (pendingNotif && pendingNotif.tracked) {
      list.unshift(pendingNotif);
    }

    for (let i = 0; i < list.length; i++) {
      const notif = list[i];
      let notifId = -1;
      let appName = "System";
      let appIcon = "";
      try {
        if (!notif)
          continue;
        notifId = notif.id;
        appName = (notif.appName && notif.appName.length > 0) ? notif.appName : "System";
        appIcon = notif.appIcon || "";
      } catch (e) {
        continue;
      }

      if (seenIds.has(notifId) || root.dismissedIds[notifId])
        continue;
      seenIds.add(notifId);

      let group = groups.find(entry => entry.appName === appName);
      if (!group) {
        group = {
          appName: appName,
          appIcon: appIcon,
          notifications: []
        };
        groups.push(group);
      } else if (!group.appIcon && appIcon) {
        group.appIcon = appIcon;
      }
      group.notifications.push(notif);
    }

    root.trackedCount = seenIds.size;
    root.notificationGroups = groups;
  }

  function syncToastExpiry(): void {
    const incoming = root.hasPopups ? root.activePopups : [];
    const now = Date.now();
    const updated = [];

    for (let i = 0; i < incoming.length; i++) {
      const n = incoming[i];
      let notifId = -1;
      try {
        if (!n)
          continue;
        notifId = n.id;
      } catch (e) {
        continue;
      }

      if (root.dismissedIds[notifId] || root.activePopupIds.indexOf(notifId) === -1)
        continue;

      const existing = root.popupExpiries.find(item => item.id === notifId);
      if (existing) {
        updated.push({
          id: notifId,
          critical: existing.critical,
          expiresAt: existing.expiresAt
        });
      } else {
        updated.push({
          id: notifId,
          critical: root.isCritical(n),
          expiresAt: now + popupTimeoutMs(n)
        });
      }
    }

    root.popupExpiries = updated;
  }

  function updateWindowState(): void {
    if (root.shouldShowWindow) {
      closeTimer.stop();
      if (root.centerOpen) {
        root.centerSession = true;
      }
      root.windowClosing = false;
      root.windowShown = true;
    } else if (root.windowShown || !root.windowClosing) {
      root.windowClosing = true;
      root.windowShown = false;
      closeTimer.restart();
    }
  }

  onCenterOpenChanged: {
    syncToastExpiry();
    updateWindowState();
  }

  onActivePopupIdsChanged: {
    syncToastExpiry();
    updateWindowState();
  }

  onActivePopupsChanged: {
    syncToastExpiry();
    updateWindowState();
  }

  function isCritical(notif): bool {
    try {
      return Boolean(notif && notif.urgency === 2);
    } catch (e) {
      return false;
    }
  }

  function popupTimeoutMs(notif): int {
    try {
      if (!notif || notif.expireTimeout <= 0)
        return 5000;
      const ms = notif.expireTimeout > 120 ? notif.expireTimeout : notif.expireTimeout * 1000;
      return Math.max(1500, Math.min(30000, Math.round(ms)));
    } catch (e) {
      return 5000;
    }
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
    let notifId = -1;
    try {
      notifId = notif ? notif.id : -1;
    } catch (e) {
      return "now";
    }
    const entry = notifId >= 0 ? root.notificationTimes.find(item => item.id === notifId) : null;
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
    root.activePopupIds = [];
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
    if (!notif)
      return;
    let notifId = -1;
    try {
      notifId = notif.id;
    } catch (e) {
      return;
    }
    const nextDismissed = Object.assign({}, root.dismissedIds);
    nextDismissed[notifId] = true;
    root.dismissedIds = nextDismissed;

    root.dismissPopupById(notifId);
    root.notificationTimes = root.notificationTimes.filter(item => item.id !== notifId);
    root.rebuildNotificationGroups();
    try {
      notif.dismiss();
    } catch (e) {}
  }

  function dismissPopupById(notifId): void {
    root.activePopupIds = root.activePopupIds.filter(id => id !== notifId);
    root.activePopups = root.activePopups.filter(n => {
      try {
        return Boolean(n) && n.id !== notifId;
      } catch (e) {
        return false;
      }
    });
  }

  function dismissPopup(notif): void {
    if (!notif)
      return;
    try {
      root.dismissPopupById(notif.id);
    } catch (e) {}
  }

  function dismissPopupGroup(appName: string): void {
    const keepIds = [];
    const keepNotifs = [];
    for (let i = 0; i < root.activePopups.length; i++) {
      const n = root.activePopups[i];
      try {
        if (!n)
          continue;
        const name = (n.appName && n.appName.length > 0) ? n.appName : "System";
        if (name !== appName) {
          keepIds.push(n.id);
          keepNotifs.push(n);
        }
      } catch (e) {}
    }
    root.activePopupIds = keepIds;
    root.activePopups = keepNotifs;
  }

  function invokeAction(notif, actionItem, dismissToastAfter: bool): void {
    if (actionItem && typeof actionItem.invoke === "function")
      actionItem.invoke();
    if (dismissToastAfter && notif)
      root.dismissPopup(notif);
  }

  function dismissAll(): void {
    const list = [...server.trackedNotifications.values];
    const nextDismissed = Object.assign({}, root.dismissedIds);
    for (let i = 0; i < list.length; i++) {
      try {
        if (list[i]) {
          nextDismissed[list[i].id] = true;
        }
      } catch (e) {}
    }
    root.dismissedIds = nextDismissed;
    root.activePopupIds = [];
    root.activePopups = [];
    root.notificationTimes = [];
    root.trackedCount = 0;
    root.notificationGroups = [];

    for (let i = 0; i < list.length; i++) {
      try {
        if (list[i]) {
          list[i].dismiss();
        }
      } catch (e) {}
    }
  }

  Connections {
    target: server.trackedNotifications
    function onValuesChanged(): void {
      root.rebuildNotificationGroups();
    }
  }

  Timer {
    id: closeTimer
    interval: 170
    onTriggered: {
      root.windowClosing = false;
      root.centerSession = false;
      if (!root.hasPopups) {
        root.popupExpiries = [];
      }
    }
  }

  Timer {
    id: expirySweepTimer
    interval: 150
    repeat: true
    running: root.popupExpiries.length > 0
    onTriggered: {
      const now = Date.now();
      const expiredIds = [];
      for (let i = 0; i < root.popupExpiries.length; i++) {
        const item = root.popupExpiries[i];
        if (!item.critical && now >= item.expiresAt) {
          expiredIds.push(item.id);
        }
      }
      for (let i = 0; i < expiredIds.length; i++) {
        root.dismissPopupById(expiredIds[i]);
      }
    }
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
      const notifId = notif.id;
      if (root.dismissedIds[notifId]) {
        const cleaned = Object.assign({}, root.dismissedIds);
        delete cleaned[notifId];
        root.dismissedIds = cleaned;
      }

      notif.tracked = true;
      root.notificationTimes = [...root.notificationTimes.filter(item => item.id !== notifId),
        {
          id: notifId,
          receivedAt: Date.now()
        }
      ];

      if (!root.doNotDisturb && !root.centerOpen && !notif.transient) {
        root.activePopupIds = [notifId, ...root.activePopupIds.filter(id => id !== notifId)];
        root.activePopups = [notif, ...root.activePopups.filter(n => {
            try {
              return Boolean(n) && n.id !== notifId;
            } catch (e) {
              return false;
            }
          })];
      }

      notif.closed.connect(() => {
        if (root.dismissedIds[notifId]) {
          const cleaned = Object.assign({}, root.dismissedIds);
          delete cleaned[notifId];
          root.dismissedIds = cleaned;
        }
        root.dismissPopupById(notifId);
        root.notificationTimes = root.notificationTimes.filter(item => item.id !== notifId);
        root.rebuildNotificationGroups();
      });

      root.rebuildNotificationGroups(notif);
    }
  }

  Component.onCompleted: rebuildNotificationGroups()

  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.timeRevision++
  }

  IpcHandler {
    target: "notifications"

    function toggle(): void {
      root.toggleCenter();
    }

    function open(): void {
      root.openCenter();
    }

    function close(): void {
      root.closeCenter();
    }

    function toggleDnd(): void {
      root.toggleDoNotDisturb();
    }

    function clearAll(): void {
      root.dismissAll();
    }
  }
}
