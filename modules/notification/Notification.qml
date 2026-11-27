import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.configs
import qs.services
import qs.components

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

      readonly property real earRadius: Math.round(14 * uiScale)
      readonly property real bodyWidth: Math.round(430 * uiScale)
      readonly property real liveHeight: NotificationService.centerOpen ? Math.min(Math.round(700 * uiScale), Math.max(Math.round(120 * uiScale), centerView.implicitHeight + Math.round(44 * uiScale))) : Math.min(Math.round(640 * uiScale), Math.max(Math.round(80 * uiScale), toastView.implicitHeight + Math.round(32 * uiScale)))

      property real cachedHeight: Math.round(120 * uiScale)
      property bool shown: false
      property bool closing: false
      property bool centerSession: false
      readonly property bool activeState: NotificationService.shouldShowWindow

      onLiveHeightChanged: {
        if (activeState) {
          cachedHeight = liveHeight;
        }
      }

      onActiveStateChanged: {
        if (activeState) {
          centerSession = NotificationService.centerOpen;
          cachedHeight = liveHeight;
          closeTimer.stop();
          closing = false;
          shown = true;
        } else {
          closing = true;
          shown = false;
          closeTimer.restart();
        }
      }

      Connections {
        target: NotificationService
        function onCenterOpenChanged() {
          if (NotificationService.centerOpen) {
            notifWindow.centerSession = true;
          }
        }
      }

      Component.onCompleted: {
        if (activeState) {
          centerSession = NotificationService.centerOpen;
          cachedHeight = liveHeight;
          shown = true;
        }
      }

      Timer {
        id: closeTimer
        interval: 260
        onTriggered: {
          notifWindow.closing = false;
          notifWindow.centerSession = false;
          if (!NotificationService.hasPopups) {
            toastView.clearAll();
          }
        }
      }

      visible: activeState || closing
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "wisp-notifications"
      WlrLayershell.keyboardFocus: (NotificationService.centerOpen && isPrimaryScreen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      // Full-screen anchors only during Notification Center sessions (never for passive toasts)
      anchors {
        top: true
        right: true
        bottom: NotificationService.centerOpen || (closing && centerSession)
        left: NotificationService.centerOpen || (closing && centerSession)
      }

      margins {
        top: 0
        right: 0
        bottom: 0
        left: 0
      }

      implicitWidth: bodyWidth + earRadius
      implicitHeight: cachedHeight + earRadius

      // Transparent Click-Outside Backdrop
      MouseArea {
        anchors.fill: parent
        visible: NotificationService.centerOpen
        enabled: NotificationService.centerOpen
        onClicked: NotificationService.closeCenter()
      }

      // Docked Top-Right Expanding Container
      Rectangle {
        id: dockBody
        anchors.top: parent.top
        anchors.right: parent.right
        width: notifWindow.shown ? notifWindow.bodyWidth : 48
        height: notifWindow.shown ? notifWindow.cachedHeight : 42
        opacity: notifWindow.shown ? 1.0 : 0.0
        topLeftRadius: 0
        topRightRadius: 0
        bottomRightRadius: 0
        bottomLeftRadius: notifWindow.shown ? Math.round(28 * notifWindow.uiScale) : 14
        color: Color.background
        clip: true
        focus: NotificationService.centerOpen

        Keys.onEscapePressed: event => {
          if (NotificationService.centerOpen) {
            NotificationService.closeCenter();
            event.accepted = true;
          }
        }

        // Prevent clicks inside the notification panel from bubbling to the backdrop
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
        }

        Behavior on width {
          NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
          }
        }

        Behavior on height {
          NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
          }
        }

        Behavior on bottomLeftRadius {
          NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

        NotificationCenter {
          id: centerView
          visible: notifWindow.centerSession
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Math.round(22 * notifWindow.uiScale)
          uiScale: notifWindow.uiScale
        }

        NotificationToast {
          id: toastView
          visible: !notifWindow.centerSession && activeCount > 0
          active: NotificationService.hasPopups
          popups: NotificationService.activePopups
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Math.round(16 * notifWindow.uiScale)
          uiScale: notifWindow.uiScale
        }
      }

      // Vertical Concave Fillet (flares down along right screen edge below dockBody)
      Shape {
        anchors.right: dockBody.right
        anchors.top: dockBody.bottom
        anchors.topMargin: -1
        width: notifWindow.earRadius
        height: notifWindow.earRadius + 1
        opacity: dockBody.opacity
        visible: notifWindow.earRadius > 0.2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeWidth: 0
          fillColor: Color.background
          startX: notifWindow.earRadius
          startY: notifWindow.earRadius + 1
          PathArc {
            x: 0
            y: 1
            radiusX: notifWindow.earRadius
            radiusY: notifWindow.earRadius
            direction: PathArc.Counterclockwise
          }
          PathLine {
            x: 0
            y: 0
          }
          PathLine {
            x: notifWindow.earRadius
            y: 0
          }
          PathLine {
            x: notifWindow.earRadius
            y: notifWindow.earRadius + 1
          }
        }
      }

      // Horizontal Concave Fillet (scoops left along top screen edge left of dockBody)
      Shape {
        anchors.right: dockBody.left
        anchors.rightMargin: -1
        anchors.top: dockBody.top
        width: notifWindow.earRadius + 1
        height: notifWindow.earRadius
        opacity: dockBody.opacity
        visible: notifWindow.earRadius > 0.2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
          strokeWidth: 0
          fillColor: Color.background
          startX: notifWindow.earRadius
          startY: notifWindow.earRadius
          PathArc {
            x: 0
            y: 0
            radiusX: notifWindow.earRadius
            radiusY: notifWindow.earRadius
            direction: PathArc.Counterclockwise
          }
          PathLine {
            x: notifWindow.earRadius + 1
            y: 0
          }
          PathLine {
            x: notifWindow.earRadius + 1
            y: notifWindow.earRadius
          }
          PathLine {
            x: notifWindow.earRadius
            y: notifWindow.earRadius
          }
        }
      }
    }
  }
}
