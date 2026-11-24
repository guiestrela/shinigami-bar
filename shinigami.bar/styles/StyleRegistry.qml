import QtQml

QtObject {
  id: root

  property string requestedId: "shinigami"
  readonly property var availableIds: ["shinigami"]
  readonly property string resolvedId: hasStyle(requestedId)
    ? normalizeId(requestedId)
    : "shinigami"
  readonly property url source: sourceFor(resolvedId)
  readonly property bool fallbackUsed: normalizeId(requestedId) !== resolvedId

  function normalizeId(value) {
    return String(value || "").trim().toLowerCase()
  }

  function hasStyle(value) {
    return availableIds.indexOf(normalizeId(value)) !== -1
  }

  function displayName(value) {
    switch (normalizeId(value)) {
    case "shinigami": return "Shinigami"
    default: return ""
    }
  }

  function sourceFor(value) {
    switch (normalizeId(value)) {
    case "shinigami": return Qt.resolvedUrl("shinigami/Style.qml")
    default: return ""
    }
  }
}
