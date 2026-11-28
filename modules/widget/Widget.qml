import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.configs
import qs.services
import qs.components
import qs.modules.notification

Scope {
  id: root

  property string activePopup: ""
  property var activeScreen: null
  property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

  function togglePopup(name: string, scr): void {
    if (root.activePopup === name && root.activeScreen === scr) {
      root.closePopup();
    } else {
      root.activeScreen = scr;
      root.activePopup = name;
      if (name === "notifications") {
        NotificationService.openCenter();
      } else if (NotificationService.centerOpen) {
        NotificationService.closeCenter();
      }
    }
  }

  function closePopup(): void {
    root.activePopup = "";
    if (NotificationService.centerOpen) {
      NotificationService.closeCenter();
    }
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

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData

      readonly property real screenW: modelData ? modelData.width : 1440
      readonly property real screenH: modelData ? modelData.height : 900
      readonly property real rawScale: screenW > 0 && screenH > 0 ? Math.sqrt((screenW / 1440) * (screenH / 900)) : 1.0
      readonly property real uiScale: Math.max(0.85, Math.min(1.4, rawScale))
      readonly property real barHeight: Math.round(56 * uiScale)

      readonly property bool hasInteractiveHere: root.activePopup !== "" && root.activeScreen === modelData
      readonly property bool hasToastsHere: !hasInteractiveHere && root.activePopup === "" && NotificationService.hasPopups && modelData === root.primaryScreen

      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "wisp-bar"
      WlrLayershell.keyboardFocus: (hasInteractiveHere && widgetPopup.closeOnEscape) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      anchors {
        top: true
        left: true
        right: true
      }

      exclusiveZone: barHeight
      implicitHeight: screen.height
      color: "transparent"

      mask: hasInteractiveHere ? null : passiveMask

      Region {
        id: passiveMask
        regions: [
          Region {
            item: leftWorkspace
          },
          Region {
            item: centerClock
          },
          Region {
            item: rightCluster
          },
          Region {
            item: widgetPopup.maskItem
          }
        ]
      }

      // Top Bar Row
      Item {
        id: topBarArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(4 * barWindow.uiScale)
        anchors.rightMargin: Math.round(4 * barWindow.uiScale)
        height: barWindow.barHeight
        z: 2

        Workspace {
          id: leftWorkspace
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          outputName: barWindow.modelData.name
          uiScale: barWindow.uiScale
        }

        Clock {
          id: centerClock
          anchors.centerIn: parent
          uiScale: barWindow.uiScale
          active: barWindow.hasInteractiveHere && root.activePopup === "calendar"
          onClicked: root.togglePopup("calendar", barWindow.modelData)
        }

        Item {
          id: rightCluster
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: statusRow.implicitWidth
          height: statusRow.implicitHeight

          RowLayout {
            id: statusRow
            anchors.centerIn: parent
            spacing: 2

            NotificationButton {
              id: notifBtn
              uiScale: barWindow.uiScale
              edge: "left"
              active: barWindow.hasInteractiveHere && root.activePopup === "notifications"
              onClicked: root.togglePopup("notifications", barWindow.modelData)
            }

            Battery {
              id: batteryBtn
              uiScale: barWindow.uiScale
              edge: "none"
              active: barWindow.hasInteractiveHere && root.activePopup === "battery"
              onClicked: root.togglePopup("battery", barWindow.modelData)
            }

            QuickSetting {
              id: quickBtn
              uiScale: barWindow.uiScale
              edge: "right"
              active: barWindow.hasInteractiveHere && root.activePopup === "quick"
              onClicked: root.togglePopup("quick", barWindow.modelData)
            }
          }
        }
      }

      // Bottom edge of the tallest bar widget (in window coordinates)
      readonly property real widgetsBottom: topBarArea.y + Math.max(leftWorkspace.y + leftWorkspace.height, centerClock.y + centerClock.height, rightCluster.y + rightCluster.height)

      // Shared Popup Rendered Inside the Bar's Layer-Shell Window
      Popup {
        id: widgetPopup
        z: 1
        topOffset: Math.round(barWindow.widgetsBottom + 6 * barWindow.uiScale)
        marginX: Math.round(4 * barWindow.uiScale)
        open: barWindow.hasInteractiveHere || barWindow.hasToastsHere
        anchorCenterX: {
          if (barWindow.hasInteractiveHere) {
            if (root.activePopup === "calendar")
              return topBarArea.x + centerClock.x + centerClock.width * 0.5;
            if (root.activePopup === "notifications")
              return topBarArea.x + rightCluster.x + statusRow.x + notifBtn.x + notifBtn.width * 0.5;
            if (root.activePopup === "battery")
              return topBarArea.x + rightCluster.x + statusRow.x + batteryBtn.x + batteryBtn.width * 0.5;
            if (root.activePopup === "quick")
              return topBarArea.x + rightCluster.x + statusRow.x + quickBtn.x + quickBtn.width * 0.5;
          }
          return topBarArea.x + rightCluster.x + statusRow.x + notifBtn.x + notifBtn.width * 0.5;
        }
        popupWidth: {
          if (!barWindow.hasInteractiveHere)
            return Math.round(420 * barWindow.uiScale);
          if (root.activePopup === "calendar")
            return Math.round(340 * barWindow.uiScale);
          if (root.activePopup === "battery")
            return Math.round(350 * barWindow.uiScale);
          if (root.activePopup === "quick")
            return Math.round(340 * barWindow.uiScale);
          return Math.round(420 * barWindow.uiScale);
        }
        cardPadding: Math.round((barWindow.hasToastsHere ? 16 : 22) * barWindow.uiScale)
        closeOnOutsideClick: barWindow.hasInteractiveHere
        closeOnEscape: barWindow.hasInteractiveHere

        onDismissed: root.closePopup()

        Item {
          id: popupBody
          property real uiScale: barWindow.uiScale
          implicitHeight: {
            if (barWindow.hasInteractiveHere && root.activePopup === "calendar")
              return calendarView.implicitHeight;
            if (barWindow.hasInteractiveHere && root.activePopup === "notifications")
              return Math.max(Math.round(180 * popupBody.uiScale), notifCenterView.implicitHeight);
            if (barWindow.hasInteractiveHere && root.activePopup === "battery")
              return batteryView.implicitHeight;
            if (barWindow.hasInteractiveHere && root.activePopup === "quick")
              return quickPlaceholder.implicitHeight;
            if (barWindow.hasToastsHere)
              return notifToastView.implicitHeight;
            return 0;
          }

          CalendarView {
            id: calendarView
            visible: barWindow.hasInteractiveHere && root.activePopup === "calendar"
            anchors.left: parent.left
            anchors.right: parent.right
            uiScale: popupBody.uiScale
          }

          NotificationCenter {
            id: notifCenterView
            visible: barWindow.hasInteractiveHere && root.activePopup === "notifications"
            anchors.left: parent.left
            anchors.right: parent.right
            uiScale: popupBody.uiScale
          }

          BatteryView {
            id: batteryView
            visible: barWindow.hasInteractiveHere && root.activePopup === "battery"
            anchors.left: parent.left
            anchors.right: parent.right
            uiScale: popupBody.uiScale
          }

          NotificationToast {
            id: notifToastView
            visible: barWindow.hasToastsHere
            anchors.left: parent.left
            anchors.right: parent.right
            uiScale: popupBody.uiScale
          }

          ColumnLayout {
            id: quickPlaceholder
            visible: barWindow.hasInteractiveHere && root.activePopup === "quick"
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Math.round(12 * popupBody.uiScale)

            Text {
              text: "Quick Settings"
              font.family: Config.textFont
              font.pixelSize: Math.max(16, Math.round(18 * popupBody.uiScale))
              font.weight: Font.Bold
              color: Color.text
            }

            Text {
              text: (NetworkService.connected ? "Wi-Fi Connected" : "Wi-Fi Disconnected") + " · " + (BluetoothService.enabled ? "Bluetooth On" : "Bluetooth Off")
              font.family: Config.textFont
              font.pixelSize: Math.max(12, Math.round(13 * popupBody.uiScale))
              color: Color.muted
            }
          }
        }
      }
    }
  }
}
