local generated = require("nixconf.generated")

local defaults = generated.defaults
local commands = generated.commands
local mod = "SUPER"
local launcher_timers = {}
local navigation_binds = {}

---@enum NavAction
local NavAction = {
	Up = 0,
	Down = 1,
	Left = 2,
	Right = 3,
	Close = 4,
	NewTab = 5,
}

local nav_directions = {
	[NavAction.Up] = "up",
	[NavAction.Down] = "down",
	[NavAction.Left] = "left",
	[NavAction.Right] = "right",
}

local kitty_nav_keys = {
	[NavAction.Left] = "h",
	[NavAction.Right] = "l",
	[NavAction.Close] = "w",
	[NavAction.NewTab] = "t",
}

local function bind_exec(keys, command, opts)
	hl.bind(keys, hl.dsp.exec_cmd(command), opts)
end

local function run_workspace_launcher(directives, opts)
	opts = opts or {}
	local index = 1
	local initial_workspace = opts.restore and "previous" or nil

	local function step()
		launcher_timers[directives] = nil
		local directive = directives[index]
		if directive == nil then
			if initial_workspace ~= nil then
				hl.dispatch(hl.dsp.focus({ workspace = initial_workspace }))
			end
			return
		end

		hl.dispatch(hl.dsp.focus({ workspace = directive.workspace }))
		hl.dispatch(hl.dsp.exec_cmd(directive.command))
		index = index + 1

		if directives[index] ~= nil or initial_workspace ~= nil then
			launcher_timers[directives] = hl.timer(step, { timeout = directive.delay or 250, type = "oneshot" })
		end
	end

	step()
end

local function active_window_class()
	local window = hl.get_active_window()
	if window == nil then
		return nil
	end

	return window.class
end

local function default_navigation_dispatcher(action)
	return function()
		local direction = nav_directions[action]
		if direction ~= nil then
			hl.dispatch(hl.dsp.focus({ direction = direction }))
		elseif action == NavAction.Close then
			hl.dispatch(hl.dsp.window.close())
		end
	end
end

local function update_navigation_bind_state()
	local is_kitty = active_window_class() == "kitty"
	for _, binds in ipairs(navigation_binds) do
		local kitty_bind = binds.kitty
		local use_kitty_bind = is_kitty and kitty_bind ~= nil

		binds.default:set_enabled(not use_kitty_bind)
		if kitty_bind ~= nil then
			kitty_bind:set_enabled(use_kitty_bind)
		end
	end
end

local function bind_navigation(keys, action)
	local binds = {
		default = hl.bind(keys, default_navigation_dispatcher(action)),
	}

	local kitty_key = kitty_nav_keys[action]
	if kitty_key ~= nil then
		binds.kitty = hl.bind(keys, hl.dsp.send_shortcut({ mods = mod, key = kitty_key, window = "activewindow" }))
		binds.kitty:set_enabled(false)
	end

	table.insert(navigation_binds, binds)
	return binds.default
end

bind_exec(mod .. " + RETURN", defaults.tty)
bind_exec(mod .. " + E", defaults.fileManager)
bind_exec(mod .. " + B", defaults.browser)
bind_exec(mod .. " + R", "xhisper-local")
bind_exec(mod .. " + SHIFT + B", defaults.browser .. " --private-window duckduckgo.com")
bind_exec(mod .. " + P", "hyprpicker -a")
bind_exec(mod .. " + EQUAL", defaults.calculator)

bind_exec(mod .. " + Z", defaults.editor)
bind_exec(mod .. " + D", defaults.editor .. " " .. defaults.home .. "/dirac/buildos-web")
hl.bind(mod .. " + SHIFT + D", function()
	run_workspace_launcher(generated.launchers.launchwork)
end)
bind_exec(mod .. " + N", defaults.editor .. " " .. defaults.home .. "/nixconf")
bind_navigation(mod .. " + T", NavAction.NewTab)

bind_exec(mod .. " + SUPER_L", "fuzzel")
bind_exec(mod .. " + V", "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy")
bind_exec(mod .. " + SLASH", "bemoji -t")

bind_exec(mod .. " + COMMA", "playerctl previous")
bind_exec(mod .. " + PERIOD", "playerctl next")
bind_exec(mod .. " + SPACE", "playerctl play-pause")

bind_navigation(mod .. " + W", NavAction.Close)
hl.bind(mod .. " + SHIFT + W", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + M", hl.dsp.window.fullscreen())
bind_exec(mod .. " + M", commands.monitorProfileSelector)

bind_navigation(mod .. " + left", NavAction.Left)
bind_navigation(mod .. " + H", NavAction.Left)
bind_navigation(mod .. " + right", NavAction.Right)
bind_navigation(mod .. " + L", NavAction.Right)
bind_navigation(mod .. " + up", NavAction.Up)
bind_navigation(mod .. " + K", NavAction.Up)
bind_navigation(mod .. " + down", NavAction.Down)
bind_navigation(mod .. " + J", NavAction.Down)

hl.bind(mod .. " + ALT + left", hl.dsp.window.resize({ x = -80, y = 0, relative = true }))
hl.bind(mod .. " + ALT + H", hl.dsp.window.resize({ x = -80, y = 0, relative = true }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.resize({ x = 80, y = 0, relative = true }))
hl.bind(mod .. " + ALT + L", hl.dsp.window.resize({ x = 80, y = 0, relative = true }))
hl.bind(mod .. " + ALT + up", hl.dsp.window.resize({ x = 0, y = -60, relative = true }))
hl.bind(mod .. " + ALT + K", hl.dsp.window.resize({ x = 0, y = -60, relative = true }))
hl.bind(mod .. " + ALT + down", hl.dsp.window.resize({ x = 0, y = 60, relative = true }))
hl.bind(mod .. " + ALT + J", hl.dsp.window.resize({ x = 0, y = 60, relative = true }))

hl.bind(mod .. " + Tab", function()
	hl.dispatch(hl.dsp.window.cycle_next())
	hl.dispatch(hl.dsp.window.bring_to_top())
end)

for workspace = 1, 10 do
	local key = tostring(workspace % 10)
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace, on_current_monitor = true }))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mod .. " + CONTROL + H", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CONTROL + L", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + CONTROL + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CONTROL + right", hl.dsp.focus({ workspace = "e+1" }))

hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ workspace = "e+1" }))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

bind_exec("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
bind_exec("XF86AudioRaiseVolume", "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+", { repeating = true })
bind_exec("XF86AudioLowerVolume", "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-", { repeating = true })
bind_exec("XF86MonBrightnessUp", "brightnessctl s +5%", { repeating = true })
bind_exec("XF86MonBrightnessDown", "brightnessctl s 5%-", { repeating = true })
bind_exec("XF86AudioPlay", "playerctl play-pause")
bind_exec("XF86AudioPause", "playerctl play-pause")
bind_exec("XF86AudioNext", "playerctl next")
bind_exec("XF86AudioPrev", "playerctl previous")

bind_exec("PRINT", "hyprshot -z -m region")
bind_exec(mod .. " + SHIFT + S", "hyprshot -z -m region")
bind_exec(mod .. " + CONTROL + S", "hyprshot -z -m output")
bind_exec(mod .. " + PRINT", "hyprshot -z -m output")
bind_exec(mod .. " + SHIFT + PRINT", "hyprshot -z -m window")

hl.on("window.active", update_navigation_bind_state)
hl.on("window.class", update_navigation_bind_state)
update_navigation_bind_state()
