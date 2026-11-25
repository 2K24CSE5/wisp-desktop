import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.configs
import qs.services
import qs.components

Scope {
  id: root

  Variants {
    model: Quickshell.screens
    delegate: PanelWindow {
      id: greeterWindow
      required property var modelData
      screen: modelData

      color: Color.background
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      WlrLayershell.namespace: "greetd-greeter"

      // Wallpaper Background
      CrossfadeImage {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper
        opacity: 0.4
      }

      // Top Bar: Session Chooser
      RowLayout {
        z: 1
        anchors {
          top: parent.top
          right: parent.right
          margins: 24
        }
        spacing: 8

        Text {
          text: "Session:"
          font.family: Config.textFont
          font.pixelSize: 13
          color: Color.muted
        }

        Rectangle {
          id: sessionBtn
          implicitHeight: 34
          implicitWidth: sessionRow.implicitWidth + 28
          radius: 17
          color: sessionMouse.containsMouse ? Color.overlay : Color.surface
          border.width: 1
          border.color: Color.subtle
          opacity: (!GreeterService.isLoadingSessions && GreeterService.availableSessions.length > 0) ? 1.0 : 0.5

          RowLayout {
            id: sessionRow
            anchors.centerIn: parent
            spacing: 6

            Text {
              text: "desktop_windows"
              font.family: Config.iconFont
              font.pixelSize: 16
              color: Color.primary
            }

            Text {
              text: GreeterService.isLoadingSessions ? "Loading sessions..." : (GreeterService.selectedSession ? GreeterService.selectedSession.name : "No sessions found")
              font.family: Config.textFont
              font.pixelSize: 13
              font.weight: Font.DemiBold
              color: Color.text
            }
          }

          MouseArea {
            id: sessionMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !GreeterService.isLoadingSessions && GreeterService.availableSessions.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              GreeterService.selectSession((GreeterService.selectedSessionIndex + 1) % GreeterService.availableSessions.length);
            }
          }
        }
      }

      // Center Panel: Clock & Credentials
      ColumnLayout {
        id: centerPanel
        z: 1
        anchors.centerIn: parent
        width: 320
        spacing: 20

        // Clock
        ColumnLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: 2

          Text {
            text: GreeterService.currentTime
            font.family: Config.textFont
            font.pixelSize: 56
            font.bold: true
            color: Color.text
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: GreeterService.currentDate
            font.family: Config.textFont
            font.pixelSize: 14
            color: Color.muted
            Layout.alignment: Qt.AlignHCenter
          }
        }

        Item {
          Layout.preferredHeight: 12
        }

        // Avatar Icon Frame
        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: 72
          height: 72
          radius: width / 2
          color: Color.surface
          border.color: Color.overlay
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "person"
            font.family: Config.iconFont
            font.pixelSize: 36
            color: Color.primary
          }
        }

        // Inputs & Login Button
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 10

          // Username Input
          Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: 21
            color: Color.surface
            border.width: userInput.activeFocus ? 2 : 1
            border.color: userInput.activeFocus ? Color.primary : Color.subtle

            RowLayout {
              anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 14
              }
              spacing: 10

              Text {
                text: "person"
                font.family: Config.iconFont
                font.pixelSize: 18
                color: userInput.activeFocus ? Color.primary : Color.muted
              }

              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextInput {
                  id: userInput
                  anchors.fill: parent
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: Config.textFont
                  font.pixelSize: 14
                  color: Color.text
                  text: GreeterService.defaultUsername
                  clip: true
                  onAccepted: passInput.forceActiveFocus()
                }

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  font: userInput.font
                  color: Color.muted
                  text: "Username"
                  visible: !userInput.text && !userInput.activeFocus
                }
              }
            }
          }

          // Password Input
          Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: 21
            color: Color.surface
            border.width: passInput.activeFocus ? 2 : 1
            border.color: passInput.activeFocus ? Color.primary : Color.subtle
            opacity: !GreeterService.isAuthenticating ? 1.0 : 0.6

            RowLayout {
              anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 14
              }
              spacing: 10

              Text {
                text: "lock"
                font.family: Config.iconFont
                font.pixelSize: 18
                color: passInput.activeFocus ? Color.primary : Color.muted
              }

              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextInput {
                  id: passInput
                  anchors.fill: parent
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: Config.textFont
                  font.pixelSize: 14
                  color: Color.text
                  echoMode: TextInput.Password
                  enabled: !GreeterService.isAuthenticating
                  clip: true
                  onAccepted: submit()

                  function submit(): void {
                    if (userInput.text.length > 0 && passInput.text.length > 0) {
                      GreeterService.login(userInput.text, passInput.text);
                    }
                  }
                }

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  font: passInput.font
                  color: Color.muted
                  text: "Password"
                  visible: !passInput.text && !passInput.activeFocus
                }
              }
            }
          }

          // Login Button
          Rectangle {
            id: loginBtn
            Layout.fillWidth: true
            height: 40
            radius: 20
            readonly property bool canSubmit: userInput.text.length > 0 && passInput.text.length > 0 && !GreeterService.isAuthenticating
            color: loginMouse.pressed ? Qt.darker(Color.primary, 1.15) : Color.primary
            opacity: canSubmit ? 1.0 : 0.45

            RowLayout {
              anchors.centerIn: parent
              spacing: 8

              Text {
                text: "login"
                font.family: Config.iconFont
                font.pixelSize: 18
                color: Color.background
              }

              Text {
                text: GreeterService.isAuthenticating ? "Logging in..." : "Login"
                font.family: Config.textFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Color.background
              }
            }

            MouseArea {
              id: loginMouse
              anchors.fill: parent
              enabled: loginBtn.canSubmit
              cursorShape: Qt.PointingHandCursor
              onClicked: passInput.submit()
            }
          }

          // Status Message
          Text {
            visible: GreeterService.statusMessage.length > 0
            text: GreeterService.statusMessage
            font.family: Config.textFont
            font.pixelSize: 12
            color: {
              const msg = GreeterService.statusMessage.toLowerCase();
              return (msg.includes("failed") || msg.includes("error") || msg.includes("failure")) ? Color.error : Color.muted;
            }
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
          }
        }
      }

      // Bottom Actions: Power controls
      RowLayout {
        z: 1
        anchors {
          bottom: parent.bottom
          horizontalCenter: parent.horizontalCenter
          margins: 28
        }
        spacing: 12

        Repeater {
          model: [
            {
              icon: "bedtime",
              action: () => GreeterService.suspend()
            },
            {
              icon: "restart_alt",
              action: () => GreeterService.reboot()
            },
            {
              icon: "power_settings_new",
              action: () => GreeterService.powerOff()
            }
          ]

          delegate: Rectangle {
            required property var modelData
            width: 38
            height: 38
            radius: 19
            color: powerMouse.containsMouse ? Color.overlay : "transparent"

            Text {
              anchors.centerIn: parent
              text: parent.modelData.icon
              font.family: Config.iconFont
              font.pixelSize: 20
              color: Color.text
            }

            MouseArea {
              id: powerMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: parent.modelData.action()
            }
          }
        }
      }

      Component.onCompleted: passInput.forceActiveFocus()

      Connections {
        target: GreeterService
        function onLoginFailed(): void {
          passInput.text = "";
          passInput.forceActiveFocus();
        }
      }
    }
  }
}
