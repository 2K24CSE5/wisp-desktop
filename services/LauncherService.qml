pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // --- Public Reactive State ---
  property bool isOpen: false
  property string searchQuery: ""
  property int selectedIndex: 0
  property var filteredApps: []
  property var allApps: []
  property point lastPointerPosition: Qt.point(-1, -1)

  // --- IPC Endpoint ---
  IpcHandler {
    target: "launcher"

    function toggle(): void {
      root.toggle();
    }

    function open(): void {
      root.open();
    }

    function close(): void {
      root.close();
    }

    function search(query: string): void {
      if (!root.isOpen) {
        root.open();
      }
      root.searchQuery = query;
    }
  }

  Connections {
    target: DesktopEntries.applications

    function onValuesChanged(): void {
      root.refreshApps();
      root.filterApps();
    }
  }

  // --- Lifecycle ---
  function open() {
    refreshApps();
    searchQuery = "";
    selectedIndex = 0;
    lastPointerPosition = Qt.point(-1, -1);
    filterApps();
    isOpen = true;
  }

  function close() {
    isOpen = false;
    searchQuery = "";
    selectedIndex = 0;
  }

  function toggle() {
    if (isOpen)
      close();
    else
      open();
  }

  // --- Application Indexing & Filtering ---
  function refreshApps() {
    const entries = DesktopEntries.applications.values || [];
    const list = [];
    for (let i = 0; i < entries.length; i++) {
      const app = entries[i];
      if (!app.noDisplay) {
        list.push(app);
      }
    }
    list.sort((a, b) => a.name.localeCompare(b.name));
    allApps = list;
  }

  onSearchQueryChanged: {
    selectedIndex = 0;
    filterApps();
  }

  function filterApps() {
    const q = searchQuery.trim().toLowerCase();
    if (q === "") {
      filteredApps = allApps;
      return;
    }

    const results = [];
    for (let i = 0; i < allApps.length; i++) {
      const app = allApps[i];
      const name = (app.name || "").toLowerCase();
      const generic = (app.genericName || "").toLowerCase();
      const comment = (app.comment || "").toLowerCase();

      let score = 0;
      if (name.startsWith(q))
        score = 3;
      else if (name.includes(q))
        score = 2;
      else if (generic.includes(q) || comment.includes(q))
        score = 1;

      if (score > 0) {
        results.push({
          app: app,
          score: score
        });
      }
    }

    results.sort((a, b) => {
      if (b.score !== a.score)
        return b.score - a.score;
      return a.app.name.localeCompare(b.app.name);
    });

    filteredApps = results.map(item => item.app);
  }

  // --- Keyboard Navigation ---
  function moveSelectionDown() {
    if (filteredApps.length === 0)
      return;
    selectedIndex = (selectedIndex + 1) % filteredApps.length;
  }

  function moveSelectionUp() {
    if (filteredApps.length === 0)
      return;
    selectedIndex = (selectedIndex - 1 + filteredApps.length) % filteredApps.length;
  }

  function updateMouseSelection(index, position) {
    const moved = lastPointerPosition.x >= 0 && (position.x !== lastPointerPosition.x || position.y !== lastPointerPosition.y);
    lastPointerPosition = Qt.point(position.x, position.y);
    if (moved)
      selectedIndex = index;
  }

  // --- Execution ---
  function launchSelected() {
    if (filteredApps.length === 0 || selectedIndex < 0 || selectedIndex >= filteredApps.length) {
      return;
    }
    launchApp(filteredApps[selectedIndex]);
  }

  function launchApp(app) {
    if (!app)
      return;
    app.execute();
    close();
  }
}
