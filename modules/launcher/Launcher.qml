import QtQuick
import QtQuick.Layouts
import qs.configs
import qs.services
import qs.components

Modal {
  id: root

  open: LauncherService.isOpen
  namespace: "wisp-launcher"
  scrimOpacity: 0.45
  cardWidth: 620
  cardHeight: 560
  cardPadding: 24

  onDismissed: LauncherService.close()
  onOpenedOnPrimary: item => Qt.callLater(() => item.focusSearch())

  ColumnLayout {
    id: launcherContent
    property real uiScale: 1.0
    spacing: Math.round(16 * uiScale)

    function focusSearch(): void {
      searchInput.forceActiveFocus();
    }

    Connections {
      target: LauncherService
      function onScrollToSelected(index: int): void {
        appList.positionViewAtIndex(index, ListView.Contain);
      }
    }

    // Expressive Full-Pill Search Bar
    Rectangle {
      id: searchPill
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(58 * launcherContent.uiScale)
      radius: height / 2
      color: Color.surface

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(20 * launcherContent.uiScale)
        anchors.rightMargin: Math.round(14 * launcherContent.uiScale)
        spacing: Math.round(12 * launcherContent.uiScale)

        Text {
          text: "search"
          font.family: Config.iconFont
          font.pixelSize: Math.round(24 * launcherContent.uiScale)
          color: searchInput.activeFocus ? Color.primary : Color.muted
        }

        TextInput {
          id: searchInput
          Layout.fillWidth: true
          Layout.fillHeight: true
          verticalAlignment: TextInput.AlignVCenter
          font.family: Config.textFont
          font.pixelSize: Math.max(14, Math.round(17 * launcherContent.uiScale))
          font.weight: Font.Medium
          color: Color.text
          selectionColor: Color.primary
          selectedTextColor: Color.background
          clip: true

          text: LauncherService.searchQuery
          onTextEdited: LauncherService.updateSearch(text)
          Keys.onPressed: event => LauncherService.handleKeyEvent(event)

          Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: "Search applications…"
            font: searchInput.font
            color: Color.muted
            visible: !LauncherService.hasQuery
          }
        }

        // Result Count Pill
        Rectangle {
          visible: LauncherService.hasResults
          Layout.preferredHeight: Math.round(28 * launcherContent.uiScale)
          Layout.preferredWidth: countLabel.implicitWidth + Math.round(18 * launcherContent.uiScale)
          radius: height / 2
          color: Color.overlay

          Text {
            id: countLabel
            anchors.centerIn: parent
            text: LauncherService.resultCount
            font.family: Config.textFont
            font.pixelSize: Math.max(11, Math.round(12 * launcherContent.uiScale))
            font.weight: Font.Bold
            color: Color.secondary
          }
        }

        // Clear Search Button
        Rectangle {
          visible: LauncherService.hasQuery
          Layout.preferredWidth: Math.round(32 * launcherContent.uiScale)
          Layout.preferredHeight: Math.round(32 * launcherContent.uiScale)
          radius: height / 2
          color: clearMouse.containsMouse ? Color.overlay : "transparent"

          Text {
            anchors.centerIn: parent
            text: "close"
            font.family: Config.iconFont
            font.pixelSize: Math.round(18 * launcherContent.uiScale)
            color: Color.muted
          }

          MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              LauncherService.clearSearch();
              launcherContent.focusSearch();
            }
          }
        }
      }
    }

    // Reusable Momentum ListView
    ListView {
      id: appList
      Layout.fillWidth: true
      Layout.fillHeight: true
      uiScale: launcherContent.uiScale
      rowHeight: 64
      spacing: Math.round(6 * launcherContent.uiScale)
      model: LauncherService.filteredApps

      delegate: Rectangle {
        id: appDelegate
        required property var modelData
        required property int index

        readonly property bool isSelected: index === LauncherService.selectedIndex
        readonly property bool isHovered: itemMouse.containsMouse

        width: appList.width
        height: Math.round(64 * launcherContent.uiScale)
        radius: Math.round((isSelected ? 24 : 16) * launcherContent.uiScale)
        color: isSelected ? Color.surface : (isHovered ? Color.surface : "transparent")

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
          anchors.leftMargin: Math.round(12 * launcherContent.uiScale)
          anchors.rightMargin: Math.round(14 * launcherContent.uiScale)
          spacing: Math.round(14 * launcherContent.uiScale)

          // Expressive Squircle Icon Container
          Rectangle {
            Layout.preferredWidth: Math.round(44 * launcherContent.uiScale)
            Layout.preferredHeight: Math.round(44 * launcherContent.uiScale)
            radius: Math.round((isSelected ? 16 : 12) * launcherContent.uiScale)
            color: isSelected ? Color.overlay : Color.surface

            Behavior on radius {
              NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
              }
            }

            Image {
              anchors.centerIn: parent
              width: Math.round(26 * launcherContent.uiScale)
              height: Math.round(26 * launcherContent.uiScale)
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
              font.pixelSize: Math.round(22 * launcherContent.uiScale)
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
              font.pixelSize: Math.max(14, Math.round(16 * launcherContent.uiScale))
              font.weight: Font.Medium
              color: isSelected ? Color.primary : Color.text
            }

            Text {
              Layout.fillWidth: true
              visible: text.length > 0
              text: modelData.comment || modelData.genericName || ""
              elide: Text.ElideRight
              font.family: Config.textFont
              font.pixelSize: Math.max(11, Math.round(12 * launcherContent.uiScale))
              color: Color.muted
            }
          }

          // Circular Arrow Launch Button
          Rectangle {
            visible: isSelected
            Layout.preferredWidth: Math.round(34 * launcherContent.uiScale)
            Layout.preferredHeight: Math.round(34 * launcherContent.uiScale)
            radius: width / 2
            color: Color.primary

            Text {
              anchors.centerIn: parent
              text: "arrow_forward"
              font.family: Config.iconFont
              font.pixelSize: Math.round(18 * launcherContent.uiScale)
              color: Color.background
            }
          }
        }

        MouseArea {
          id: itemMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: LauncherService.handleItemPointer(index, itemMouse, appList)
          onPositionChanged: LauncherService.handleItemPointer(index, itemMouse, appList)
          onClicked: LauncherService.launchApp(modelData)
        }
      }

      // Empty State
      ColumnLayout {
        anchors.centerIn: parent
        spacing: Math.round(8 * launcherContent.uiScale)
        visible: !LauncherService.hasResults

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "search_off"
          font.family: Config.iconFont
          font.pixelSize: Math.round(36 * launcherContent.uiScale)
          color: Color.muted
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "No matching applications"
          font.family: Config.textFont
          font.pixelSize: Math.max(14, Math.round(16 * launcherContent.uiScale))
          font.weight: Font.Bold
          color: Color.text
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "Try searching with a different keyword"
          font.family: Config.textFont
          font.pixelSize: Math.max(12, Math.round(13 * launcherContent.uiScale))
          color: Color.muted
        }
      }
    }
  }
}
