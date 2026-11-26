import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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
      color: "transparent"

      readonly property bool isPrimaryScreen: modelData === Quickshell.screens[0]
      readonly property real uiScale: Math.max(0.72, Math.min(1.35, Math.min(width / 1440, height / 960)))

      visible: LauncherService.isOpen

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: (LauncherService.isOpen && isPrimaryScreen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      WlrLayershell.namespace: "wisp-launcher"

      // Scrim backdrop
      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: LauncherService.isOpen ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: LauncherService.close()
        }
      }

      // Centered M3 Expressive Launcher Card (rendered on primary screen)
      Rectangle {
        id: launcherCard
        visible: launcherWindow.isPrimaryScreen
        anchors.centerIn: parent

        readonly property real marginX: Math.max(20, parent.width * 0.04)
        readonly property real marginY: Math.max(64, parent.height * 0.08)
        readonly property real cardPadding: Math.round(24 * launcherWindow.uiScale)

        width: Math.min(parent.width - marginX * 2, Math.round(620 * launcherWindow.uiScale))
        height: Math.min(parent.height - marginY * 2, Math.round(560 * launcherWindow.uiScale))
        radius: Math.round(32 * launcherWindow.uiScale)
        color: Color.background
        clip: true

        scale: LauncherService.isOpen ? 1.0 : 0.92
        opacity: LauncherService.isOpen ? 1.0 : 0.0

        Behavior on scale {
          NumberAnimation {
            duration: 280
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        // Prevent clicks inside card from dismissing scrim
        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: launcherCard.cardPadding
          spacing: Math.round(16 * launcherWindow.uiScale)

          // Expressive Full-Pill Search Bar
          Rectangle {
            id: searchPill
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(58 * launcherWindow.uiScale)
            radius: height / 2
            color: Color.surface

            Behavior on border.color {
              ColorAnimation {
                duration: 160
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Math.round(20 * launcherWindow.uiScale)
              anchors.rightMargin: Math.round(14 * launcherWindow.uiScale)
              spacing: Math.round(12 * launcherWindow.uiScale)

              Text {
                text: "search"
                font.family: Config.iconFont
                font.pixelSize: Math.round(24 * launcherWindow.uiScale)
                color: searchInput.activeFocus ? Color.primary : Color.muted
              }

              TextInput {
                id: searchInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                font.family: Config.textFont
                font.pixelSize: Math.max(14, Math.round(17 * launcherWindow.uiScale))
                font.weight: Font.Medium
                color: Color.text
                selectionColor: Color.primary
                selectedTextColor: Color.background
                clip: true

                text: LauncherService.searchQuery
                onTextEdited: LauncherService.searchQuery = text

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  text: "Search applications…"
                  font: searchInput.font
                  color: Color.muted
                  visible: searchInput.text.length === 0
                }

                Keys.onDownPressed: {
                  LauncherService.moveSelectionDown();
                  appList.positionViewAtIndex(LauncherService.selectedIndex, ListView.Contain);
                }
                Keys.onUpPressed: {
                  LauncherService.moveSelectionUp();
                  appList.positionViewAtIndex(LauncherService.selectedIndex, ListView.Contain);
                }
                Keys.onReturnPressed: LauncherService.launchSelected()
                Keys.onEnterPressed: LauncherService.launchSelected()
                Keys.onEscapePressed: LauncherService.close()
              }

              // Result Count Pill
              Rectangle {
                visible: LauncherService.filteredApps.length > 0
                Layout.preferredHeight: Math.round(28 * launcherWindow.uiScale)
                Layout.preferredWidth: countLabel.implicitWidth + Math.round(18 * launcherWindow.uiScale)
                radius: height / 2
                color: Color.overlay

                Text {
                  id: countLabel
                  anchors.centerIn: parent
                  text: LauncherService.filteredApps.length
                  font.family: Config.textFont
                  font.pixelSize: Math.max(11, Math.round(12 * launcherWindow.uiScale))
                  font.weight: Font.Bold
                  color: Color.secondary
                }
              }

              // Clear Search Button
              Rectangle {
                visible: searchInput.text.length > 0
                Layout.preferredWidth: Math.round(32 * launcherWindow.uiScale)
                Layout.preferredHeight: Math.round(32 * launcherWindow.uiScale)
                radius: height / 2
                color: clearMouse.containsMouse ? Color.overlay : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "close"
                  font.family: Config.iconFont
                  font.pixelSize: Math.round(18 * launcherWindow.uiScale)
                  color: Color.muted
                }

                MouseArea {
                  id: clearMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    LauncherService.searchQuery = "";
                    searchInput.forceActiveFocus();
                  }
                }
              }
            }
          }

          // Filtered Application List
          ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Math.round(6 * launcherWindow.uiScale)
            boundsBehavior: Flickable.StopAtBounds
            model: LauncherService.filteredApps

            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
              width: 4
            }

            delegate: Rectangle {
              id: appDelegate
              required property var modelData
              required property int index

              readonly property bool isSelected: index === LauncherService.selectedIndex
              readonly property bool isHovered: itemMouse.containsMouse

              width: appList.width
              height: Math.round(64 * launcherWindow.uiScale)
              radius: Math.round((isSelected ? 24 : 16) * launcherWindow.uiScale)
              color: isSelected ? Color.overlay : (isHovered ? Color.surface : "transparent")

              Behavior on radius {
                NumberAnimation {
                  duration: 180
                  easing.type: Easing.OutCubic
                }
              }

              Behavior on color {
                ColorAnimation {
                  duration: 140
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(12 * launcherWindow.uiScale)
                anchors.rightMargin: Math.round(16 * launcherWindow.uiScale)
                spacing: Math.round(14 * launcherWindow.uiScale)

                // Expressive Squircle Icon Container
                Rectangle {
                  Layout.preferredWidth: Math.round(44 * launcherWindow.uiScale)
                  Layout.preferredHeight: Math.round(44 * launcherWindow.uiScale)
                  radius: Math.round((isSelected ? 16 : 12) * launcherWindow.uiScale)
                  color: Color.surface

                  Behavior on radius {
                    NumberAnimation {
                      duration: 180
                      easing.type: Easing.OutCubic
                    }
                  }

                  Image {
                    anchors.centerIn: parent
                    width: Math.round(26 * launcherWindow.uiScale)
                    height: Math.round(26 * launcherWindow.uiScale)
                    source: modelData.icon ? ("image://icon/" + modelData.icon) : ""
                    sourceSize: Qt.size(32, 32)
                    smooth: true
                    visible: status === Image.Ready
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: !modelData.icon
                    text: "apps"
                    font.family: Config.iconFont
                    font.pixelSize: Math.round(22 * launcherWindow.uiScale)
                    color: isSelected ? Color.background : Color.muted
                  }
                }

                // Application Name & Description
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  Text {
                    Layout.fillWidth: true
                    text: modelData.name || "Unknown"
                    elide: Text.ElideRight
                    font.family: Config.textFont
                    font.pixelSize: Math.max(14, Math.round(16 * launcherWindow.uiScale))
                    font.weight: isSelected ? Font.Bold : Font.Medium
                    color: isSelected ? Color.primary : Color.text
                  }

                  Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: modelData.comment || modelData.genericName || ""
                    elide: Text.ElideRight
                    font.family: Config.textFont
                    font.pixelSize: Math.max(11, Math.round(12 * launcherWindow.uiScale))
                    color: Color.muted
                  }
                }

                // Active Item Launch Pill
                Rectangle {
                  visible: isSelected
                  Layout.preferredHeight: Math.round(28 * launcherWindow.uiScale)
                  Layout.preferredWidth: launchRow.implicitWidth + Math.round(18 * launcherWindow.uiScale)
                  radius: height / 2
                  color: Color.primary

                  RowLayout {
                    id: launchRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                      text: "Open"
                      font.family: Config.textFont
                      font.pixelSize: Math.max(10, Math.round(11 * launcherWindow.uiScale))
                      font.weight: Font.Bold
                      color: Color.background
                    }

                    Text {
                      text: "keyboard_return"
                      font.family: Config.iconFont
                      font.pixelSize: Math.round(14 * launcherWindow.uiScale)
                      color: Color.background
                    }
                  }
                }
              }

              MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: LauncherService.updateMouseSelection(index, itemMouse.mapToItem(appList, itemMouse.mouseX, itemMouse.mouseY))
                onPositionChanged: LauncherService.updateMouseSelection(index, itemMouse.mapToItem(appList, itemMouse.mouseX, itemMouse.mouseY))
                onClicked: LauncherService.launchApp(modelData)
              }
            }

            // Empty State
            ColumnLayout {
              anchors.centerIn: parent
              spacing: Math.round(8 * launcherWindow.uiScale)
              visible: appList.count === 0

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "search_off"
                font.family: Config.iconFont
                font.pixelSize: Math.round(36 * launcherWindow.uiScale)
                color: Color.muted
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No matching applications"
                font.family: Config.textFont
                font.pixelSize: Math.max(14, Math.round(16 * launcherWindow.uiScale))
                font.weight: Font.Bold
                color: Color.text
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Try searching with a different keyword"
                font.family: Config.textFont
                font.pixelSize: Math.max(12, Math.round(13 * launcherWindow.uiScale))
                color: Color.muted
              }
            }
          }
        }
      }

      Connections {
        target: LauncherService
        function onIsOpenChanged(): void {
          if (LauncherService.isOpen && launcherWindow.isPrimaryScreen) {
            Qt.callLater(() => searchInput.forceActiveFocus());
          }
        }
      }
    }
  }
}
