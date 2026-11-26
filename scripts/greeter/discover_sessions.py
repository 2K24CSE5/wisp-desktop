import configparser
import json
import os
import shlex
import shutil


search_dirs = []
for base in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
    if base:
        search_dirs.extend([os.path.join(base, "wayland-sessions"), os.path.join(base, "xsessions")])
home = os.path.expanduser("~/.local/share")
search_dirs.extend([os.path.join(home, "wayland-sessions"), os.path.join(home, "xsessions")])
sessions = []
seen = set()
for directory in search_dirs:
    try:
        if not os.path.isdir(directory):
            continue
        filenames = sorted(os.listdir(directory))
    except (PermissionError, OSError):
        continue
    for filename in filenames:
        if not filename.endswith(".desktop"):
            continue
        path = os.path.join(directory, filename)
        if path in seen:
            continue
        seen.add(path)
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        try:
            with open(path, encoding="utf-8") as session_file:
                parser.read_file(session_file)
            entry = parser["Desktop Entry"]
            if entry.get("Type", "Application") != "Application" or entry.get("Hidden", "false").lower() == "true" or entry.get("NoDisplay", "false").lower() == "true":
                continue
            command = shlex.split(entry.get("Exec", ""))
            command = [part for part in command if not part.startswith("%")]
            if not command or not shutil.which(command[0]):
                continue
            sessions.append({"name": entry.get("Name", os.path.splitext(filename)[0]), "command": command})
        except (KeyError, OSError, ValueError):
            continue
sessions.sort(key=lambda session: session["name"].lower())
print(json.dumps(sessions))
