import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.configs
import qs.services

Scope {
  id: root

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: launcherWindow
      required property var modelData
      screen: modelData
      visible: LauncherService.isOpen && modelData === Quickshell.screens[0]
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      WlrLayershell.namespace: "wisp-launcher"

      Rectangle {
        anchors.fill: parent
        color: "#99000000"

        MouseArea {
          anchors.fill: parent
          onClicked: LauncherService.close()
        }
      }

      Rectangle {
        id: launcherPanel
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 620)
        height: Math.min(parent.height - 48, 500)
        radius: 20
        color: Color.surface
        border.width: 1
        border.color: Color.subtle

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 20
          spacing: 14

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              text: "apps"
              font.family: Config.iconFont
              font.pixelSize: 24
              color: Color.primary
            }

            Text {
              text: "Applications"
              font.family: Config.textFont
              font.pixelSize: 20
              font.weight: Font.DemiBold
              color: Color.text
              Layout.fillWidth: true
            }

            Text {
              text: "ESC"
              font.family: Config.textFont
              font.pixelSize: 11
              color: Color.muted
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 12
            color: Color.background
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? Color.primary : Color.subtle

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 10

              Text {
                text: "search"
                font.family: Config.iconFont
                font.pixelSize: 20
                color: searchInput.activeFocus ? Color.primary : Color.muted
              }

              TextInput {
                id: searchInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                font.family: Config.textFont
                font.pixelSize: 15
                color: Color.text
                clip: true
                selectByMouse: true
                text: LauncherService.searchText

                onTextEdited: LauncherService.setSearchText(text)
                onAccepted: LauncherService.launchSelected()

                Keys.onEscapePressed: event => {
                  LauncherService.close();
                  event.accepted = true;
                }
                Keys.onDownPressed: event => {
                  LauncherService.selectNext();
                  if (LauncherService.selectedIndex >= 0)
                    appList.positionViewAtIndex(LauncherService.selectedIndex, ListView.Contain);
                  event.accepted = true;
                }
                Keys.onUpPressed: event => {
                  LauncherService.selectPrevious();
                  if (LauncherService.selectedIndex >= 0)
                    appList.positionViewAtIndex(LauncherService.selectedIndex, ListView.Contain);
                  event.accepted = true;
                }
              }
            }
          }

          ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: LauncherService.applications
            currentIndex: LauncherService.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            onModelChanged: Qt.callLater(() => positionViewAtBeginning())

            delegate: Rectangle {
              id: appRow
              required property var modelData
              required property int index
              width: appList.width
              height: 54
              radius: 11
              color: ListView.isCurrentItem ? Color.overlay : "transparent"

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                IconImage {
                  Layout.preferredWidth: 32
                  Layout.preferredHeight: 32
                  source: appRow.modelData.icon ? Quickshell.iconPath(appRow.modelData.icon, true) : ""
                  asynchronous: true
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  Text {
                    text: appRow.modelData.name
                    font.family: Config.textFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Color.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    text: appRow.modelData.genericName || appRow.modelData.comment
                    visible: text.length > 0
                    font.family: Config.textFont
                    font.pixelSize: 11
                    color: Color.muted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                Text {
                  text: "arrow_forward"
                  font.family: Config.iconFont
                  font.pixelSize: 18
                  color: Color.primary
                  visible: ListView.isCurrentItem
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: LauncherService.selectedIndex = appRow.index
                onClicked: LauncherService.launch(appRow.modelData)
              }
            }

            Text {
              anchors.centerIn: parent
              visible: appList.count === 0
              text: "No applications found"
              font.family: Config.textFont
              font.pixelSize: 14
              color: Color.muted
            }
          }

          Text {
            Layout.fillWidth: true
            text: "↑  ↓  Navigate     ↵  Launch"
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.textFont
            font.pixelSize: 11
            color: Color.muted
          }
        }
      }

      onVisibleChanged: {
        if (visible) {
          Qt.callLater(() => searchInput.forceActiveFocus());
        }
      }
    }
  }
}