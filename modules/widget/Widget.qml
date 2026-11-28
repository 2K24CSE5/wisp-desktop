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

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData

      readonly property real uiScale: WidgetService.scaleForScreen(modelData)
      readonly property int pillHeight: Math.round(40 * uiScale)
      readonly property int barHeight: pillHeight + 4

      readonly property bool hasInteractiveHere: WidgetService.activePopup !== "" && WidgetService.activeScreen === modelData
      readonly property bool hasToastsHere: !hasInteractiveHere && WidgetService.activePopup === "" && NotificationService.hasPopups && modelData === WidgetService.primaryScreen

      readonly property real widgetsBottom: topBarArea.y + Math.max(leftWorkspace.y + leftWorkspace.height, centerClock.y + centerClock.height, rightCluster.y + rightCluster.height)

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
        anchors {
          top: parent.top
          topMargin: 4
          left: parent.left
          right: parent.right
          leftMargin: 4
          rightMargin: 4
        }
        height: barWindow.pillHeight
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
          active: WidgetService.isPopupOpen("calendar", barWindow.modelData)
          onClicked: WidgetService.togglePopup("calendar", barWindow.modelData)
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
              active: WidgetService.isPopupOpen("notifications", barWindow.modelData)
              onClicked: WidgetService.togglePopup("notifications", barWindow.modelData)
            }

            Battery {
              id: batteryBtn
              uiScale: barWindow.uiScale
              edge: "none"
              active: WidgetService.isPopupOpen("battery", barWindow.modelData)
              onClicked: WidgetService.togglePopup("battery", barWindow.modelData)
            }

            QuickSetting {
              id: quickBtn
              uiScale: barWindow.uiScale
              edge: "right"
              active: WidgetService.isPopupOpen("quick", barWindow.modelData)
              onClicked: WidgetService.togglePopup("quick", barWindow.modelData)
            }
          }
        }
      }

      // Shared Popup Rendered Inside the Bar's Layer-Shell Window
      Popup {
        id: widgetPopup
        z: 1
        topOffset: Math.round(barWindow.widgetsBottom + 6 * barWindow.uiScale)
        marginX: Math.round(4 * barWindow.uiScale)
        open: barWindow.hasInteractiveHere || barWindow.hasToastsHere
        popupWidth: WidgetService.popupWidthFor(WidgetService.activePopup, barWindow.hasInteractiveHere, barWindow.uiScale)
        cardPadding: Math.round((barWindow.hasToastsHere ? 16 : 22) * barWindow.uiScale)
        closeOnOutsideClick: barWindow.hasInteractiveHere
        closeOnEscape: barWindow.hasInteractiveHere

        anchorCenterX: {
          if (!barWindow.hasInteractiveHere)
            return topBarArea.x + rightCluster.x + statusRow.x + notifBtn.x + notifBtn.width * 0.5;
          if (WidgetService.activePopup === "calendar")
            return topBarArea.x + centerClock.x + centerClock.width * 0.5;
          const target = WidgetService.activePopup === "battery" ? batteryBtn : WidgetService.activePopup === "quick" ? quickBtn : notifBtn;
          return topBarArea.x + rightCluster.x + statusRow.x + target.x + target.width * 0.5;
        }

        onDismissed: WidgetService.closePopup()

        Item {
          id: popupBody
          property real uiScale: barWindow.uiScale

          implicitHeight: {
            if (barWindow.hasToastsHere)
              return notifToastView.implicitHeight;
            if (!barWindow.hasInteractiveHere)
              return 0;
            if (WidgetService.activePopup === "calendar")
              return calendarView.implicitHeight;
            if (WidgetService.activePopup === "notifications")
              return Math.max(Math.round(180 * uiScale), notifCenterView.implicitHeight);
            if (WidgetService.activePopup === "battery")
              return batteryView.implicitHeight;
            if (WidgetService.activePopup === "quick")
              return quickPlaceholder.implicitHeight;
            return 0;
          }

          CalendarView {
            id: calendarView
            visible: WidgetService.isPopupOpen("calendar", barWindow.modelData)
            anchors {
              left: parent.left
              right: parent.right
            }
            uiScale: popupBody.uiScale
          }

          NotificationCenter {
            id: notifCenterView
            visible: WidgetService.isPopupOpen("notifications", barWindow.modelData)
            anchors {
              left: parent.left
              right: parent.right
            }
            uiScale: popupBody.uiScale
          }

          BatteryView {
            id: batteryView
            visible: WidgetService.isPopupOpen("battery", barWindow.modelData)
            anchors {
              left: parent.left
              right: parent.right
            }
            uiScale: popupBody.uiScale
          }

          NotificationToast {
            id: notifToastView
            visible: barWindow.hasToastsHere
            anchors {
              left: parent.left
              right: parent.right
            }
            uiScale: popupBody.uiScale
          }

          ColumnLayout {
            id: quickPlaceholder
            visible: WidgetService.isPopupOpen("quick", barWindow.modelData)
            anchors {
              left: parent.left
              right: parent.right
            }
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
