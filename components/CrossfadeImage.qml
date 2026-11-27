import QtQuick

Item {
  id: root

  property string source: ""
  property int fillMode: Image.PreserveAspectCrop
  property int transitionDuration: 650
  property bool showA: true

  component Layer: Image {
    property bool isA: true
    readonly property bool isCurrent: root.showA === isA
    readonly property bool active: isCurrent && status === Image.Ready

    anchors.fill: parent
    fillMode: root.fillMode
    sourceSize: Qt.size(Screen.width, Screen.height)
    asynchronous: true
    cache: true
    mipmap: true
    smooth: true
    transformOrigin: Item.Center

    z: isCurrent ? 2 : 1
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : (isCurrent ? 1.06 : 0.97)

    onStatusChanged: {
      if (status === Image.Ready && !isCurrent && source !== "") {
        root.showA = isA;
      } else if (status === Image.Error && source !== "") {
        console.warn("CrossfadeImage: failed to load", source);
        source = "";
      }
    }

    onOpacityChanged: {
      if (opacity === 0.0 && !isCurrent && source !== "")
        source = "";
    }

    Behavior on scale {
      NumberAnimation {
        duration: root.transitionDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
      }
    }

    Behavior on opacity {
      NumberAnimation {
        duration: Math.round(root.transitionDuration * 0.5)
        easing.type: Easing.OutCubic
      }
    }
  }

  onSourceChanged: {
    if (!source) {
      layerA.source = "";
      layerB.source = "";
      showA = true;
      return;
    }

    const active = showA ? layerA : layerB;
    const standby = showA ? layerB : layerA;

    if (active.source === "" && standby.source === "") {
      showA = true;
      layerA.source = source;
      return;
    }

    if (active.source === source && active.status === Image.Ready)
      return;

    standby.source = source;
    if (standby.status === Image.Ready)
      showA = (standby === layerA);
  }

  Layer {
    id: layerA
    isA: true
  }

  Layer {
    id: layerB
    isA: false
  }
}
