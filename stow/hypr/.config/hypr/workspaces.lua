-- Synced workspaces: switching workspace switches every monitor together.
--
-- Hyprland gives each workspace to exactly one monitor, so workspace N here is a
-- group of real workspaces, one per monitor: N on the primary, N + 10 on the
-- second monitor, N + 20 on a third. Monitors are ranked by position, left to
-- right then top to bottom, so the leftmost screen is the primary. Nothing is
-- pinned with workspace rules: showing a workspace pulls it onto the monitor
-- whose rank owns it, so the mapping heals itself when monitors come, go or move.
--
-- Syncing hangs off the `workspace.active` event rather than the binds, so
-- anything that changes workspace (a keybind, a bar click, a launcher focusing a
-- window elsewhere, a swipe) brings the other monitors along. The binds that
-- pick a workspace by number or by order live in bindings.lua and go through
-- `show`, `move`, `swap`, `cycle` and `previous` below.

local workspaces = {}

-- groups per monitor, ie the 1-0 number keys
local GROUPS = 10

-- set while sync drives the other monitors, so their own events are ignored
local syncing = false
-- the group on screen, and the one before it for `previous`
local current_group = nil
local previous_group = nil

-- helpers, defined under Implementation
local windows_on, move_all

--- workspace id that shows `group` on the monitor at `rank` (0 = primary)
function workspaces.id(group, rank)
  return group + GROUPS * rank
end

--- group a workspace id belongs to, ie 13 -> 3
function workspaces.group(id)
  return (id - 1) % GROUPS + 1
end

--- rank of the monitor a workspace id belongs on, ie 13 -> 1
function workspaces.id_rank(id)
  return (id - 1) // GROUPS
end

--- switches every monitor to `group`, keeping focus on the current monitor
function workspaces.show(group)
  local monitor = hl.get_active_monitor()
  if not monitor then
    return
  end
  local target = workspaces.id(group, workspaces.rank(monitor))
  hl.dispatch(hl.dsp.focus({ workspace = tostring(target), on_current_monitor = true }))
  -- the event above syncs too, this catches a monitor that drifted while this one did not change
  workspaces.sync(group)
end

--- moves the active window to `group` on its own monitor, following it unless `follow` is false
function workspaces.move(group, follow)
  local window = hl.get_active_window()
  if not window or not window.monitor then
    return
  end
  local target = workspaces.id(group, workspaces.rank(window.monitor))
  hl.dispatch(hl.dsp.window.move({ workspace = tostring(target), follow = follow }))
end

--- shows the next (`step` 1) or previous (`step` -1) group holding windows, wrapping
function workspaces.cycle(step)
  local current = workspaces.current()
  if not current then
    return
  end
  -- Hyprland drops a hidden workspace once it is empty, so existing means occupied
  local open = {}
  for _, workspace in ipairs(hl.get_workspaces()) do
    if workspace.id > 0 and not workspace.special then
      open[workspaces.group(workspace.id)] = true
    end
  end
  for offset = 1, GROUPS - 1 do
    local group = (current - 1 + step * offset) % GROUPS + 1
    if open[group] then
      return workspaces.show(group)
    end
  end
end

--- trades the windows on this monitor with those on the monitor in `direction` (l, r, u, d), within the current group
function workspaces.swap(direction)
  local here = hl.get_active_monitor()
  local there = hl.get_monitor(direction)
  local group = workspaces.current()
  if not here or not there or there.name == here.name or not group then
    return
  end
  local window = hl.get_active_window()
  local here_id = workspaces.id(group, workspaces.rank(here))
  local there_id = workspaces.id(group, workspaces.rank(there))
  -- collect both sides before moving anything, so nothing is moved twice
  local here_windows = windows_on(here_id)
  local there_windows = windows_on(there_id)
  move_all(here_windows, there_id)
  move_all(there_windows, here_id)
  if window then
    hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
  end
end

--- shows the group that was on screen before this one
function workspaces.previous()
  if previous_group then
    workspaces.show(previous_group)
  end
end

--- group on the focused monitor
function workspaces.current()
  local monitor = hl.get_active_monitor()
  local workspace = monitor and monitor.active_workspace
  if not workspace or workspace.id < 1 then
    return nil
  end
  return workspaces.group(workspace.id)
end

--- monitors that show their own content, primary first
function workspaces.ranked()
  local monitors = {}
  for _, monitor in ipairs(hl.get_monitors()) do
    if not monitor.is_mirror then
      table.insert(monitors, monitor)
    end
  end
  table.sort(monitors, function(left, right)
    if left.x ~= right.x then
      return left.x < right.x
    end
    return left.y < right.y
  end)
  return monitors
end

--- position of `monitor` in `ranked`, 0 for the primary
function workspaces.rank(monitor)
  for index, ranked in ipairs(workspaces.ranked()) do
    if ranked.name == monitor.name then
      return index - 1
    end
  end
  return 0
end

--- brings every monitor to `group`, handing focus and the cursor back afterwards
function workspaces.sync(group)
  if group ~= current_group then
    previous_group = current_group
    current_group = group
  end

  -- monitors not already showing their workspace for this group
  local stale = {}
  for index, monitor in ipairs(workspaces.ranked()) do
    local target = workspaces.id(group, index - 1)
    local active = monitor.active_workspace
    if not active or active.id ~= target then
      table.insert(stale, { monitor = monitor.name, target = target })
    end
  end
  if #stale == 0 then
    return
  end

  syncing = true
  local focused = hl.get_active_monitor()
  local window = hl.get_active_window()
  local cursor = hl.get_cursor_pos()

  -- a workspace can only be put on the focused monitor, so visit each in turn
  for _, entry in ipairs(stale) do
    hl.dispatch(hl.dsp.focus({ monitor = entry.monitor }))
    hl.dispatch(hl.dsp.focus({ workspace = tostring(entry.target), on_current_monitor = true }))
  end

  -- refocusing a window that ended up hidden would drag its workspace back on screen
  if window and window.workspace and window.workspace.visible then
    hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
  elseif focused then
    hl.dispatch(hl.dsp.focus({ monitor = focused.name }))
  end
  if cursor then
    hl.dispatch(hl.dsp.cursor.move({ x = cursor.x, y = cursor.y }))
  end
  syncing = false
end

--- folds workspaces whose monitor rank no longer exists into the same group on the monitor now holding them, then resyncs
function workspaces.heal()
  local ranks = #workspaces.ranked()
  if ranks == 0 then
    return
  end
  -- a removed monitor hands its workspaces to one that stays, out of reach of every bind
  for _, workspace in ipairs(hl.get_workspaces()) do
    local id = workspace.id
    if id > 0 and not workspace.special and workspace.monitor and workspaces.id_rank(id) >= ranks then
      local target = workspaces.id(workspaces.group(id), workspaces.rank(workspace.monitor))
      move_all(hl.get_workspace_windows(workspace), target)
    end
  end
  local group = workspaces.current()
  if group then
    workspaces.sync(group)
  end
end

--------------------------------------------------------------------------------
-- Implementation
--------------------------------------------------------------------------------

-- windows on workspace `id`, none if it does not exist (a nil workspace would match every window)
function windows_on(id)
  local workspace = hl.get_workspace(tostring(id))
  if not workspace then
    return {}
  end
  return hl.get_workspace_windows(workspace)
end

-- moves `windows` to workspace `id` without following them
function move_all(windows, id)
  for _, window in ipairs(windows) do
    hl.dispatch(hl.dsp.window.move({
      workspace = tostring(id),
      follow = false,
      window = "address:" .. window.address,
    }))
  end
end

hl.on("workspace.active", function(workspace)
  if syncing or workspace.special or workspace.id < 1 then
    return
  end
  workspaces.sync(workspaces.group(workspace.id))
end)

-- Monitor events land before positions settle, so heal once they have, coalescing bursts.
local heal_timer = nil
local function heal_soon()
  if heal_timer then
    heal_timer:set_enabled(false)
  end
  heal_timer = hl.timer(workspaces.heal, { timeout = 200, type = "oneshot" })
end

hl.on("hyprland.start", heal_soon)
hl.on("monitor.added", heal_soon)
hl.on("monitor.removed", heal_soon)
hl.on("monitor.layout_changed", heal_soon)

return workspaces
