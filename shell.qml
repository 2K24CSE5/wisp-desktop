import Quickshell
import qs.configs
import qs.services
import qs.modules.wallpaper
import qs.modules.launcher

ShellRoot {
  readonly property var _niri: Niri
  readonly property var _settings: SettingsService

  Wallpaper {}
  Launcher {}
}
