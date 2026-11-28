import QtQuick
import QtQuick.Layouts
import qs.configs
import qs.services
import qs.components

WidgetPill {
  id: root

  inner: true
  contentImplicitWidth: quickRow.implicitWidth

  RowLayout {
    id: quickRow
    anchors.centerIn: parent
    spacing: Math.round(8 * root.uiScale)

    Text {
      text: NetworkService.connected ? "wifi" : "wifi_off"
      font.family: Config.iconFont
      font.pixelSize: Math.round(16 * root.uiScale)
      color: NetworkService.connected ? Color.primary : Color.error
    }

    Text {
      text: {
        if (BluetoothService.connected)
          return "bluetooth_connected";
        if (BluetoothService.enabled)
          return "bluetooth";
        return "bluetooth_disabled";
      }
      font.family: Config.iconFont
      font.pixelSize: Math.round(16 * root.uiScale)
      color: {
        if (!BluetoothService.enabled)
          return Color.muted;
        return BluetoothService.connected ? Color.primary : Color.text;
      }
    }
  }
}
