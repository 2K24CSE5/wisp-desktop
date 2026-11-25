import QtQuick
import QtQuick.Layouts
import qs.configs

Rectangle {
  id: root

  property real uiScale: 1.0
  property alias text: inputField.text
  property string placeholderText: "Password"
  property bool showPassword: false
  property bool enabled: true
  property bool busy: false
  property bool canSubmit: enabled && !busy && text.length > 0
  readonly property alias inputActiveFocus: inputField.activeFocus

  // Concentric inner spacing and button sizes derived from the pill's actual height
  readonly property real innerInset: Math.max(6, Math.round(height * 0.11))
  readonly property real submitSize: Math.max(28, height - innerInset * 2)
  readonly property real toggleSize: Math.round(submitSize * 0.88)

  signal submitted(string password)

  function forceInputFocus(): void {
    inputField.forceActiveFocus();
  }

  function clear(): void {
    inputField.text = "";
  }

  implicitWidth: Math.round(440 * uiScale)
  implicitHeight: Math.round(65 * uiScale)
  radius: height / 2
  color: Color.surface
  opacity: busy ? 0.65 : 1.0

  Behavior on border.color {
    ColorAnimation {
      duration: 160
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Math.round(root.height * 0.34)
    anchors.rightMargin: root.innerInset
    spacing: Math.round(root.height * 0.18)

    Text {
      Layout.alignment: Qt.AlignVCenter
      text: "lock"
      font.family: Config.iconFont
      font.pixelSize: Math.round(root.height * 0.34)
      color: inputField.activeFocus ? Color.primary : Color.muted

      Behavior on color {
        ColorAnimation {
          duration: 160
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      TextInput {
        id: inputField
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        height: contentHeight
        font.family: Config.textFont
        font.pixelSize: Math.max(14, Math.round(root.height * 0.25))
        color: Color.text
        echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
        enabled: root.enabled && !root.busy
        onAccepted: {
          if (root.canSubmit)
            root.submitted(text);
        }
      }

      Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: inputField.verticalCenter
        text: root.placeholderText
        font: inputField.font
        color: Color.muted
        visible: !inputField.text && !inputField.activeFocus
      }
    }

    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: root.toggleSize
      Layout.preferredHeight: root.toggleSize
      radius: width / 2
      color: root.showPassword ? Color.primary : (visibilityMouse.containsMouse ? Color.overlay : "transparent")
      scale: visibilityMouse.pressed ? 0.92 : 1.0

      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: 150
          easing.type: Easing.OutQuad
        }
      }

      Text {
        anchors.centerIn: parent
        text: root.showPassword ? "visibility_off" : "visibility"
        font.family: Config.iconFont
        font.pixelSize: Math.round(root.toggleSize * 0.48)
        color: root.showPassword ? Color.background : Color.muted
      }

      MouseArea {
        id: visibilityMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.showPassword = !root.showPassword
      }
    }

    Rectangle {
      id: submitButton
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: root.submitSize
      Layout.preferredHeight: root.submitSize
      radius: width / 2
      color: root.canSubmit ? (submitMouse.pressed ? Qt.darker(Color.primary, 1.12) : Color.primary) : Color.overlay
      scale: (root.canSubmit && submitMouse.pressed) ? 0.92 : (root.canSubmit && submitMouse.containsMouse ? 1.05 : 1.0)

      Behavior on color {
        ColorAnimation {
          duration: 160
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: 180
          easing.type: Easing.OutBack
        }
      }

      Text {
        anchors.centerIn: parent
        text: root.busy ? "progress_activity" : "arrow_forward"
        font.family: Config.iconFont
        font.pixelSize: Math.round(root.submitSize * 0.46)
        color: root.canSubmit ? Color.background : Color.muted
      }

      MouseArea {
        id: submitMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.canSubmit
        cursorShape: Qt.PointingHandCursor
        onClicked: root.submitted(inputField.text)
      }
    }
  }
}
