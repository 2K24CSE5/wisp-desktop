import QtQuick
import QtQuick.Layouts
import qs.configs
import qs.services
import qs.components

WidgetPill {
  id: root
  required property string outputName

  readonly property var screenWorkspaces: NiriService.workspaces.filter(ws => ws.output === root.outputName)

  interactive: false
  horizontalPadding: Math.round(12 * uiScale)
  contentImplicitWidth: wsRow.implicitWidth

  RowLayout {
    id: wsRow
    anchors.centerIn: parent
    spacing: Math.round(7 * root.uiScale)

    Repeater {
      model: root.screenWorkspaces

      Rectangle {
        id: wsPill
        required property var modelData
        readonly property bool isFocused: Boolean(modelData.is_focused)
        readonly property bool isOccupied: modelData.active_window_id !== null && modelData.active_window_id !== undefined

        Layout.preferredWidth: Math.round((isFocused ? 28 : 14) * root.uiScale)
        Layout.preferredHeight: Math.round(14 * root.uiScale)
        radius: height / 2
        color: {
          if (isFocused)
            return Color.primary;
          if (wsMouse.containsMouse)
            return Color.text;
          if (isOccupied)
            return Color.muted;
          return Color.subtle;
        }
        opacity: isFocused ? 1.0 : (isOccupied ? 0.85 : (wsMouse.containsMouse ? 0.9 : 0.5))
        scale: wsMouse.pressed ? 0.92 : 1.0

        Behavior on Layout.preferredWidth {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

        Behavior on color {
          ColorAnimation {
            duration: 150
          }
        }

        Behavior on opacity {
          NumberAnimation {
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
          id: wsMouse
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: NiriService.focusWorkspace(modelData.idx)
        }
      }
    }
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
      if (event.angleDelta.y > 0) {
        NiriService.focusPreviousWorkspace();
      } else if (event.angleDelta.y < 0) {
        NiriService.focusNextWorkspace();
      }
    }
  }
}
