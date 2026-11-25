pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool isOpen: false
  property string searchText: ""
  property int selectedIndex: 0

  readonly property var applications: {
    const query = searchText.trim().toLowerCase();
    return [...DesktopEntries.applications.values]
      .filter(entry => {
        if (!query)
          return true;
        const searchable = [
          entry.name,
          entry.genericName,
          entry.comment,
          ...entry.keywords,
          ...entry.categories
        ].join(" ").toLowerCase();
        return searchable.includes(query);
      })
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  function setSearchText(value: string): void {
    if (searchText === value)
      return;
    searchText = value;
    selectedIndex = applications.length > 0 ? 0 : -1;
  }

  function open(): void {
    searchText = "";
    selectedIndex = applications.length > 0 ? 0 : -1;
    isOpen = true;
  }

  function close(): void {
    isOpen = false;
    searchText = "";
    selectedIndex = 0;
  }

  function toggle(): void {
    if (isOpen)
      close();
    else
      open();
  }

  function selectNext(): void {
    if (applications.length === 0)
      return;
    selectedIndex = Math.min(selectedIndex + 1, applications.length - 1);
  }

  function selectPrevious(): void {
    if (applications.length === 0)
      return;
    selectedIndex = Math.max(selectedIndex - 1, 0);
  }

  function launch(entry): void {
    if (!entry)
      return;
    entry.execute();
    close();
  }

  function launchSelected(): void {
    if (selectedIndex >= 0 && selectedIndex < applications.length) {
      launch(applications[selectedIndex]);
    }
  }

  IpcHandler {
    target: "launcher"

    function open(): void {
      root.open();
    }

    function toggle(): void {
      root.toggle();
    }

    function close(): void {
      root.close();
    }
  }
}