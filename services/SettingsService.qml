pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.configs
import qs.services

Singleton {
  id: root

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
    target: "settings"

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
