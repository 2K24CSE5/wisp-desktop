pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string cacheDir: homeDir + "/.cache/wisp-desktop"
  readonly property string niriDir: homeDir + "/.config/niri"

  readonly property string settingsFile: cacheDir + "/settings.json"
  readonly property string colorsFile: cacheDir + "/colors.json"
  readonly property string niriConfigFile: niriDir + "/config.kdl"
  readonly property string wispNiriFile: niriDir + "/wisp-desktop.kdl"

  property bool ready: false

  Process {
    command: ["mkdir", "-p", root.cacheDir, root.niriDir]
    running: true
    onExited: root.ready = true
  }

  function expand(rawPath: string): string {
    if (!rawPath)
      return "";
    let p = rawPath.trim();
    if (p.startsWith("file://"))
      p = p.slice(7);
    return p.startsWith("~/") ? root.homeDir + p.slice(1) : p;
  }

  function toFileUrl(rawPath: string): string {
    const p = expand(rawPath);
    return p && p.startsWith("/") ? "file://" + p : p;
  }
}
