pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.configs
import qs.services

Singleton {
  id: root

  readonly property string currentWallpaper: Paths.toFileUrl(Config.wallpaper)
  property string queuedPath: ""

  function applyWallpaper(destPath: string): void {
    if (Config.wallpaper !== destPath) {
      Config.saveSettings(Object.assign({}, Config.settings, {
        wallpaper: destPath
      }));
    }
    MatugenService.generateColors(destPath);
  }

  Process {
    id: copyProcess
    property string destPath: ""

    onExited: exitCode => {
      if (exitCode === 0 && destPath !== "") {
        root.applyWallpaper(destPath);
      } else {
        console.warn("WallpaperService: failed to copy wallpaper:", destPath);
      }
      destPath = "";

      if (root.queuedPath !== "") {
        const next = root.queuedPath;
        root.queuedPath = "";
        root.setWallpaper(next);
      }
    }
  }

  function setWallpaper(path: string): void {
    const sourcePath = Paths.expand(path);
    if (!sourcePath || !Paths.ready)
      return;

    if (copyProcess.running) {
      queuedPath = sourcePath;
      return;
    }

    if (sourcePath === Config.wallpaper) {
      applyWallpaper(sourcePath);
      return;
    }

    const fileName = sourcePath.split("/").pop();
    const dotIndex = fileName.lastIndexOf(".");
    const ext = dotIndex !== -1 ? fileName.slice(dotIndex) : "";
    const stamp = Date.now();
    const destPath = `${Paths.cacheDir}/wallpaper-${stamp}${ext}`;
    const tempPath = `${Paths.cacheDir}/.wallpaper.tmp-${stamp}${ext}`;

    copyProcess.destPath = destPath;
    copyProcess.command = ["sh", "-c", 'cp -f "$1" "$2" && mv -f "$2" "$4" && find "$3" -maxdepth 1 -name "wallpaper-*" ! -name "$(basename "$4")" -delete', "_", sourcePath, tempPath, Paths.cacheDir, destPath];
    copyProcess.running = true;
  }
}
