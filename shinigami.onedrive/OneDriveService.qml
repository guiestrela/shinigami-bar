pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "integration" as OneDrive
import "integration/Model.js" as Model

// Shinigami-owned adapter around the Rise OmaOneDrive coordinator. It deliberately
// exposes no IPC handler: the standalone plugin Service owns that single target.
OneDrive.Service {
  id: service

  required property var owner
  onExternalActionRequested: if (owner && typeof owner.close === "function") owner.close()

  property var preferencesData: ({
    refreshIntervalSec: 30,
    recentFileLimit: 20,
    panelStyle: "Full",
    notifications: true
  })
  settings: preferencesData

  function updateSetting(name, value) {
    const next = Object.assign({}, preferencesData)
    next[name] = value
    preferencesData = next
    preferences.setText(JSON.stringify(next))
  }

  FileView {
    id: preferences
    path: Quickshell.env("HOME") + "/.cache/shinigami-onedrive.json"
    blockWrites: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        const data = JSON.parse(text())
        if (data && typeof data === "object" && !Array.isArray(data))
          service.preferencesData = Object.assign({}, service.preferencesData, data)
      } catch (error) { /* Invalid preferences retain defaults. */ }
    }
  }
}
