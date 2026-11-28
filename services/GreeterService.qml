pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.configs

Singleton {
  id: service

  property string currentTime: ""
  property string currentDate: ""
  property string statusMessage: ""
  property bool isAuthenticating: false
  property var availableSessions: []
  property var availableUsers: []
  property bool isLoadingSessions: true
  property bool isLoadingUsers: true
  property int selectedSessionIndex: 0
  property int selectedUserIndex: -1

  readonly property var selectedSession: availableSessions[Math.max(0, Math.min(selectedSessionIndex, availableSessions.length - 1))]
  readonly property var selectedUser: selectedUserIndex >= 0 ? availableUsers[selectedUserIndex] : null
  readonly property string lastLoggedInName: {
    const user = availableUsers.find(entry => entry.username === Config.targetUser);
    return user ? user.name : Config.targetUser;
  }
  readonly property string greetdSocket: Quickshell.env("GREETD_SOCK") || "/run/greetd.sock"
  readonly property bool isLiveGreetd: Quickshell.env("GREETD_SOCK") !== undefined

  signal loginFailed

  function selectInitialUser(): void {
    if (availableUsers.length === 0)
      return;

    const index = availableUsers.findIndex(user => user.username === Config.targetUser);
    selectedUserIndex = index >= 0 ? index : 0;
  }

  function selectUser(username: string): void {
    const index = availableUsers.findIndex(user => user.username === username);
    if (index >= 0)
      selectedUserIndex = index;
  }

  Process {
    id: userDiscoveryProc
    property string stdoutBuffer: ""
    property string stderrBuffer: ""

    stdout: SplitParser {
      onRead: data => userDiscoveryProc.stdoutBuffer += data
    }

    stderr: SplitParser {
      onRead: data => userDiscoveryProc.stderrBuffer += data
    }

    onExited: code => {
      service.isLoadingUsers = false;
      if (code !== 0) {
        console.warn("GreeterService: user discovery failed:", stderrBuffer.trim());
        service.statusMessage = "Could not load user accounts";
        return;
      }

      try {
        service.availableUsers = JSON.parse(stdoutBuffer);
        service.selectInitialUser();
        if (service.availableUsers.length === 0)
          service.statusMessage = "No user accounts found";
      } catch (error) {
        console.warn("GreeterService: could not parse user accounts:", error);
        service.statusMessage = "Could not read user accounts";
      }
    }

    Component.onCompleted: {
      command = ["python3", Directory.greetdUserDiscovery];
      running = true;
    }
  }

  Process {
    id: sessionDiscoveryProc
    stdout: SplitParser {
      onRead: data => {
        try {
          service.availableSessions = JSON.parse(data);
          const savedIndex = service.availableSessions.findIndex(s => s.name === Config.selectedSession);
          service.selectedSessionIndex = savedIndex >= 0 ? savedIndex : 0;
        } catch (error) {
          service.availableSessions = [];
          service.statusMessage = "Could not read available sessions";
        }
      }
    }
    onExited: code => {
      service.isLoadingSessions = false;
      if (code !== 0)
        service.availableSessions = [];
    }
    Component.onCompleted: {
      command = ["python3", Directory.greetdSessionDiscovery];
      running = true;
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      const now = new Date();
      service.currentTime = Qt.formatTime(now, "hh:mm");
      service.currentDate = Qt.formatDateTime(now, "dddd, MMMM d");
    }
  }

  Process {
    id: authProc
    stdinEnabled: true
    property string pendingSecret: ""
    property string stdoutBuffer: ""
    property string stderrBuffer: ""
    property string username: ""

    onStarted: {
      const secret = pendingSecret;
      pendingSecret = "";
      write(JSON.stringify(secret) + "\n");
    }

    stdout: SplitParser {
      onRead: data => authProc.stdoutBuffer += data
    }
    stderr: SplitParser {
      onRead: data => authProc.stderrBuffer += data
    }
    onExited: code => {
      service.isAuthenticating = false;
      authProc.pendingSecret = "";
      const output = [authProc.stdoutBuffer, authProc.stderrBuffer].join("\n").trim();
      authProc.stdoutBuffer = "";
      authProc.stderrBuffer = "";

      if (code === 0) {
        Config.saveSettings(Object.assign({}, Config.settings, {
          targetUser: authProc.username
        }));
        service.statusMessage = "Authenticated. Launching session...";
        Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
        Qt.quit();
      } else {
        service.statusMessage = output || "Authentication failed";
        service.loginFailed();
      }
    }
  }

  function login(username: string, secret: string): void {
    if (!username || !secret || isAuthenticating || !selectedSession)
      return;

    if (!isLiveGreetd) {
      service.statusMessage = "greetd is not running; start the greeter through greetd";
      service.loginFailed();
      return;
    }

    if (authProc.running)
      authProc.running = false;

    isAuthenticating = true;
    service.statusMessage = "Authenticating...";
    authProc.username = username;

    authProc.pendingSecret = secret;
    authProc.command = ["python3", Directory.greetdAuthHelper, username, JSON.stringify(selectedSession.command), greetdSocket];
    authProc.running = true;
  }

  function selectSession(index: int): void {
    if (index < 0 || index >= availableSessions.length)
      return;
    selectedSessionIndex = index;
    Config.setSelectedSession(availableSessions[index].name);
  }

  function powerOff(): void {
    Quickshell.execDetached(["systemctl", "poweroff"]);
  }

  function reboot(): void {
    Quickshell.execDetached(["systemctl", "reboot"]);
  }

  function suspend(): void {
    Quickshell.execDetached(["systemctl", "suspend"]);
  }
}
