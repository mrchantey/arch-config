function isZed(window) {
  var info = window.lastIpcObject || {}
  return /^(dev\.zed\.Zed(?:-Preview)?|zed)$/i.test(info.class || "")
    || /^(dev\.zed\.Zed(?:-Preview)?|zed)$/i.test(info.initialClass || "")
}

function projectName(title) {
  var project = String(title || "").split(" — ")[0].trim()
  if (project === "Zed" || project === "Empty Project") return ""
  return project.replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, 512)
}

// Keep focus history across non-Zed app activations, but not closed windows.
function rememberFocus(windows, previous, active) {
  var addresses = windows.filter(isZed).map(function(window) { return window.address })
  var recent = previous.filter(function(address) {
    return addresses.indexOf(address) !== -1 && (!active || address !== active.address)
  })
  if (active && isZed(active)) recent.unshift(active.address)
  return recent
}

function projectForGroup(windows, group, groupCount, recent) {
  var selected = ""
  var bestRank = Infinity
  for (var i = 0; i < windows.length; i++) {
    var window = windows[i]
    if (!window.workspace || window.workspace.id < 1 || !isZed(window)) continue
    if ((window.workspace.id - 1) % groupCount + 1 !== group) continue
    var project = projectName(window.title)
    if (!project) continue

    // Hyprland's snapshot seeds the order when the shell first starts.
    var history = (window.lastIpcObject || {}).focusHistoryID
    var rank = recent.indexOf(window.address)
    if (rank === -1) rank = recent.length + (typeof history === "number" && history >= 0 ? history : 1000000)
    if (window.activated) rank = -1
    if (rank < bestRank) {
      selected = project
      bestRank = rank
    }
  }
  return selected
}

function buttonLabel(group, project, vertical) {
  var number = group === 10 ? "0" : String(group)
  if (vertical || !project) return number
  // QML's Array.from splits surrogate pairs, so match Unicode code points explicitly.
  var characters = project.match(/[\uD800-\uDBFF][\uDC00-\uDFFF]|[\s\S]/g) || []
  var shortName = characters.length > 24 ? characters.slice(0, 23).join("") + "…" : project
  return number + " " + shortName
}

// Shared shell text sinks can change with updates; never hand them markup.
function safeText(text) {
  return text.replace(/</g, "‹").replace(/>/g, "›")
}
