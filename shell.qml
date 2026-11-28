import Quickshell
import qs.configs
import qs.services
import qs.modules.wallpaper
import qs.modules.launcher
import qs.modules.widget
import qs.modules.polkit
import qs.modules.setting

ShellRoot {
  readonly property var _niri: Niri
  readonly property var _settings: SettingsService

  Wallpaper {}
  Launcher {}
  Widget {}
  Polkit {}
  Setting {}
}
