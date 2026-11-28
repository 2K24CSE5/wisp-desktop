import QtQuick
import qs.configs

Item {
  id: root

  property bool open: false
  property real anchorCenterX: -1
  property real topOffset: 44
  property real marginX: 14
  property real popupWidth: 380
  property real maxPopupHeight: 680
  property real cardRadius: 28
  property real cardPadding: 20
  property bool closeOnOutsideClick: true
  property bool closeOnEscape: true

  default property Component contentComponent

  readonly property bool active: root.open || closing
  readonly property Item maskItem: root.active ? popupCard : null

  signal dismissed

  readonly property real containerW: parent && parent.width > 0 ? parent.width : 1440
  readonly property real containerH: parent && parent.height > 0 ? parent.height : 900
  readonly property real rawScale: Math.sqrt((containerW / 1440) * (containerH / 900))
  readonly property real uiScale: Math.max(0.85, Math.min(1.4, rawScale))

  readonly property real scaledPadding: Math.round(root.cardPadding * uiScale)
  readonly property real targetWidth: Math.min(containerW - root.marginX * 2, Math.round(root.popupWidth * uiScale))
  readonly property real contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
  readonly property real maxAvailableHeight: Math.min(containerH - root.topOffset - 16, Math.round(root.maxPopupHeight * uiScale))
  readonly property real effectiveHeight: Math.min(maxAvailableHeight, Math.max(Math.round(72 * uiScale), contentHeight + scaledPadding * 2))

  function resolveX(w: real): real {
    const minX = root.marginX;
    const maxX = Math.max(minX, containerW - w - root.marginX);
    if (root.anchorCenterX <= 0)
      return maxX;
    return Math.max(minX, Math.min(maxX, Math.round(root.anchorCenterX - w * 0.5)));
  }

  property real lockedX: resolveX(targetWidth)
  property real lockedWidth: targetWidth
  property bool shown: false
  property bool closing: false
  property bool allowSlide: false

  onAnchorCenterXChanged: {
    if (root.open) {
      lockedWidth = targetWidth;
      lockedX = resolveX(lockedWidth);
    }
  }

  onPopupWidthChanged: {
    if (root.open) {
      lockedWidth = targetWidth;
      lockedX = resolveX(lockedWidth);
    }
  }

  onContainerWChanged: {
    lockedWidth = targetWidth;
    lockedX = resolveX(lockedWidth);
  }

  onOpenChanged: {
    if (root.open) {
      closeTimer.stop();
      closing = false;
      allowSlide = false;
      const w = Math.min(containerW - root.marginX * 2, Math.round(root.popupWidth * uiScale));
      lockedWidth = w;
      lockedX = resolveX(w);
      shown = true;
      slideTimer.restart();
    } else if (shown || closing) {
      slideTimer.stop();
      allowSlide = false;
      closing = true;
      shown = false;
      closeTimer.restart();
    }
  }

  Timer {
    id: slideTimer
    interval: 20
    onTriggered: {
      if (root.open && root.shown) {
        root.allowSlide = true;
      }
    }
  }

  Timer {
    id: closeTimer
    interval: 160
    onTriggered: {
      root.closing = false;
      root.allowSlide = false;
    }
  }

  anchors.fill: parent
  visible: true

  MouseArea {
    anchors.fill: parent
    visible: root.open && root.closeOnOutsideClick
    enabled: root.open && root.closeOnOutsideClick
    onClicked: root.dismissed()
  }

  Rectangle {
    id: popupCard
    x: root.lockedX
    y: root.topOffset
    width: root.lockedWidth
    height: root.shown ? root.effectiveHeight : Math.round(44 * root.uiScale)
    radius: Math.round(root.cardRadius * root.uiScale)
    color: Color.background
    clip: true
    focus: root.open

    opacity: root.shown ? 1.0 : 0.0
    scale: root.shown ? 1.0 : 0.95
    transformOrigin: Item.Top

    Keys.onEscapePressed: event => {
      if (root.open && root.closeOnEscape) {
        root.dismissed();
        event.accepted = true;
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.active
      acceptedButtons: Qt.AllButtons
    }

    Behavior on x {
      enabled: root.allowSlide
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Behavior on width {
      enabled: root.allowSlide
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Behavior on height {
      NumberAnimation {
        duration: root.shown ? 200 : 150
        easing.type: Easing.OutCubic
      }
    }

    Behavior on opacity {
      NumberAnimation {
        duration: root.shown ? 160 : 120
        easing.type: Easing.OutCubic
      }
    }

    Behavior on scale {
      NumberAnimation {
        duration: root.shown ? 200 : 150
        easing.type: Easing.OutCubic
      }
    }

    Loader {
      id: contentLoader
      active: true
      sourceComponent: root.contentComponent
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: root.scaledPadding

      onLoaded: {
        if (item && item.hasOwnProperty("uiScale")) {
          item.uiScale = Qt.binding(() => root.uiScale);
        }
      }
    }
  }
}
