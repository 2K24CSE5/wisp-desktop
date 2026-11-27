import Quickshell
import qs.configs
import qs.services
import qs.modules.wallpaper
import qs.modules.launcher
import qs.modules.bar
import qs.modules.polkit
import qs.modules.notification

ShellRoot {
  readonly property var _niri: Niri
  readonly property var _settings: SettingsService

  Wallpaper {}
  Launcher {}
  Bar {}
  Polkit {}
  Notification {}
}
