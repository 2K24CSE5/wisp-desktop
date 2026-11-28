pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.configs

Singleton {
  id: root

  readonly property var darkPalette: ({
      background: "#0e1513",
      surface: "#171d1b",
      overlay: "#252b29",
      muted: "#89938f",
      subtle: "#3f4945",
      text: "#dee4e0",
      primary: "#85d6c0",
      secondary: "#b1ccc3",
      tertiary: "#aacbe3",
      warning: "#aacbe3",
      info: "#b1ccc3",
      error: "#ffb4ab"
    })

  readonly property var lightPalette: ({
      background: "#f5fbf7",
      surface: "#eff5f1",
      overlay: "#e3eae6",
      muted: "#6f7975",
      subtle: "#bfc9c4",
      text: "#171d1b",
      primary: "#0a6b5a",
      secondary: "#4b635c",
      tertiary: "#426277",
      warning: "#426277",
      info: "#4b635c",
      error: "#ba1a1a"
    })
  readonly property bool isDark: Config.isDark

  property var colorData: ({
      dark: darkPalette,
      light: lightPalette
    })

  readonly property var palette: isDark ? colorData.dark : colorData.light

  readonly property color background: palette.background
  readonly property color surface: palette.surface
  readonly property color overlay: palette.overlay
  readonly property color muted: palette.muted
  readonly property color subtle: palette.subtle
  readonly property color text: palette.text
  readonly property color primary: palette.primary
  readonly property color secondary: palette.secondary
  readonly property color tertiary: palette.tertiary
  readonly property color warning: palette.warning
  readonly property color info: palette.info
  readonly property color error: palette.error

  Timer {
    id: reloadTimer
    interval: 50
    onTriggered: colorFile.reload()
  }

  FileView {
    id: colorFile
    path: Directory.ready ? Directory.colorsFile : ""
    watchChanges: true
    printErrors: false

    onFileChanged: reloadTimer.restart()

    onLoaded: {
      try {
        const parsed = JSON.parse(text());
        if (parsed.dark && parsed.light)
          root.colorData = parsed;
      } catch (e) {
        console.warn("Color: failed to parse colors.json:", e);
      }
    }

    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound) {
        colorFile.setText(JSON.stringify({
          dark: root.darkPalette,
          light: root.lightPalette
        }, null, 2));
      }
    }
  }
}
