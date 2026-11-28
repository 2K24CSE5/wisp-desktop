pragma Singleton
import QtQuick
import Quickshell
import qs.services

Singleton {
  id: root

  property string activePopup: ""
  property var activeScreen: null
  readonly property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

  function isPopupOpen(name: string, scr): bool {
    return root.activePopup === name && root.activeScreen === scr;
  }

  function togglePopup(name: string, scr): void {
    if (root.activePopup === name && root.activeScreen === scr) {
      root.closePopup();
      return;
    }

    root.activeScreen = scr;
    root.activePopup = name;

    if (name === "notifications") {
      NotificationService.openCenter();
    } else if (NotificationService.centerOpen) {
      NotificationService.closeCenter();
    }
  }

  function closePopup(): void {
    root.activePopup = "";
    if (NotificationService.centerOpen) {
      NotificationService.closeCenter();
    }
  }

  function scaleForScreen(scr): real {
    const w = scr ? scr.width : 1440;
    const h = scr ? scr.height : 900;
    const raw = (w > 0 && h > 0) ? Math.sqrt((w / 1440) * (h / 900)) : 1.0;
    return Math.max(0.85, Math.min(1.4, raw));
  }

  function popupWidthFor(popupName: string, hasInteractive: bool, scale: real): int {
    const base = !hasInteractive ? 420 : (popupName === "calendar" || popupName === "quick") ? 340 : popupName === "battery" ? 350 : 420;
    return Math.round(base * scale);
  }

  Connections {
    target: NotificationService
    function onCenterOpenChanged(): void {
      if (NotificationService.centerOpen && root.activePopup !== "notifications") {
        root.activeScreen = root.primaryScreen;
        root.activePopup = "notifications";
      } else if (!NotificationService.centerOpen && root.activePopup === "notifications") {
        root.activePopup = "";
      }
    }
  }
}
