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

function appName(window, desktopName) {
  var info = window.lastIpcObject || {}
  var className = String(info.class || info.initialClass || "")
  if (/^google-chrome(?:-(stable|beta|unstable))?$/i.test(className)) return "Chrome"
  if (!desktopName && /^chrome-/i.test(className)) return "Chrome"
  var name = String(desktopName || className.split(".").pop().replace(/[-_]+/g, " "))
  if (!desktopName) name = name.charAt(0).toUpperCase() + name.slice(1)
  return name.replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, 512)
}

// Retain relative focus order for every app, pruning closed windows.
function rememberFocus(windows, previous, active) {
  var addresses = windows.map(function(window) { return window.address })
  var recent = previous.filter(function(address) {
    return addresses.indexOf(address) !== -1 && (!active || address !== active.address)
  })
  if (active && addresses.indexOf(active.address) !== -1) recent.unshift(active.address)
  return recent
}

function labelForGroup(windows, group, groupCount, recent, resolveAppName) {
  var selected = ""
  var bestPriority = Infinity
  var bestRank = Infinity
  for (var i = 0; i < windows.length; i++) {
    var window = windows[i]
    if (!window.workspace || window.workspace.id < 1) continue
    if ((window.workspace.id - 1) % groupCount + 1 !== group) continue
    var zed = isZed(window)
    var name = (zed ? projectName(window.title) : "") || resolveAppName(window)
    if (!name) continue
    var priority = zed ? 0 : 1

    // Hyprland's snapshot seeds the order when the shell first starts.
    var history = (window.lastIpcObject || {}).focusHistoryID
    var rank = recent.indexOf(window.address)
    if (rank === -1) rank = recent.length + (typeof history === "number" && history >= 0 ? history : 1000000)
    if (window.activated) rank = -1
    if (priority < bestPriority || (priority === bestPriority && rank < bestRank)) {
      selected = name
      bestPriority = priority
      bestRank = rank
    }
  }
  return selected
}

function buttonLabel(group, name, vertical) {
  var number = group === 10 ? "0" : String(group)
  if (vertical || !name) return number
  // QML's Array.from splits surrogate pairs, so match Unicode code points explicitly.
  var characters = name.match(/[\uD800-\uDBFF][\uDC00-\uDFFF]|[\s\S]/g) || []
  var shortName = characters.length > 24 ? characters.slice(0, 23).join("") + "…" : name
  return number + " " + shortName
}

// Shared shell text sinks can change with updates; never hand them markup.
function safeText(text) {
  return text.replace(/</g, "‹").replace(/>/g, "›")
}
