import QtQuick
import QtQuick.Controls

ListView {
  id: root

  property real uiScale: 1.0
  property real rowHeight: 64
  property real frictionDecay: 3.5
  property real wheelMultiplier: 12
  property real maxVelocity: 5500
  property real maxEdgeStretch: 14
  property bool showScrollBar: true

  readonly property real itemStep: Math.round(rowHeight * uiScale) + spacing
  readonly property real exactContentHeight: Math.max(0, count * itemStep - spacing)
  readonly property real maxScrollY: Math.max(0, exactContentHeight - height)

  property real scrollVelocity: 0
  property real edgeStretch: 0

  clip: true
  boundsBehavior: Flickable.StopAtBounds
  interactive: false
  cacheBuffer: Math.round(240 * uiScale)
  highlightMoveDuration: 180
  highlightMoveVelocity: -1

  function resetScroll(): void {
    scrollVelocity = 0;
    contentY = 0;
  }

  // Clamp cleanly if the model shrinks while scrolled down
  onMaxScrollYChanged: {
    if (contentY > maxScrollY) {
      contentY = maxScrollY;
      scrollVelocity = 0;
    }
  }

  transform: Translate {
    y: root.edgeStretch
  }

  SequentialAnimation {
    id: edgeBounceAnim
    PropertyAnimation {
      target: root
      property: "edgeStretch"
      duration: 85
      easing.type: Easing.OutQuad
    }
    SpringAnimation {
      target: root
      property: "edgeStretch"
      to: 0
      spring: 4.5
      damping: 0.35
      epsilon: 0.1
    }
  }

  FrameAnimation {
    id: momentumTick
    running: Math.abs(root.scrollVelocity) > 4
    onTriggered: {
      const dt = Math.min(frameTime, 0.05);
      const nextY = root.contentY + root.scrollVelocity * dt;

      if (nextY <= 0) {
        root.contentY = 0;
        root.scrollVelocity = 0;
        return;
      }
      if (nextY >= root.maxScrollY) {
        root.contentY = root.maxScrollY;
        root.scrollVelocity = 0;
        return;
      }

      root.contentY = nextY;
      root.scrollVelocity *= Math.exp(-dt * root.frictionDecay);
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
      const rawDelta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y * 2.5 : wheel.angleDelta.y;

      if (rawDelta === 0)
        return;

      const scrollingUp = rawDelta > 0;
      const atTopEdge = scrollingUp && root.contentY <= 0.5;
      const atBottomEdge = !scrollingUp && root.contentY >= (root.maxScrollY - 0.5);

      if (atTopEdge || atBottomEdge) {
        root.scrollVelocity = 0;
        const limit = Math.round(root.maxEdgeStretch * root.uiScale);
        const direction = scrollingUp ? 1 : -1;
        const nextStretch = Math.max(-limit, Math.min(limit, root.edgeStretch + direction * 6));

        edgeBounceAnim.stop();
        edgeBounceAnim.animations[0].to = nextStretch;
        edgeBounceAnim.start();
        wheel.accepted = true;
        return;
      }

      const impulse = -rawDelta * root.wheelMultiplier;
      const sameDirection = (impulse > 0 && root.scrollVelocity > 0) || (impulse < 0 && root.scrollVelocity < 0);

      root.scrollVelocity = sameDirection ? Math.max(-root.maxVelocity, Math.min(root.maxVelocity, root.scrollVelocity * 0.65 + impulse)) : impulse;

      wheel.accepted = true;
    }
  }

  ScrollBar.vertical: ScrollBar {
    visible: root.showScrollBar
    policy: root.showScrollBar ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    width: 4
  }
}
