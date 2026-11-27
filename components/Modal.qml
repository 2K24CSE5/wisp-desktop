import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.configs

Scope {
  id: root

  property bool open: false
  property string namespace: "wisp-modal"
  property real scrimOpacity: 0.45
  property real cardWidth: 520
  property real cardHeight: 0 // 0 = auto-size to loaded content implicitHeight
  property real cardPadding: 24
  property real cardRadius: 32
  property real minMarginRatioX: 0.04
  property real minMarginRatioY: 0.06
  property bool closeOnBackdropClick: true
  property bool closeOnEscape: true

  default property Component contentComponent

  signal dismissed
  signal openedOnPrimary(var item)

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: modalWindow
      required property var modelData
      screen: modelData
      color: "transparent"

      readonly property bool isPrimaryScreen: modelData === Quickshell.screens[0]

      // Resolution-independent scale using geometric mean of logical screen dimensions (baseline 1440x900)
      readonly property real rawScale: width > 0 && height > 0 ? Math.sqrt((width / 1440) * (height / 900)) : 1.0
      readonly property real uiScale: Math.max(0.75, Math.min(1.4, rawScale))

      readonly property real scaledPadding: Math.max(14, Math.round(root.cardPadding * uiScale))
      readonly property real safeMarginX: Math.max(16, Math.round(width * root.minMarginRatioX))
      readonly property real safeMarginY: Math.max(24, Math.round(height * root.minMarginRatioY))
      readonly property real maxAvailableWidth: Math.max(260, width - safeMarginX * 2)
      readonly property real maxAvailableHeight: Math.max(200, height - safeMarginY * 2)

      visible: root.open
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: (root.open && isPrimaryScreen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      WlrLayershell.namespace: root.namespace

      // Scrim backdrop covering the entire screen
      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.scrimOpacity)
        opacity: root.open ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            if (root.closeOnBackdropClick)
              root.dismissed();
          }
        }
      }

      // Centered M3 Expressive Modal Card (primary screen)
      Rectangle {
        id: card
        visible: modalWindow.isPrimaryScreen
        anchors.centerIn: parent

        readonly property real loadedHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
        readonly property real desiredHeight: root.cardHeight > 0 ? Math.round(root.cardHeight * modalWindow.uiScale) : (loadedHeight + modalWindow.scaledPadding * 2)

        width: Math.min(modalWindow.maxAvailableWidth, Math.round(root.cardWidth * modalWindow.uiScale))
        height: Math.min(modalWindow.maxAvailableHeight, Math.max(80, desiredHeight))
        radius: Math.min(Math.round(root.cardRadius * modalWindow.uiScale), Math.round(Math.min(width, height) * 0.25))
        color: Color.background
        clip: true

        scale: root.open ? 1.0 : 0.92
        opacity: root.open ? 1.0 : 0.0

        Behavior on scale {
          NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.12
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Behavior on height {
          enabled: root.cardHeight <= 0
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Keys.onEscapePressed: event => {
          if (root.closeOnEscape) {
            root.dismissed();
            event.accepted = true;
          }
        }

        // Prevent clicks inside card from dismissing scrim
        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        Flickable {
          id: contentFlickable
          anchors.fill: parent
          anchors.margins: modalWindow.scaledPadding
          clip: true
          interactive: root.cardHeight <= 0 && contentHeight > height
          contentWidth: width
          contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
          boundsBehavior: Flickable.StopAtBounds

          Loader {
            id: contentLoader
            active: modalWindow.isPrimaryScreen
            sourceComponent: root.contentComponent
            width: contentFlickable.width
            height: root.cardHeight > 0 ? contentFlickable.height : implicitHeight

            onLoaded: {
              if (item && item.hasOwnProperty("uiScale")) {
                item.uiScale = Qt.binding(() => modalWindow.uiScale);
              }
            }
          }
        }
      }

      Connections {
        target: root
        function onOpenChanged(): void {
          if (root.open && modalWindow.isPrimaryScreen && contentLoader.item) {
            root.openedOnPrimary(contentLoader.item);
          }
        }
      }
    }
  }
}
