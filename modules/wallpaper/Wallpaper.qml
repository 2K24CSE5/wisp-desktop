import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.configs
import qs.services
import qs.components

Scope {
  id: root

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: wallpaperWindow
      required property var modelData
      screen: modelData

      readonly property real targetInset: NiriService.overviewOpen ? WallpaperService.overviewInsetFor(modelData) : 0
      readonly property real targetRadius: NiriService.overviewOpen ? WallpaperService.overviewRadiusFor(modelData) : 0

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
        id: wallpaperFrame

        property real animatedInset: wallpaperWindow.targetInset
        property real animatedRadius: wallpaperWindow.targetRadius

        Behavior on animatedInset {
          SpringAnimation {
            spring: 4.0
            damping: NiriService.overviewOpen ? 0.28 : 0.42
            epsilon: 0.05
          }
        }

        Behavior on animatedRadius {
          SpringAnimation {
            spring: 4.0
            damping: NiriService.overviewOpen ? 0.28 : 0.42
            epsilon: 0.05
          }
        }

        readonly property real safeInset: Math.max(0, animatedInset)
        readonly property real safeRadius: Math.max(0, animatedRadius)

        anchors {
          fill: parent
          margins: safeInset
        }
        clip: true

        CrossfadeImage {
          anchors.centerIn: parent
          width: wallpaperWindow.width
          height: wallpaperWindow.height
          source: WallpaperService.currentWallpaper
        }

        // Hollow rounded corner frame matching Color.background
        Rectangle {
          anchors.fill: parent
          anchors.margins: -wallpaperFrame.safeRadius
          radius: wallpaperFrame.safeRadius * 2
          color: "transparent"
          border.width: wallpaperFrame.safeRadius
          border.color: Color.background
        }
      }
    }
  }
}
