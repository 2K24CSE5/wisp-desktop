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

    PanelWindow {
      id: greeterWindow
      required property var modelData
      screen: modelData
      color: "transparent"

      readonly property real uiScale: Math.max(0.72, Math.min(1.35, Math.min(width / 1440, height / 960)))
      readonly property real screenMargin: Math.max(20, Math.round(28 * uiScale))

      function moveSelectedUser(offset: int): void {
        const users = GreeterService.availableUsers;
        if (users.length < 2 || GreeterService.isAuthenticating)
          return;

        const index = (GreeterService.selectedUserIndex + offset + users.length) % users.length;
        GreeterService.selectUser(users[index].username);
        passInput.clear();
        passInput.forceInputFocus();
      }

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0] ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      WlrLayershell.namespace: "wisp-greeter"

      CrossfadeImage {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper
        opacity: 1
      }

      // Centered Login Card (Clock, Avatar, Username, Password)
      Rectangle {
        id: loginCard
        anchors.centerIn: parent

        readonly property real marginX: Math.max(20, parent.width * 0.04)
        readonly property real marginY: Math.max(84, parent.height * 0.10)
        readonly property real cardPadding: Math.round(28 * greeterWindow.uiScale)

        width: Math.min(parent.width - marginX * 2, Math.round(520 * greeterWindow.uiScale))
        height: Math.min(parent.height - marginY * 2, contentCol.implicitHeight + cardPadding * 2)
        radius: Math.round(32 * greeterWindow.uiScale)
        color: Color.background
        clip: true

        Behavior on height {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        ColumnLayout {
          id: contentCol
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: loginCard.cardPadding
            rightMargin: loginCard.cardPadding
          }
          spacing: Math.round(22 * greeterWindow.uiScale)

          // Hero Clock & Date Pill
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(6 * greeterWindow.uiScale)

            Text {
              Layout.alignment: Qt.AlignHCenter
              textFormat: Text.StyledText
              text: {
                const raw = GreeterService.currentTime || "";
                const colonIdx = raw.indexOf(":");
                if (colonIdx === -1)
                  return raw;
                const left = raw.slice(0, colonIdx + 1);
                const right = raw.slice(colonIdx + 1);
                return `${left}<font color="${Color.primary}">${right}</font>`;
              }
              font.family: Config.textFont
              font.pixelSize: Math.round(104 * greeterWindow.uiScale)
              font.weight: Font.ExtraBold
              font.letterSpacing: -2 * greeterWindow.uiScale
              color: Color.text
            }

            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: Math.min(contentCol.width * 0.85, dateLabel.implicitWidth + Math.round(34 * greeterWindow.uiScale))
              height: Math.round(48 * greeterWindow.uiScale)
              radius: height / 2
              color: Color.surface

              Text {
                id: dateLabel
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Math.round(24 * greeterWindow.uiScale))
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: GreeterService.currentDate
                font.family: Config.textFont
                font.pixelSize: Math.max(14, Math.round(15 * greeterWindow.uiScale))
                font.weight: Font.Medium
                font.letterSpacing: 0.4
                color: Color.text
              }
            }
          }

          // Expressive Avatar & User Switcher
          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(138 * greeterWindow.uiScale)

            readonly property real avatarSize: Math.round(134 * greeterWindow.uiScale)
            readonly property real navSize: Math.round(46 * greeterWindow.uiScale)

            Rectangle {
              id: avatar
              width: parent.avatarSize
              height: parent.avatarSize
              radius: width / 2
              anchors.centerIn: parent
              color: Color.primary

              Text {
                anchors.centerIn: parent
                text: GreeterService.selectedUser ? GreeterService.selectedUser.name.charAt(0).toUpperCase() : "person"
                font.family: GreeterService.selectedUser ? Config.textFont : Config.iconFont
                font.pixelSize: Math.round((GreeterService.selectedUser ? 62 : 68) * greeterWindow.uiScale)
                font.weight: Font.DemiBold
                color: Color.background
              }
            }

            Rectangle {
              width: parent.navSize
              height: parent.navSize
              radius: height / 2
              anchors.verticalCenter: avatar.verticalCenter
              anchors.right: avatar.left
              anchors.rightMargin: Math.max(14, Math.round(24 * greeterWindow.uiScale))
              visible: GreeterService.availableUsers.length > 1
              color: previousUserMouse.containsMouse ? Color.primary : Color.surface
              opacity: GreeterService.isAuthenticating ? 0.5 : 1
              scale: previousUserMouse.pressed ? 0.92 : (previousUserMouse.containsMouse ? 1.05 : 1.0)

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
                text: "chevron_left"
                font.family: Config.iconFont
                font.pixelSize: Math.round(26 * greeterWindow.uiScale)
                color: previousUserMouse.containsMouse ? Color.background : Color.text
              }

              MouseArea {
                id: previousUserMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: GreeterService.availableUsers.length > 1 && !GreeterService.isAuthenticating
                cursorShape: Qt.PointingHandCursor
                onClicked: greeterWindow.moveSelectedUser(-1)
              }
            }

            Rectangle {
              width: parent.navSize
              height: parent.navSize
              radius: height / 2
              anchors.verticalCenter: avatar.verticalCenter
              anchors.left: avatar.right
              anchors.leftMargin: Math.max(14, Math.round(24 * greeterWindow.uiScale))
              visible: GreeterService.availableUsers.length > 1
              color: nextUserMouse.containsMouse ? Color.primary : Color.surface
              opacity: GreeterService.isAuthenticating ? 0.5 : 1
              scale: nextUserMouse.pressed ? 0.92 : (nextUserMouse.containsMouse ? 1.05 : 1.0)

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
                text: "chevron_right"
                font.family: Config.iconFont
                font.pixelSize: Math.round(26 * greeterWindow.uiScale)
                color: nextUserMouse.containsMouse ? Color.background : Color.text
              }

              MouseArea {
                id: nextUserMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: GreeterService.availableUsers.length > 1 && !GreeterService.isAuthenticating
                cursorShape: Qt.PointingHandCursor
                onClicked: greeterWindow.moveSelectedUser(1)
              }
            }
          }

          // Username Pill Container
          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            readonly property real padX: Math.round(20 * greeterWindow.uiScale)
            readonly property real padY: Math.round(10 * greeterWindow.uiScale)

            implicitWidth: Math.min(contentCol.width * 0.78, usernameLabel.implicitWidth + padX * 2)
            implicitHeight: usernameLabel.implicitHeight + padY * 2
            radius: height / 2
            color: Color.surface

            Behavior on implicitWidth {
              NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
              }
            }

            Text {
              id: usernameLabel
              anchors.centerIn: parent
              width: Math.min(implicitWidth, parent.width - parent.padX * 2)
              text: GreeterService.isLoadingUsers ? "Loading accounts…" : (GreeterService.selectedUser ? GreeterService.selectedUser.username : "No accounts available")
              horizontalAlignment: Text.AlignHCenter
              font.family: Config.textFont
              font.pixelSize: Math.max(15, Math.round(17 * greeterWindow.uiScale))
              font.weight: Font.Medium
              font.letterSpacing: 0.2
              color: Color.text
              elide: Text.ElideRight
            }
          }

          // Reusable M3 Expressive Password Input
          PasswordInput {
            id: passInput
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(440 * greeterWindow.uiScale)
            uiScale: greeterWindow.uiScale
            enabled: !!GreeterService.selectedUser
            busy: GreeterService.isAuthenticating
            onSubmitted: password => {
              if (GreeterService.selectedUser)
                GreeterService.login(GreeterService.selectedUser.username, password);
            }
          }

          // Status / Error Feedback
          Text {
            Layout.fillWidth: true
            visible: GreeterService.statusMessage.length > 0
            text: GreeterService.statusMessage
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: Config.textFont
            font.pixelSize: Math.max(12, Math.round(13 * greeterWindow.uiScale))
            font.weight: Font.Medium
            color: {
              const msg = GreeterService.statusMessage.toLowerCase();
              return (msg.includes("failed") || msg.includes("error") || msg.includes("failure") || msg.includes("could not")) ? Color.error : Color.muted;
            }
          }
        }
      }

      // Bottom-Left Screen Corner: Reusable Expandable Power Pill
      ExpandableActionPill {
        id: powerPill
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: greeterWindow.screenMargin
        anchors.bottomMargin: greeterWindow.screenMargin
        uiScale: greeterWindow.uiScale
        triggerIcon: "power_settings_new"
        actions: [
          {
            icon: "bedtime",
            label: "Sleep",
            action: () => GreeterService.suspend()
          },
          {
            icon: "restart_alt",
            label: "Restart",
            action: () => GreeterService.reboot()
          },
          {
            icon: "power_settings_new",
            label: "Shut down",
            action: () => GreeterService.powerOff()
          }
        ]
        onToggled: isExpanded => {
          if (isExpanded)
            sessionPill.expanded = false;
        }
      }

      // Bottom-Right Screen Corner: Reusable Expandable Session Selector Pill
      ExpandableSelectorPill {
        id: sessionPill
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: greeterWindow.screenMargin
        anchors.bottomMargin: greeterWindow.screenMargin
        uiScale: greeterWindow.uiScale
        icon: "desktop_windows"
        emptyText: "No sessions"
        loading: GreeterService.isLoadingSessions
        items: GreeterService.availableSessions
        selectedIndex: GreeterService.selectedSessionIndex
        maxExpandedWidth: parent.width - powerPill.width - greeterWindow.screenMargin * 3
        onToggled: isExpanded => {
          if (isExpanded)
            powerPill.expanded = false;
        }
        onItemSelected: index => GreeterService.selectSession(index)
      }

      Component.onCompleted: {
        if (modelData === Quickshell.screens[0])
          Qt.callLater(() => passInput.forceInputFocus());
      }

      Connections {
        target: GreeterService

        function onLoginFailed(): void {
          passInput.clear();
          passInput.forceInputFocus();
        }
      }
    }
  }
}
