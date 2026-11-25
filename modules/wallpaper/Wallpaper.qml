import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.configs
import qs.services
import qs.components

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.namespace: "wisp-wallpaper"
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      color: Color.background

      Item {
        anchors.fill: parent
        clip: true

        CrossfadeImage {
          anchors.fill: parent
          source: WallpaperService.currentWallpaper
        }
      }
    }
  }
}
