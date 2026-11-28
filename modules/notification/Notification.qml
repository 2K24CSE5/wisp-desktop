import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.configs
import qs.services

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: notifWindow
      required property var modelData
      screen: modelData

      readonly property bool isPrimaryScreen: modelData === Quickshell.screens[0]
      readonly property real screenW: modelData ? modelData.width : 1440
      readonly property real screenH: modelData ? modelData.height : 900
      readonly property real rawScale: screenW > 0 && screenH > 0 ? Math.sqrt((screenW / 1440) * (screenH / 900)) : 1.0
      readonly property real uiScale: Math.max(0.85, Math.min(1.4, rawScale))

      readonly property real topBarHeight: 40
      readonly property real cardGapTop: 4
      readonly property real cardMarginRight: 14
      readonly property real bodyWidth: Math.round(420 * uiScale)
      readonly property real liveHeight: NotificationService.centerOpen ? Math.min(Math.round(680 * uiScale), Math.max(Math.round(120 * uiScale), centerView.implicitHeight + Math.round(44 * uiScale))) : Math.min(Math.round(620 * uiScale), Math.max(Math.round(80 * uiScale), toastView.implicitHeight + Math.round(32 * uiScale)))

      property real cachedHeight: Math.round(120 * uiScale)

      onLiveHeightChanged: {
        if (NotificationService.shouldShowWindow) {
          cachedHeight = liveHeight;
        }
      }

      visible: NotificationService.windowVisible
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "wisp-notifications"
      WlrLayershell.keyboardFocus: (NotificationService.centerOpen && isPrimaryScreen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      anchors {
        top: true
        right: true
        bottom: NotificationService.fullScreenMode
        left: NotificationService.fullScreenMode
      }

      margins {
        top: topBarHeight
        right: NotificationService.fullScreenMode ? 0 : cardMarginRight
        bottom: 0
        left: 0
      }

      implicitWidth: bodyWidth
      implicitHeight: cachedHeight + cardGapTop

      // Click-outside backdrop below the top bar
      MouseArea {
        anchors.fill: parent
        visible: NotificationService.centerOpen
        enabled: NotificationService.centerOpen
        onClicked: NotificationService.closeCenter()
      }

      // Floating Popup Container Below Top Widget Bar
      Rectangle {
        id: popupCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: notifWindow.cardGapTop
        anchors.rightMargin: NotificationService.fullScreenMode ? notifWindow.cardMarginRight : 0

        width: notifWindow.bodyWidth
        height: NotificationService.windowShown ? notifWindow.cachedHeight : Math.round(48 * notifWindow.uiScale)
        radius: Math.round(28 * notifWindow.uiScale)
        color: Color.background
        border.width: 1
        border.color: Color.overlay
        clip: true
        focus: NotificationService.centerOpen

        opacity: NotificationService.windowShown ? 1.0 : 0.0
        scale: NotificationService.windowShown ? 1.0 : 0.95
        transformOrigin: Item.TopRight

        Keys.onEscapePressed: event => {
          if (NotificationService.centerOpen) {
            NotificationService.closeCenter();
            event.accepted = true;
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
        }

        Behavior on height {
          NumberAnimation {
            duration: NotificationService.windowShown ? 200 : 150
            easing.type: Easing.OutCubic
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: NotificationService.windowShown ? 160 : 120
            easing.type: Easing.OutCubic
          }
        }

        Behavior on scale {
          NumberAnimation {
            duration: NotificationService.windowShown ? 200 : 150
            easing.type: Easing.OutCubic
          }
        }

        NotificationCenter {
          id: centerView
          visible: NotificationService.centerSession
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Math.round(22 * notifWindow.uiScale)
          uiScale: notifWindow.uiScale
        }

        NotificationToast {
          id: toastView
          visible: !NotificationService.centerSession && NotificationService.toastGroups.length > 0
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Math.round(16 * notifWindow.uiScale)
          uiScale: notifWindow.uiScale
        }
      }
    }
  }
}
