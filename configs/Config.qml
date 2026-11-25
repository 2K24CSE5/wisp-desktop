pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.configs

Singleton {
  id: root

  readonly property var defaultSettings: ({
      wallpaper: "",
      iconFont: "Material Symbols Rounded",
      textFont: "Inter",
      isDark: true,
      targetUser: "",
      selectedSession: "Niri"
    })

  property var settings: Object.assign({}, defaultSettings)
  property bool ignoreNextFileChange: false

  readonly property string wallpaper: settings.wallpaper
  readonly property string iconFont: settings.iconFont
  readonly property string textFont: settings.textFont
  readonly property bool isDark: settings.isDark
  readonly property string targetUser: settings.targetUser
  readonly property string selectedSession: settings.selectedSession

  function saveSettings(newSettings): void {
    const merged = Object.assign({}, defaultSettings, newSettings);
    settings = merged;
    if (Paths.ready) {
      ignoreNextFileChange = true;
      settingsFile.setText(JSON.stringify(merged, null, 2));
    }
  }

  function setSelectedSession(sessionName: string): void {
    if (sessionName && sessionName !== selectedSession) {
      saveSettings(Object.assign({}, settings, {
        selectedSession: sessionName
      }));
    }
  }

  Timer {
    id: reloadDebounce
    interval: 50
    onTriggered: settingsFile.reload()
  }

  FileView {
    id: settingsFile
    path: Paths.ready ? Paths.settingsFile : ""
    watchChanges: true
    printErrors: false

    onFileChanged: {
      if (root.ignoreNextFileChange) {
        root.ignoreNextFileChange = false;
        return;
      }
      reloadDebounce.restart();
    }

    onLoaded: {
      try {
        const parsed = JSON.parse(text());
        const merged = Object.assign({}, root.defaultSettings, parsed);
        root.settings = merged;

        const currentUser = Quickshell.env("USER") || "";
        if (!merged.targetUser && currentUser && currentUser !== "greetd" && currentUser !== "greeter") {
          root.saveSettings(Object.assign({}, merged, {
            targetUser: currentUser
          }));
        }
      } catch (e) {
        console.warn("Config: failed to parse settings.json:", e);
      }
    }

    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound) {
        const currentUser = Quickshell.env("USER") || "";
        root.saveSettings(Object.assign({}, root.defaultSettings, {
          targetUser: (currentUser && currentUser !== "greetd" && currentUser !== "greeter") ? currentUser : ""
        }));
      }
    }
  }
}
