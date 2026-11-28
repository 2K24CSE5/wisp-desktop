import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.configs
import qs.services

Scope {
  id: root

  Modal {
    id: modal
    open: SettingService.uiOpen
    namespace: "wisp-setting"
    cardWidth: 760
    cardHeight: 600
    cardRadius: 28
    cardPadding: 16
    onDismissed: SettingService.closeUi()

    RowLayout {
      id: layout
      property real uiScale: 1.0
      anchors.fill: parent
      spacing: Math.round(16 * uiScale)

      // --- Sidebar ---
      Rectangle {
        Layout.preferredWidth: Math.round(200 * layout.uiScale)
        Layout.fillHeight: true
        radius: Math.round(20 * layout.uiScale)
        color: Color.surface

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Math.round(12 * layout.uiScale)
          spacing: Math.round(6 * layout.uiScale)

          Text {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(8 * layout.uiScale)
            Layout.bottomMargin: Math.round(6 * layout.uiScale)
            text: "Settings"
            font.family: Config.textFont
            font.pixelSize: Math.round(16 * layout.uiScale)
            font.weight: Font.DemiBold
            color: Color.text
          }

          Repeater {
            model: SettingService.sections

            delegate: Rectangle {
              required property var modelData
              required property int index
              readonly property bool selected: SettingService.activeTab === index

              Layout.fillWidth: true
              Layout.preferredHeight: Math.round(38 * layout.uiScale)
              radius: height / 2
              color: selected ? Color.primary : (navMouse.containsMouse ? Color.overlay : "transparent")

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(12 * layout.uiScale)
                anchors.rightMargin: Math.round(12 * layout.uiScale)
                spacing: Math.round(10 * layout.uiScale)

                Text {
                  text: modelData.icon
                  font.family: Config.iconFont
                  font.pixelSize: Math.round(18 * layout.uiScale)
                  color: selected ? Color.background : Color.primary
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.label
                  font.family: Config.textFont
                  font.pixelSize: Math.round(13 * layout.uiScale)
                  font.weight: selected ? Font.DemiBold : Font.Medium
                  color: selected ? Color.background : Color.text
                }
              }

              MouseArea {
                id: navMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingService.selectTab(index)
              }
            }
          }

          Item {
            Layout.fillHeight: true
          }
        }
      }

      // --- Main Content ---
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Math.round(20 * layout.uiScale)
        color: Color.background

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Math.round(16 * layout.uiScale)
          spacing: Math.round(12 * layout.uiScale)

          // Header Bar
          RowLayout {
            Layout.fillWidth: true

            Text {
              Layout.fillWidth: true
              text: SettingService.sections[SettingService.activeTab].label
              font.family: Config.textFont
              font.pixelSize: Math.round(18 * layout.uiScale)
              font.weight: Font.DemiBold
              color: Color.text
            }

            Rectangle {
              Layout.preferredWidth: Math.round(34 * layout.uiScale)
              Layout.preferredHeight: Math.round(34 * layout.uiScale)
              radius: width / 2
              color: closeMouse.containsMouse ? Color.overlay : "transparent"

              Text {
                anchors.centerIn: parent
                text: "close"
                font.family: Config.iconFont
                font.pixelSize: Math.round(18 * layout.uiScale)
                color: Color.muted
              }

              MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingService.closeUi()
              }
            }
          }

          // Blank Main Content Area
          Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
          }
        }
      }
    }
  }
}
