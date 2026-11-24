.pragma library

var GroupIds = [
  "G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8",
  "G9", "G10", "G11", "G12", "G13", "G14", "G15",
  "G16", "G17", "G18"
]

var BaseEntries = {
  G1: ["shinigami.control-center"],
  G2: ["shinigami.workspaces"],
  G3: ["shinigami.status"],
  G4: ["shinigami.memory"],
  G5: ["shinigami.cpu"],
  G6: ["shinigami.audio"],
  G7: ["shinigami.ai"],
  G8: ["shinigami.center"],
  G9: ["shinigami.media"],
  G10: ["shinigami.quick-access"],
  G11: ["shinigami.network"],
  G12: ["shinigami.battery"],
  G13: ["shinigami.display-manager"],
  G14: ["shinigami.power-profile"],
  G15: ["shinigami.bluetooth"],
  G16: ["shinigami.temperature"],
  G17: ["shinigami.gpu"],
  G18: ["shinigami.storage"]
}

var OptionalGroups = {
  "omarchy.dropbox": "G3",
  "omarchy.microphone": "G6",
  "omarchy.active-window": "G8",
  "omarchy.keyboard-layout": "G8",
  "omarchy.tailscale": "G11"
}

// Official Omarchy entries represented by Shinigami composites stay hidden
// unless the user explicitly installs the original as a Shinigami module.
var ConsumedAliases = [
  "omarchy.menu",
  "omarchy.workspaces",
  "omarchy.agents",
  "omarchy.model-usage",
  "omarchy.audio",
  "omarchy.media",
  "omarchy.system-update",
  "omarchy.tray",
  "omarchy.notifications",
  "omarchy.network",
  "omarchy.monitor",
  "omarchy.bluetooth",
  "omarchy.power",
  "omarchy.weather",
  "omarchy.clock",
  "omarchy.indicators"
]
// Native persistence/identity and presentation capacity are distinct contracts.
var NativeSections = ["left", "centerBegin", "center", "centerEnd", "right", "tray"]
var Regions = ["left", "center", "right"]
var DynamicGroupPrefix = "G:"

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function entryId(entry) {
  if (typeof entry === "string") return entry
  return isObject(entry) ? String(entry.id || "") : ""
}

function validPluginId(value) {
  var id = String(value || "")
  return id.length > 0 && id.length <= 160
    && /^[a-z0-9][a-z0-9._-]*$/.test(id)
}

function dynamicGroupIdForModule(moduleValue) {
  var moduleId = String(moduleValue || "")
  return validPluginId(moduleId) ? DynamicGroupPrefix + moduleId : ""
}

function dynamicModuleIdForGroup(groupValue) {
  var groupId = String(groupValue || "")
  if (groupId.indexOf(DynamicGroupPrefix) !== 0) return ""
  var moduleId = groupId.slice(DynamicGroupPrefix.length)
  return validPluginId(moduleId) ? moduleId : ""
}

function copySettings(value) {
  if (!isObject(value)) return {}
  var result = {}
  for (var key in value) {
    if (key !== "id") result[key] = value[key]
  }
  return result
}

function copyGroupModuleSettings(value) {
  var result = copySettings(value)
  // Group activation is owned by GroupSlot and is variant-aware. Forwarding
  // the legacy group-level `enabled` flag to WidgetSlot would disable the
  // inner loader even when enabledV1/enabledV2 activates the group.
  delete result.enabled
  delete result.enabledV1
  delete result.enabledV2
  return result
}

function validNativeLayout(layout) {
  if (!isObject(layout)) return false
  for (var r = 0; r < NativeSections.length; r++) {
    var section = NativeSections[r]
    if (Object.prototype.hasOwnProperty.call(layout, section)
        && !Array.isArray(layout[section])) return false
  }
  return true
}

function configuredEntries(layout) {
  var result = []
  if (!validNativeLayout(layout)) return result
  for (var r = 0; r < NativeSections.length; r++) {
    var section = NativeSections[r]
    var entries = layout[section] || []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      if (id) result.push({ id: id, entry: entries[i], region: section,
        section: section, index: i })
    }
  }
  return result
}

function presentationRegion(section) {
  return section === "centerBegin" || section === "centerEnd" ? "center"
    : Regions.indexOf(section) >= 0 ? section : ""
}

// Projection retains the original entry objects; native coordinates remain
// authoritative and are never serialized into provider-owned settings.
function projectedEntries(layout, region) {
  if (Regions.indexOf(region) < 0) return []
  return configuredEntries(layout).filter(function(row) {
    return presentationRegion(row.section) === region
  })
}

function nativeLocation(layout, entry, moduleId) {
  var rows = configuredEntries(layout)
  var match = null
  var count = 0
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].entry === entry) return rows[i]
    if (rows[i].id === moduleId) { match = rows[i]; count++ }
  }
  // Group-derived entries are copies. Only a unique native provider is safe.
  return count === 1 ? match : null
}

function trayOnly(layout, moduleId) {
  var rows = configuredEntries(layout)
  var found = false
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].id !== moduleId) continue
    if (rows[i].section !== "tray") return false
    found = true
  }
  return found
}

function configuredEntry(layout, moduleId, visibleOnly) {
  var configured = configuredEntries(layout)
  for (var i = 0; i < configured.length; i++) {
    if (configured[i].id === moduleId
        && (visibleOnly !== true || configured[i].section !== "tray")) return configured[i].entry
  }
  return null
}

function groupSettings(groupValue, moduleId, moduleCount) {
  if (!isObject(groupValue)) return {}
  if (moduleId === "shinigami.center")
    return copyGroupModuleSettings(groupValue)
  if (moduleId === "shinigami.audio"
      || moduleId === "shinigami.network") {
    if (isObject(groupValue[moduleId])) return copySettings(groupValue[moduleId])
    return copyGroupModuleSettings(groupValue)
  }
  if (moduleCount === 1) return copyGroupModuleSettings(groupValue)
  return copySettings(groupValue[moduleId])
}

function childSettingsFor(groupValue, layout, moduleId) {
  var result = copySettings(configuredEntry(layout, moduleId, true))
  var local = isObject(groupValue) ? copySettings(groupValue[moduleId]) : {}
  for (var key in local) result[key] = local[key]
  return result
}

function mergeEntry(moduleId, hostEntry, overrides) {
  var result = { id: moduleId }
  var host = copySettings(hostEntry)
  var local = copySettings(overrides)
  for (var hostKey in host) result[hostKey] = host[hostKey]
  for (var localKey in local) result[localKey] = local[localKey]
  return result
}

function moduleIdsFor(groupValue, layout) {
  var groupId = String(groupValue || "")
  var dynamicModule = dynamicModuleIdForGroup(groupId)
  if (dynamicModule !== "")
    return configuredEntry(layout, dynamicModule, true) !== null
      ? [dynamicModule] : []
  if (GroupIds.indexOf(groupId) < 0) return []
  var result = (BaseEntries[groupId] || []).filter(function(id) {
    return !trayOnly(layout, id)
  })
  var configured = configuredEntries(layout).filter(function(row) {
    return row.section !== "tray"
  })
  var explicitlyInstalled = {}
  for (var i = 0; i < configured.length; i++) {
    if (isObject(configured[i].entry)
        && configured[i].entry.shinigamiModule === true)
      explicitlyInstalled[configured[i].id] = true
  }
  for (var j = 0; j < configured.length; j++) {
    var optionalId = configured[j].id
    if (OptionalGroups[optionalId] === groupId
        && explicitlyInstalled[optionalId] !== true
        && result.indexOf(optionalId) < 0) result.push(optionalId)
  }
  return result
}

function entriesFor(groupValue, groupValueSettings, layout) {
  var ids = moduleIdsFor(groupValue, layout)
  var result = []
  for (var i = 0; i < ids.length; i++) {
    result.push(entryFor(groupValue, ids[i], groupValueSettings, layout))
  }
  return result
}

function entryFor(groupValue, moduleValue, groupValueSettings, layout) {
  var id = String(moduleValue || "")
  var ids = moduleIdsFor(groupValue, layout)
  if (!id || ids.indexOf(id) < 0) return { id: id }
  return mergeEntry(id, configuredEntry(layout, id, true),
    groupSettings(groupValueSettings, id, ids.length))
}

// WidgetSlot needs explicit host and group-local layers so an inline host-state
// write can preserve equal-valued overrides and survive consecutive updates.
function hostEntryFor(moduleValue, layout) {
  var id = String(moduleValue || "")
  var entry = configuredEntry(layout, id, true)
  return entry !== null ? entry : { id: id }
}

function settingsOverridesFor(groupValue, moduleValue, groupValueSettings,
    layout) {
  var id = String(moduleValue || "")
  var ids = moduleIdsFor(groupValue, layout)
  return groupSettings(groupValueSettings, id, ids.length)
}

function assignedModuleIds() {
  var result = []
  for (var i = 0; i < GroupIds.length; i++) {
    var entries = BaseEntries[GroupIds[i]] || []
    for (var j = 0; j < entries.length; j++) {
      if (result.indexOf(entries[j]) < 0) result.push(entries[j])
    }
  }
  for (var optionalId in OptionalGroups) {
    if (result.indexOf(optionalId) < 0) result.push(optionalId)
  }
  return result
}

function isOptionalModule(moduleValue) {
  return Object.prototype.hasOwnProperty.call(
    OptionalGroups, String(moduleValue || ""))
}

function isAssignedModule(moduleValue) {
  var moduleId = String(moduleValue || "")
  return assignedModuleIds().indexOf(moduleId) >= 0
    || ConsumedAliases.indexOf(moduleId) >= 0
}

function unassignedEntries(layout, regionValue) {
  var region = String(regionValue || "")
  if (NativeSections.indexOf(region) < 0 || !validNativeLayout(layout)
      || !Array.isArray(layout[region])) return []
  var result = []
  for (var i = 0; i < layout[region].length; i++) {
    var entry = layout[region][i]
    var moduleId = entryId(entry)
    var explicitlyInstalled = isObject(entry)
      && entry.shinigamiModule === true
    if (!isAssignedModule(moduleId) || explicitlyInstalled)
      result.push(entry)
  }
  return result
}
