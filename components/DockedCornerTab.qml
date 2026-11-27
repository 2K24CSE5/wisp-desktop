import QtQuick
import QtQuick.Shapes
import qs.configs

Item {
  id: root

  // "left" | "right" and "bottom" | "top"
  property string edge: "left"
  property string verticalEdge: "bottom"
  property bool forceExpanded: false
  property real frameInset: 8
  property real expandedHeight: 42
  property real collapsedHeight: 6
  property real horizontalPadding: 28
  property real collapsedWidthRatio: 0.5
  property real cornerRadius: 14
  property color expandedColor: Color.background
  property color collapsedColor: Color.subtle

  default property alias content: contentContainer.data

  readonly property bool expanded: root.forceExpanded || hoverHandler.hovered
  readonly property real contentWidth: contentContainer.childrenRect.width
  readonly property real fullWidth: Math.max(40, contentWidth + root.horizontalPadding)
  readonly property real lineWidth: Math.round(fullWidth * root.collapsedWidthRatio)
  readonly property bool isLeft: root.edge === "left"
  readonly property bool isBottom: root.verticalEdge === "bottom"

  property real earRadius: expanded ? root.cornerRadius : 0
  property color fillColor: expanded ? root.expandedColor : root.collapsedColor

  implicitWidth: expanded ? fullWidth : lineWidth
  implicitHeight: expanded ? ((root.expandedHeight + root.frameInset) + root.cornerRadius) : root.collapsedHeight

  Behavior on earRadius {
    NumberAnimation {
      duration: 180
      easing.type: Easing.OutCubic
    }
  }

  Behavior on fillColor {
    ColorAnimation {
      duration: 150
    }
  }

  // Main Docked Tab Body
  Rectangle {
    id: tabBody
    anchors.left: root.isLeft ? parent.left : undefined
    anchors.right: root.isLeft ? undefined : parent.right
    anchors.bottom: root.isBottom ? parent.bottom : undefined
    anchors.top: root.isBottom ? undefined : parent.top

    height: root.expanded ? (root.expandedHeight + root.frameInset) : root.collapsedHeight
    width: root.expanded ? root.fullWidth : root.lineWidth
    topLeftRadius: root.isBottom ? (root.isLeft ? 0 : (root.expanded ? root.cornerRadius : root.collapsedHeight / 2)) : 0
    topRightRadius: root.isBottom ? (root.isLeft ? (root.expanded ? root.cornerRadius : root.collapsedHeight / 2) : 0) : 0
    bottomLeftRadius: !root.isBottom ? (root.isLeft ? 0 : (root.expanded ? root.cornerRadius : root.collapsedHeight / 2)) : 0
    bottomRightRadius: !root.isBottom ? (root.isLeft ? (root.expanded ? root.cornerRadius : root.collapsedHeight / 2) : 0) : 0
    color: root.fillColor
    clip: true

    Behavior on height {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Behavior on width {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Behavior on topLeftRadius {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Behavior on topRightRadius {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Behavior on bottomLeftRadius {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Behavior on bottomRightRadius {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    HoverHandler {
      id: hoverHandler
    }

    Item {
      id: contentContainer
      anchors.centerIn: parent
      anchors.verticalCenterOffset: root.expanded ? (root.isBottom ? -(root.frameInset * 0.5) : (root.frameInset * 0.5)) : 0
      width: childrenRect.width
      height: childrenRect.height
      opacity: root.expanded ? 1.0 : 0.0

      Behavior on opacity {
        NumberAnimation {
          duration: 140
        }
      }
    }
  }

  // Vertical Concave Fillet (flares along outer side frame)
  Shape {
    anchors.left: root.isLeft ? tabBody.left : undefined
    anchors.right: root.isLeft ? undefined : tabBody.right
    anchors.bottom: root.isBottom ? tabBody.top : undefined
    anchors.bottomMargin: root.isBottom ? -1 : 0
    anchors.top: root.isBottom ? undefined : tabBody.bottom
    anchors.topMargin: root.isBottom ? 0 : -1
    width: root.earRadius
    height: root.earRadius + 1
    visible: root.earRadius > 0.2
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      fillColor: root.fillColor
      startX: root.isLeft ? 0 : root.earRadius
      startY: root.isBottom ? 0 : (root.earRadius + 1)
      PathArc {
        x: root.isLeft ? root.earRadius : 0
        y: root.isBottom ? root.earRadius : 1
        radiusX: root.earRadius
        radiusY: root.earRadius
        direction: (root.isLeft === root.isBottom) ? PathArc.Counterclockwise : PathArc.Clockwise
      }
      PathLine {
        x: root.isLeft ? root.earRadius : 0
        y: root.isBottom ? (root.earRadius + 1) : 0
      }
      PathLine {
        x: root.isLeft ? 0 : root.earRadius
        y: root.isBottom ? (root.earRadius + 1) : 0
      }
      PathLine {
        x: root.isLeft ? 0 : root.earRadius
        y: root.isBottom ? 0 : (root.earRadius + 1)
      }
    }
  }

  // Horizontal Concave Fillet (scoops inward onto top or bottom frame)
  Shape {
    anchors.left: root.isLeft ? tabBody.right : undefined
    anchors.leftMargin: root.isLeft ? -1 : 0
    anchors.right: root.isLeft ? undefined : tabBody.left
    anchors.rightMargin: root.isLeft ? 0 : -1
    anchors.bottom: root.isBottom ? tabBody.bottom : undefined
    anchors.bottomMargin: root.isBottom ? root.frameInset : 0
    anchors.top: root.isBottom ? undefined : tabBody.top
    anchors.topMargin: root.isBottom ? 0 : root.frameInset
    width: root.earRadius + 1
    height: root.earRadius
    visible: root.earRadius > 0.2
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      fillColor: root.fillColor
      startX: root.isLeft ? 1 : root.earRadius
      startY: root.isBottom ? 0 : root.earRadius
      PathArc {
        x: root.isLeft ? (root.earRadius + 1) : 0
        y: root.isBottom ? root.earRadius : 0
        radiusX: root.earRadius
        radiusY: root.earRadius
        direction: (root.isLeft === root.isBottom) ? PathArc.Counterclockwise : PathArc.Clockwise
      }
      PathLine {
        x: root.isLeft ? 0 : (root.earRadius + 1)
        y: root.isBottom ? root.earRadius : 0
      }
      PathLine {
        x: root.isLeft ? 0 : (root.earRadius + 1)
        y: root.isBottom ? 0 : root.earRadius
      }
      PathLine {
        x: root.isLeft ? 1 : root.earRadius
        y: root.isBottom ? 0 : root.earRadius
      }
    }
  }
}
