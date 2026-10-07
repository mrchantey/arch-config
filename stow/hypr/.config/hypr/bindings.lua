-- mrchantey omarchy keybindings
--
-- SUPER:       common shortcuts
-- SUPER CTRL:  application level shortcuts
-- SUPER ALT:   windowing shortcuts
-- SUPER SHIFT: os shortcuts
--
-- Ported from bindings.conf for Omarchy 4 (quattro). Keys are unchanged; the
-- syntax is now Lua. See current bindings with: omarchy menu keybindings --print
--
-- Every `hl.unbind` below names the Omarchy default it displaces. Unlike the old
-- .conf files, re-binding a key does NOT silently replace the default -- both
-- binds would fire -- so each conflict has to be unbound first.

-- Chrome is launched directly rather than through `omarchy-launch-browser`. That
-- script treats any argument as a URL (the check is just "not --private"), so our
-- --profile-directory flag makes it follow the launch with omarchy-hyprland-focus-app,
-- which focuses the FIRST matching window in `hyprctl clients` -- an already-open
-- Chrome on another workspace -- yanking us over there. We always want the new
-- window here, on the current workspace.
-- Note this is focus stealing, NOT the placement bug that scripts/launch-here.sh
-- handles for clicked links: the launch itself was always correct. See AGENTS.md.
local browser = "uwsm app -- google-chrome-stable --new-window"

-- Not `uwsm app -- $EDITOR`: in the Hyprland session $EDITOR is omarchy's own
-- `omarchy-launch-editor --inline` (our .bashrc's EDITOR=zed only reaches
-- interactive shells), so that expanded to the same script anyway, and it
-- already does its own uwsm-app wrapping. Which editor it opens comes from
-- ~/.local/state/omarchy/defaults/editor, written by `just setup-editor`.
local editor = "omarchy-launch-editor"

--------------------------------------------------------------------------------
-- OS (SUPER SHIFT)
--------------------------------------------------------------------------------
o.bind("SUPER + SHIFT + L", "Lock", "omarchy-system-lock")
o.bind("SUPER + SHIFT + R", "󰜉 Restart", "systemctl reboot")
o.bind("SUPER + SHIFT + S", "󰐥 Shutdown", "systemctl poweroff")
o.bind("SUPER + SHIFT + Z", "󰤄 Suspend", "systemctl suspend")
o.bind("SUPER + SHIFT + H", " Relaunch Hyprland", "uwsm stop")
o.bind("SUPER + SHIFT + O", "󱄄 Omarchy Screensaver", "omarchy-launch-screensaver force")

--------------------------------------------------------------------------------
-- WINDOWING (SUPER ALT)
--------------------------------------------------------------------------------
hl.unbind("SUPER + W") -- was: Close window (moved to SUPER + Q, which frees SUPER + W for the work browser)
o.bind("SUPER + Q", "Close active window", hl.dsp.window.close())
hl.unbind("CTRL + ALT + DELETE") -- was: Close all windows (moved to SUPER + SHIFT + Q)
o.bind("SUPER + SHIFT + Q", "Close all windows", "omarchy-hyprland-window-close-all")

o.bind("SUPER + ALT + M", "Adds a master to the master side", hl.dsp.layout("addmaster"))
hl.unbind("SUPER + BACKSPACE") -- was: Toggle window transparency
o.bind("SUPER + BACKSPACE", "Swaps the current window with master", hl.dsp.layout("swapwithmaster"))
o.bind("SUPER + BACKSLASH", "Sets the orientation for the current workspace to center", hl.dsp.layout("orientationcenter"))

-- Master-layout orientation. Each of these displaces "Move window to group on <dir>".
for _, orientation in ipairs({
  { key = "UP", name = "top" },
  { key = "RIGHT", name = "right" },
  { key = "DOWN", name = "bottom" },
  { key = "LEFT", name = "left" },
}) do
  hl.unbind("SUPER + ALT + " .. orientation.key) -- was: Move window to group on <direction>
  o.bind(
    "SUPER + ALT + " .. orientation.key,
    "Sets the orientation for the current workspace to " .. orientation.name,
    hl.dsp.layout("orientation" .. orientation.name)
  )
end

-- Move-to-workspace lives on SUPER ALT, not the Omarchy default SUPER SHIFT.
for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)

  hl.unbind("SUPER + SHIFT + " .. key) -- was: Move window to workspace N
  if workspace <= 5 then
    hl.unbind("SUPER + ALT + " .. key) -- was: Switch to group window N
  end

  o.bind(
    "SUPER + ALT + " .. key,
    "Move window to workspace " .. workspace,
    hl.dsp.window.move({ workspace = tostring(workspace) })
  )
end

-- xkbcommon names these Page_Up/Page_Down; the old .conf spelling PAGEUP/PAGEDOWN
-- silently worked but the Lua binder rejects it (same trap as COMMA vs comma).
o.bind("SUPER + Page_Up", "Next Workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + Page_Down", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))

--------------------------------------------------------------------------------
-- APPLICATIONS (SUPER CTRL)
--------------------------------------------------------------------------------
-- SUPER + RETURN is left on the Omarchy default: omarchy-launch-terminal already
-- opens in the active terminal's cwd (it wraps xdg-terminal-exec --dir), which is
-- the only reason we used to override it. Which terminal it picks is declared in
-- xdg-terminals.list (stowed by the ghostty package), NOT $TERMINAL -- without
-- that file it silently falls back to foot.

hl.unbind("SUPER + F") -- was: Full screen
o.bind("SUPER + F", "File manager", "uwsm app -- nautilus --new-window")
o.bind("SUPER + B", "Browser", browser .. ' --profile-directory="Default"')
o.bind("SUPER + W", "Browser (work)", browser .. ' --profile-directory="Profile 2"')
o.bind("SUPER + N", "Editor", "omarchy-launch-editor")
hl.unbind("SUPER + T") -- was: Toggle window floating/tiling
o.bind("SUPER + T", "Activity", "omarchy-launch-tui btop")
hl.unbind("SUPER + C") -- was: Universal copy
o.bind("SUPER + C", "Element", "uwsm app -- element-desktop")
o.bind("SUPER + Z", "Zed", editor)

hl.unbind("SUPER + CTRL + B") -- was: Bluetooth panel
o.bind("SUPER + CTRL + B", "Beet Repo", editor .. " ~/me/beet")
o.bind("SUPER + CTRL + M", "Beetmash Repo", editor .. " ~/me/beetmash")
hl.unbind("SUPER + CTRL + P") -- was: Power panel
o.bind("SUPER + CTRL + P", "Personal Repo", editor .. " ~/me/personal")
hl.unbind("SUPER + CTRL + O") -- was: Toggle menu
o.bind("SUPER + CTRL + O", "Arch Config Repo", editor .. " ~/me/arch-config")
hl.unbind("SUPER + CTRL + S") -- was: Share
o.bind("SUPER + CTRL + S", "Scratchpad Repo", editor .. " ~/me/scratch")
hl.unbind("SUPER + CTRL + V") -- was: Clipboard manager
o.bind("SUPER + CTRL + V", "Venti Repo", editor .. " ~/me/venti")
o.bind("SUPER + CTRL + Y", "Bevy Repo", editor .. " ~/me/bevy")

-- Emoji picker: SUPER + CTRL + E is left on the Omarchy default, which is now
-- the shell's own picker (omarchy.emojis). The old override pointed at walker
-- with a custom wide-grid theme (stow/walker); quattro removed walker entirely,
-- and the elephant `symbols` provider with it, so there is nothing to point at.

--------------------------------------------------------------------------------
-- WEB APPS
--------------------------------------------------------------------------------
-- located in ~/.local/share/applications
-- URLs no longer need ## escaping: Lua strings aren't parsed for comments.
o.bind("SUPER + M", "YouTube Music", { webapp = "https://music.youtube.com" })
o.bind("SUPER + D", "Discord", { webapp = "https://discord.com/channels/@me" })
hl.unbind("SUPER + G") -- was: Toggle window grouping
o.bind("SUPER + G", "Graphite", { webapp = "https://editor.graphite.art" })
o.bind("SUPER + R", "Docs", { webapp = "https://docs.rs" })

-- o.bind("SUPER + A", "ChatGPT", { webapp = "https://gemini.google.com/app" })
o.bind("SUPER + A", "ChatGPT", { webapp = "https://claude.ai/new" })

-- o.bind("SUPER + C", "Calendar", { webapp = "https://calendar.google.com" })
o.bind("SUPER + E", "Email", { webapp = "https://gmail.com" })
o.bind("SUPER + Y", "YouTube", { webapp = "https://youtube.com/" })

--------------------------------------------------------------------------------
-- DISABLED OMARCHY DEFAULTS
--------------------------------------------------------------------------------
-- Cursor screen-zoom (default/hypr/bindings/utilities.lua):
--   SUPER CTRL, Z       -> Zoom in (increments cursor:zoom_factor)
--   SUPER CTRL ALT, Z   -> Reset zoom (fully zoom out)
hl.unbind("SUPER + CTRL + Z")
hl.unbind("SUPER + CTRL + ALT + Z")

--------------------------------------------------------------------------------
-- DICTATION (voxtype)
--------------------------------------------------------------------------------
-- Push-to-talk: hold to record, release to transcribe.
-- PAUSE for keyboards that have it (blackboy); INSERT everywhere (silver-fox has no PAUSE).
-- Talking over playback is pointless, so starting a clip also cuts any speech in flight.
-- Quattro adds its own voxtype defaults (F9 push-to-talk, SUPER + CTRL + X toggle).
-- They don't collide with these, so they're left in place as extra entry points.
for _, key in ipairs({ "PAUSE", "INSERT" }) do
  o.bind(key, "Start dictation (push-to-talk)", "~/me/arch-config/scripts/tts.sh stop; voxtype record start")
  o.bind(key, "Stop dictation (push-to-talk)", "voxtype record stop", { release = true })

  -- TEXT-TO-SPEECH (kokoro) — the reverse of dictation.
  -- Toggle: read the highlighted selection aloud; press again to stop.
  -- SHIFT + the dictation keys, so speak/listen sit on the same fingers.
  o.bind("SHIFT + " .. key, "Read selection aloud", "~/me/arch-config/scripts/tts.sh toggle")

  -- CTRL + the same keys reads the last reply from the coding agent in Zed, no highlighting.
  -- Provider-agnostic: it reads the ACP stream tapped by scripts/acp-tee.sh, so it works for
  -- whichever agent the panel is running. Press again to stop.
  o.bind("CTRL + " .. key, "Read last agent reply aloud", "~/me/arch-config/scripts/tts.sh last")
end

--------------------------------------------------------------------------------
-- THEME — toggle between dark (Everforest) and light (Solarized Light)
--------------------------------------------------------------------------------
o.bind("SUPER + SHIFT + T", "Toggle light/dark theme", "~/me/arch-config/scripts/theme-toggle.sh")

--------------------------------------------------------------------------------
-- PRESENTATION (SUPER ALT P) — modal step-through for demos
--------------------------------------------------------------------------------
-- Enter a submap where page/arrow keys drive the *armed* presentation via
-- ~/me/arch-config/scripts/present (arm one first with `present arm` in a talk's repo).
-- The map is presentation-agnostic; the repo supplies its own present.ts.
-- While in the submap plain Enter/Space/Backspace are captured, so you cannot
-- type: press Esc (or Super+Alt+P again) to leave and type freely.
local function leave_presentation()
  hl.exec_cmd("~/me/arch-config/scripts/present notify-exit")
  hl.dispatch(hl.dsp.submap("reset"))
end

hl.define_submap("presentation", function()
  -- next
  for _, key in ipairs({ "Page_Down", "RIGHT", "RETURN", "SPACE" }) do
    hl.bind(key, hl.dsp.exec_cmd("~/me/arch-config/scripts/present next"), { description = "Next slide" })
  end
  -- prev
  for _, key in ipairs({ "Page_Up", "LEFT", "BACKSPACE" }) do
    hl.bind(key, hl.dsp.exec_cmd("~/me/arch-config/scripts/present prev"), { description = "Previous slide" })
  end
  -- exit presentation mode
  hl.bind("ESCAPE", leave_presentation, { description = "Exit presentation" })
  hl.bind("SUPER + ALT + P", leave_presentation, { description = "Exit presentation" })
end)

o.bind("SUPER + ALT + P", "Presentation step-through", function()
  hl.exec_cmd("~/me/arch-config/scripts/present notify-enter")
  hl.dispatch(hl.dsp.submap("presentation"))
end)

--------------------------------------------------------------------------------
-- PRESENTATION MODE (SUPER ALT SHIFT P) — chromeless desktop for demos
--------------------------------------------------------------------------------
-- The *visual* counterpart to the `present` step-through above: hides the blue
-- window border, zeroes gaps/rounding, and hides the bar so pre-set workspaces
-- read edge-to-edge on a projector. Applies globally; toggle to restore.
o.bind("SUPER + ALT + SHIFT + P", "Presentation mode (chromeless)", "~/me/arch-config/scripts/presentation-mode.sh")
