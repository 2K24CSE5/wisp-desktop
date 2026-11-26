import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.configs
import qs.services
import qs.components

Scope {
  id: root

  property string errorMessage: ""
  property bool isAuthenticating: false

  Connections {
    target: PolkitService

    function onDialogOpenChanged(): void {
      if (PolkitService.dialogOpen) {
        root.errorMessage = "";
        root.isAuthenticating = false;
      }
    }
  }

  Connections {
    target: PolkitService.flow
    ignoreUnknownSignals: true

    function onAuthenticationFailed(): void {
      root.isAuthenticating = false;
      root.errorMessage = "Authentication failed. Please try again.";
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: polkitWindow
      required property var modelData
      screen: modelData
      color: "transparent"

      readonly property bool isPrimaryScreen: modelData === Quickshell.screens[0]
      readonly property real uiScale: Math.max(0.72, Math.min(1.35, Math.min(width / 1440, height / 960)))

      visible: PolkitService.dialogOpen

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: (PolkitService.dialogOpen && isPrimaryScreen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      WlrLayershell.namespace: "wisp-polkit"

      // Scrim backdrop
      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: PolkitService.dialogOpen ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: PolkitService.dismiss()
        }
      }

      // Centered M3 Expressive Polkit Dialog Card (primary screen)
      Rectangle {
        id: dialogCard
        visible: polkitWindow.isPrimaryScreen
        anchors.centerIn: parent

        readonly property real marginX: Math.max(20, parent.width * 0.04)
        readonly property real marginY: Math.max(64, parent.height * 0.08)
        readonly property real cardPadding: Math.round(28 * polkitWindow.uiScale)

        width: Math.min(parent.width - marginX * 2, Math.round(480 * polkitWindow.uiScale))
        height: Math.min(parent.height - marginY * 2, contentCol.implicitHeight + cardPadding * 2)
        radius: Math.round(32 * polkitWindow.uiScale)
        color: Color.background
        clip: true

        scale: PolkitService.dialogOpen ? 1.0 : 0.92
        opacity: PolkitService.dialogOpen ? 1.0 : 0.0

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
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Keys.onEscapePressed: PolkitService.dismiss()

        // Absorb clicks inside card
        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        ColumnLayout {
          id: contentCol
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: dialogCard.cardPadding
            rightMargin: dialogCard.cardPadding
          }
          spacing: Math.round(18 * polkitWindow.uiScale)

          // Shield / Lock Badge
          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: Math.round(64 * polkitWindow.uiScale)
            height: Math.round(64 * polkitWindow.uiScale)
            radius: width / 2
            color: Color.surface

            Text {
              anchors.centerIn: parent
              text: "shield_lock"
              font.family: Config.iconFont
              font.pixelSize: Math.round(30 * polkitWindow.uiScale)
              color: Color.primary
            }
          }

          // Title & Policy Message
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(6 * polkitWindow.uiScale)

            Text {
              Layout.fillWidth: true
              text: "Authentication Required"
              horizontalAlignment: Text.AlignHCenter
              font.family: Config.textFont
              font.pixelSize: Math.max(18, Math.round(21 * polkitWindow.uiScale))
              font.weight: Font.Bold
              color: Color.text
            }

            Text {
              Layout.fillWidth: true
              text: PolkitService.message
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              font.family: Config.textFont
              font.pixelSize: Math.max(13, Math.round(14 * polkitWindow.uiScale))
              font.weight: Font.Normal
              color: Color.muted
            }
          }

          // Identity Pill (Avatar + Username)
          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            readonly property real padX: Math.round(16 * polkitWindow.uiScale)
            readonly property real padY: Math.round(8 * polkitWindow.uiScale)

            implicitWidth: Math.min(contentCol.width * 0.85, identityRow.implicitWidth + padX * 2)
            implicitHeight: identityRow.implicitHeight + padY * 2
            radius: height / 2
            color: Color.surface

            RowLayout {
              id: identityRow
              anchors.centerIn: parent
              spacing: Math.round(10 * polkitWindow.uiScale)

              Rectangle {
                width: Math.round(28 * polkitWindow.uiScale)
                height: Math.round(28 * polkitWindow.uiScale)
                radius: width / 2
                color: Color.primary
                clip: true

                Image {
                  id: faceImg
                  anchors.fill: parent
                  source: PolkitService.avatarPath
                  fillMode: Image.PreserveAspectCrop
                  visible: status === Image.Ready
                }

                Text {
                  anchors.centerIn: parent
                  visible: faceImg.status !== Image.Ready
                  text: PolkitService.systemUser.charAt(0).toUpperCase()
                  font.family: Config.textFont
                  font.pixelSize: Math.round(14 * polkitWindow.uiScale)
                  font.weight: Font.Bold
                  color: Color.background
                }
              }

              Text {
                text: PolkitService.systemUser
                font.family: Config.textFont
                font.pixelSize: Math.max(13, Math.round(14 * polkitWindow.uiScale))
                font.weight: Font.Medium
                color: Color.text
              }
            }
          }

          // Reusable M3 Expressive Password Input
          PasswordInput {
            id: passInput
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(420 * polkitWindow.uiScale)
            uiScale: polkitWindow.uiScale
            busy: root.isAuthenticating
            onSubmitted: password => {
              root.errorMessage = "";
              root.isAuthenticating = true;
              PolkitService.submit(password);
            }
          }

          // Error Feedback
          Text {
            Layout.fillWidth: true
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: Config.textFont
            font.pixelSize: Math.max(12, Math.round(13 * polkitWindow.uiScale))
            font.weight: Font.Medium
            color: Color.error
          }

          // Cancel Action Pill
          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: cancelLabel.implicitWidth + Math.round(32 * polkitWindow.uiScale)
            implicitHeight: Math.round(38 * polkitWindow.uiScale)
            radius: height / 2
            color: cancelMouse.containsMouse ? Color.overlay : Color.surface

            Behavior on color {
              ColorAnimation {
                duration: 150
              }
            }

            Text {
              id: cancelLabel
              anchors.centerIn: parent
              text: "Cancel"
              font.family: Config.textFont
              font.pixelSize: Math.max(12, Math.round(13 * polkitWindow.uiScale))
              font.weight: Font.Medium
              color: Color.text
            }

            MouseArea {
              id: cancelMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: PolkitService.dismiss()
            }
          }
        }
      }

      Connections {
        target: PolkitService
        function onDialogOpenChanged(): void {
          if (PolkitService.dialogOpen && polkitWindow.isPrimaryScreen) {
            passInput.clear();
            Qt.callLater(() => passInput.forceInputFocus());
          }
        }
      }

      Connections {
        target: PolkitService.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed(): void {
          if (polkitWindow.isPrimaryScreen) {
            passInput.clear();
            Qt.callLater(() => passInput.forceInputFocus());
          }
        }
      }
    }
  }
}
