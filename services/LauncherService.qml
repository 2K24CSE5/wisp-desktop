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

  readonly property int resultCount: filteredApps.length
  readonly property bool hasQuery: searchQuery.length > 0
  readonly property bool hasResults: filteredApps.length > 0

  signal scrollToSelected(int index)

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
      root.updateSearch(query);
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
  function open(): void {
    refreshApps();
    searchQuery = "";
    selectedIndex = 0;
    lastPointerPosition = Qt.point(-1, -1);
    filterApps();
    isOpen = true;
    scrollToSelected(0);
  }

  function close(): void {
    isOpen = false;
    searchQuery = "";
    selectedIndex = 0;
  }

  function toggle(): void {
    if (isOpen)
      close();
    else
      open();
  }

  // --- Search & Query State ---
  function updateSearch(query: string): void {
    if (searchQuery !== query) {
      searchQuery = query;
    }
  }

  function clearSearch(): void {
    searchQuery = "";
    selectedIndex = 0;
    scrollToSelected(0);
  }

  // --- Application Indexing & Filtering ---
  function refreshApps(): void {
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
    scrollToSelected(0);
  }

  function filterApps(): void {
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

  // --- Input & Navigation ---
  function handleKeyEvent(event): void {
    switch (event.key) {
    case Qt.Key_Down:
      moveSelectionDown();
      event.accepted = true;
      break;
    case Qt.Key_Up:
      moveSelectionUp();
      event.accepted = true;
      break;
    case Qt.Key_Return:
    case Qt.Key_Enter:
      launchSelected();
      event.accepted = true;
      break;
    case Qt.Key_Escape:
      close();
      event.accepted = true;
      break;
    }
  }

  function moveSelectionDown(): void {
    if (filteredApps.length === 0)
      return;
    selectedIndex = (selectedIndex + 1) % filteredApps.length;
    scrollToSelected(selectedIndex);
  }

  function moveSelectionUp(): void {
    if (filteredApps.length === 0)
      return;
    selectedIndex = (selectedIndex - 1 + filteredApps.length) % filteredApps.length;
    scrollToSelected(selectedIndex);
  }

  function handleItemPointer(index: int, mouseArea, listItem): void {
    const pos = mouseArea.mapToItem(listItem, mouseArea.mouseX, mouseArea.mouseY);
    const moved = lastPointerPosition.x >= 0 && (pos.x !== lastPointerPosition.x || pos.y !== lastPointerPosition.y);
    lastPointerPosition = Qt.point(pos.x, pos.y);
    if (moved)
      selectedIndex = index;
  }

  // --- Execution ---
  function launchSelected(): void {
    if (filteredApps.length === 0 || selectedIndex < 0 || selectedIndex >= filteredApps.length) {
      return;
    }
    launchApp(filteredApps[selectedIndex]);
  }

  function launchApp(app): void {
    if (!app)
      return;
    app.execute();
    close();
  }
}
