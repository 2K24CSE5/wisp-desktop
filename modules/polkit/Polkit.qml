import QtQuick
import QtQuick.Layouts
import qs.configs
import qs.services
import qs.components

Modal {
  id: root

  property string errorMessage: ""
  property bool isAuthenticating: false

  open: PolkitService.dialogOpen
  namespace: "wisp-polkit"
  scrimOpacity: 0.5
  cardWidth: 480
  cardPadding: 28

  onDismissed: PolkitService.dismiss()
  onOpenedOnPrimary: item => {
    errorMessage = "";
    isAuthenticating = false;
    item.resetAndFocus();
  }

  ColumnLayout {
    id: polkitContent
    property real uiScale: 1.0
    spacing: Math.round(18 * uiScale)

    function resetAndFocus(): void {
      passInput.clear();
      Qt.callLater(() => passInput.forceInputFocus());
    }

    Connections {
      target: PolkitService.flow
      ignoreUnknownSignals: true

      function onAuthenticationFailed(): void {
        root.isAuthenticating = false;
        root.errorMessage = "Authentication failed. Please try again.";
        polkitContent.resetAndFocus();
      }
    }

    // Title & Policy Message
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Math.round(6 * polkitContent.uiScale)

      Text {
        Layout.fillWidth: true
        text: "Authentication Required"
        horizontalAlignment: Text.AlignHCenter
        font.family: Config.textFont
        font.pixelSize: Math.max(18, Math.round(21 * polkitContent.uiScale))
        font.weight: Font.Bold
        color: Color.text
      }

      Text {
        Layout.fillWidth: true
        text: PolkitService.message
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        font.family: Config.textFont
        font.pixelSize: Math.max(13, Math.round(14 * polkitContent.uiScale))
        font.weight: Font.Normal
        color: Color.muted
      }
    }

    // Identity Pill (Avatar + Username)
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      readonly property real padX: Math.round(16 * polkitContent.uiScale)
      readonly property real padY: Math.round(8 * polkitContent.uiScale)

      implicitWidth: Math.min(polkitContent.width * 0.85, identityRow.implicitWidth + padX * 2)
      implicitHeight: identityRow.implicitHeight + padY * 2
      radius: height / 2
      color: Color.surface

      RowLayout {
        id: identityRow
        anchors.centerIn: parent
        spacing: Math.round(10 * polkitContent.uiScale)

        Rectangle {
          width: Math.round(28 * polkitContent.uiScale)
          height: Math.round(28 * polkitContent.uiScale)
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
            font.pixelSize: Math.round(14 * polkitContent.uiScale)
            font.weight: Font.Bold
            color: Color.background
          }
        }

        Text {
          text: PolkitService.systemUser
          font.family: Config.textFont
          font.pixelSize: Math.max(13, Math.round(14 * polkitContent.uiScale))
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
      Layout.maximumWidth: Math.round(420 * polkitContent.uiScale)
      uiScale: polkitContent.uiScale
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
      font.pixelSize: Math.max(12, Math.round(13 * polkitContent.uiScale))
      font.weight: Font.Medium
      color: Color.error
    }
  }
}
