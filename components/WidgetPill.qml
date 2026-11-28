import QtQuick
import Quickshell
import qs.configs

Rectangle {
  id: root

  readonly property var targetScreen: {
    const win = Window.window;
    if (win && win.screen)
      return win.screen;
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
  }
  readonly property real rawScale: (targetScreen && targetScreen.width > 0 && targetScreen.height > 0) ? Math.sqrt((targetScreen.width / 1440) * (targetScreen.height / 900)) : 1.0
  property real uiScale: Math.max(0.85, Math.min(1.4, rawScale))

  property bool active: false
  property bool interactive: !grouped
  property bool circular: false
  property bool grouped: false
  property bool inner: false
  property string edge: "none" // "none" | "left" | "right" | "only"

  property real horizontalPadding: Math.round((grouped ? 4 : (inner ? 10 : 14)) * uiScale)
  property real pillHeight: Math.round(40 * uiScale)
  property real outerRadius: Math.round(16 * uiScale)
  property real innerRadius: 4
  property real contentImplicitWidth: 0

  readonly property real leftRadius: {
    if (circular)
      return height / 2;
    if (!inner || edge === "left" || edge === "only")
      return outerRadius;
    return innerRadius;
  }
  readonly property real rightRadius: {
    if (circular)
      return height / 2;
    if (!inner || edge === "right" || edge === "only")
      return outerRadius;
    return innerRadius;
  }

  property color baseColor: Color.background
  property color hoverColor: Color.surface
  property color activeColor: Color.surface

  readonly property bool hovered: interactive && pillMouse.containsMouse
  readonly property bool pressed: interactive && pillMouse.pressed

  signal clicked

  implicitWidth: circular ? pillHeight : Math.max(pillHeight, contentImplicitWidth + horizontalPadding * 2)
  implicitHeight: pillHeight

  topLeftRadius: leftRadius
  bottomLeftRadius: leftRadius
  topRightRadius: rightRadius
  bottomRightRadius: rightRadius

  color: root.active ? root.activeColor : (root.hovered ? root.hoverColor : root.baseColor)
  scale: root.pressed ? 0.96 : 1.0

  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  Behavior on scale {
    NumberAnimation {
      duration: 140
      easing.type: Easing.OutQuad
    }
  }

  MouseArea {
    id: pillMouse
    anchors.fill: parent
    enabled: root.interactive
    hoverEnabled: root.interactive
    cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.clicked()
  }
}
