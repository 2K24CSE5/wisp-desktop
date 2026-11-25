import Quickshell
import qs.configs
import qs.services
import qs.modules.wallpaper

ShellRoot {
  readonly property var _niri: Niri
  readonly property var _settings: SettingsService

  Wallpaper {}
}
