pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.configs

Singleton {
  id: root

  property string queuedPath: ""
  property string stdoutBuf: ""
  property string stderrBuf: ""

  function generateColors(imagePath: string): void {
    const cleanPath = Directory.expand(imagePath);
    if (!cleanPath || !Directory.ready)
      return;

    if (matugenProcess.running) {
      queuedPath = cleanPath;
      return;
    }

    stdoutBuf = "";
    stderrBuf = "";
    matugenProcess.command = ["matugen", "image", cleanPath, "--config", Directory.homeDir + "/.config/quickshell/wisp-desktop/matugen/config.toml", "--source-color-index", "0", "--json", "hex"];
    matugenProcess.running = true;
  }

  function pick(colors: var, token: string, mode: string, fallback: string): string {
    const entry = colors?.[token];
    if (!entry)
      return fallback;
    return typeof entry === "string" ? entry : (entry[mode]?.color ?? entry.default?.color ?? fallback);
  }

  function mapPalette(colors: var, mode: string, fb: var): var {
    return {
      background: pick(colors, "background", mode, pick(colors, "surface", mode, fb.background)),
      surface: pick(colors, "surface_container", mode, pick(colors, "surface", mode, fb.surface)),
      overlay: pick(colors, "surface_container_high", mode, pick(colors, "surface_variant", mode, fb.overlay)),
      muted: pick(colors, "outline", mode, pick(colors, "on_surface_variant", mode, fb.muted)),
      subtle: pick(colors, "outline_variant", mode, fb.subtle),
      text: pick(colors, "on_surface", mode, pick(colors, "on_background", mode, fb.text)),
      primary: pick(colors, "primary", mode, fb.primary),
      secondary: pick(colors, "secondary", mode, fb.secondary),
      tertiary: pick(colors, "tertiary", mode, fb.tertiary),
      warning: pick(colors, "tertiary", mode, fb.warning),
      info: pick(colors, "secondary", mode, fb.info),
      error: pick(colors, "error", mode, fb.error)
    };
  }

  function applyJson(raw: string): void {
    try {
      const jsonStart = raw.indexOf("{");
      const jsonEnd = raw.lastIndexOf("}");
      if (jsonStart === -1 || jsonEnd < jsonStart) {
        console.warn("MatugenService: no JSON object found in Matugen output");
        return;
      }

      const parsed = JSON.parse(raw.slice(jsonStart, jsonEnd + 1));
      const colors = parsed.colors ?? parsed;
      const palettes = {
        dark: mapPalette(colors, "dark", Color.darkPalette),
        light: mapPalette(colors, "light", Color.lightPalette)
      };
      const newJson = JSON.stringify(palettes, null, 2);

      if (newJson !== colorsWriter.text())
        colorsWriter.setText(newJson);
    } catch (e) {
      console.warn("MatugenService: JSON parse error:", e);
    }
  }

  FileView {
    id: colorsWriter
    path: Directory.ready ? Directory.colorsFile : ""
    printErrors: false
  }

  Process {
    id: matugenProcess

    stdout: SplitParser {
      splitMarker: ""
      onRead: data => root.stdoutBuf += data
    }

    stderr: SplitParser {
      splitMarker: ""
      onRead: data => root.stderrBuf += data
    }

    onExited: exitCode => {
      if (exitCode === 0 && root.stdoutBuf.trim() !== "") {
        root.applyJson(root.stdoutBuf);
      } else {
        console.warn("MatugenService: exited with code", exitCode, root.stderrBuf.trim());
      }
      root.stdoutBuf = "";
      root.stderrBuf = "";

      if (root.queuedPath !== "") {
        const next = root.queuedPath;
        root.queuedPath = "";
        root.generateColors(next);
      }
    }
  }
}
