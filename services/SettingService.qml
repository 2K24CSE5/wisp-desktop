pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.configs
import qs.services

Singleton {
  id: root

  property bool uiOpen: false
  property int activeTab: 0

  readonly property var sections: [
    {
      id: "general",
      icon: "tune",
      label: "General"
    },
    {
      id: "appearance",
      icon: "palette",
      label: "Appearance"
    },
    {
      id: "system",
      icon: "settings",
      label: "System"
    }
  ]

  function toggleUi(): void {
    uiOpen = !uiOpen;
  }

  function openUi(): void {
    uiOpen = true;
  }

  function closeUi(): void {
    uiOpen = false;
  }

  function selectTab(index: int): void {
    if (index >= 0 && index < sections.length) {
      activeTab = index;
    }
  }

  function set(key: string, value): void {
    if (!(key in Config.defaultSettings)) {
      console.warn("Unknown setting key:", key);
      return;
    }
    if (key === "wallpaper") {
      WallpaperService.setWallpaper(value);
      return;
    }
    let normalized = value;
    if (key === "isDark" && typeof value === "string") {
      normalized = value.trim().toLowerCase() === "true";
    }
    const updated = Object.assign({}, Config.settings);
    updated[key] = normalized;
    Config.saveSettings(updated);
  }

  function setIconFont(fontName: string): void {
    if (fontName && fontName !== Config.iconFont) {
      set("iconFont", fontName.trim());
    }
  }

  function setTextFont(fontName: string): void {
    if (fontName && fontName !== Config.textFont) {
      set("textFont", fontName.trim());
    }
  }

  function setDarkMode(dark: bool): void {
    if (dark !== Config.isDark) {
      set("isDark", dark);
    }
  }

  function toggleDarkMode(): void {
    set("isDark", !Config.isDark);
  }

  function reset(): void {
    Config.saveSettings(Config.defaultSettings);
  }

  property IpcHandler settingsIpc: IpcHandler {
    target: "setting"

    function toggle(): void {
      root.toggleUi();
    }

    function open(): void {
      root.openUi();
    }

    function close(): void {
      root.closeUi();
    }

    function setWallpaper(path: string): void {
      WallpaperService.setWallpaper(path);
    }

    function setIconFont(fontName: string): void {
      root.setIconFont(fontName);
    }

    function setTextFont(fontName: string): void {
      root.setTextFont(fontName);
    }

    function setDarkMode(dark: bool): void {
      root.setDarkMode(dark);
    }

    function toggleDarkMode(): void {
      root.toggleDarkMode();
    }

    function set(key: string, value: string): void {
      root.set(key, value);
    }

    function reset(): void {
      root.reset();
    }
  }
}
