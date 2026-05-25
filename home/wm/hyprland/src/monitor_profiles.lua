local generated = require("nixconf.generated")
local util = require("nixconf.util")

local M = {}

local default_label = "default"
local headless = generated.monitor.tabletHeadless
local host_config = generated.monitor.hosts[generated.host]
local state = {
	active_profile = default_label,
	sunshine_pid = nil,
}
local debounce_timer = nil
local last_profile_request_id = nil

local function state_path()
	local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
	return runtime_dir .. "/hyprmonitor-state.lua"
end

local function profile_request_path()
	local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
	return runtime_dir .. "/hyprmonitor-profile-request"
end

local function load_state()
	local chunk = loadfile(state_path())
	if chunk == nil then
		return
	end

	local ok, loaded = pcall(chunk)
	if ok and type(loaded) == "table" then
		state.active_profile = loaded.active_profile or state.active_profile
		state.sunshine_pid = loaded.sunshine_pid
	end
end

local function read_profile_request()
	local file = io.open(profile_request_path(), "r")
	if file == nil then
		return nil, nil
	end

	local request_id = file:read("*l")
	local label = file:read("*l")
	file:close()

	if label == nil then
		label = request_id
		request_id = label
	end

	if request_id == nil or request_id == "" or label == nil or label == "" then
		return nil, nil
	end

	return request_id, label
end

local function load_desired_profile()
	local request_id, label = read_profile_request()
	if label == nil then
		return
	end

	last_profile_request_id = request_id
	state.active_profile = label
end

local function save_state()
	local path = state_path()
	local file = io.open(path, "w")
	if file == nil then
		return
	end

	file:write("return {\n")
	file:write("  active_profile = " .. string.format("%q", state.active_profile) .. ",\n")
	if state.sunshine_pid ~= nil then
		file:write("  sunshine_pid = " .. tostring(state.sunshine_pid) .. ",\n")
	else
		file:write("  sunshine_pid = nil,\n")
	end
	file:write("}\n")
	file:close()
end

local function output_from_desc(desc)
	if desc:sub(1, 5) == "desc:" then
		return desc
	end
	return "desc:" .. desc
end

local function resolve_output(monitors, output_ref)
	local monitor = monitors[output_ref]
	if type(monitor) == "table" and monitor.desc ~= nil then
		return output_from_desc(monitor.desc)
	end
	return output_from_desc(output_ref)
end

local function monitor_names()
	local names = {}
	for name, _ in pairs(host_config.monitors or {}) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function profiles_by_label()
	local profiles = {}
	for key, profile in pairs(host_config.profiles or {}) do
		profile.key = key
		profile.label = key
		profiles[key] = profile
	end
	return profiles
end

local function get_profile(label)
	if label == default_label or label == nil then
		return nil
	end
	return profiles_by_label()[label]
end

local function is_valid_profile_label(label)
	return label == default_label or profiles_by_label()[label] ~= nil
end

local function profile_labels()
	local labels = { default_label }
	for label, _ in pairs(profiles_by_label()) do
		table.insert(labels, label)
	end
	table.sort(labels)
	return labels
end

local function default_enabled_outputs()
	local outputs = {}
	for _, key in ipairs(monitor_names()) do
		outputs[resolve_output(host_config.monitors, key)] = true
	end
	return outputs
end

local function profile_enabled_outputs(profile)
	if profile == nil then
		return default_enabled_outputs()
	end

	local outputs = {}
	for _, output_ref in ipairs(profile.enabledOutputs or {}) do
		outputs[resolve_output(host_config.monitors, output_ref)] = true
	end
	return outputs
end

local function profile_overrides(profile)
	if profile == nil or profile.monitorOverrides == nil then
		return {}
	end

	local resolved = {}
	for output_ref, overrides in pairs(profile.monitorOverrides) do
		resolved[resolve_output(host_config.monitors, output_ref)] = overrides
	end
	return resolved
end

local function stop_sunshine()
	if state.sunshine_pid ~= nil then
		util.run("kill " .. tostring(state.sunshine_pid) .. " >/dev/null 2>&1")
		state.sunshine_pid = nil
	end
end

local function apply_monitor(output, settings, overrides)
	local spec = {
		output = output,
		mode = overrides.mode or settings.mode,
		position = overrides.position or settings.position,
		scale = tostring(overrides.scale or settings.scale),
		disabled = false,
	}

	for key, value in pairs(settings) do
		if key ~= "mode" and key ~= "position" and key ~= "scale" then
			spec[key] = value
		end
	end
	for key, value in pairs(overrides) do
		if key ~= "mode" and key ~= "position" and key ~= "scale" then
			spec[key] = value
		end
	end

	hl.monitor(spec)
end

local function apply_workspace_rules()
	for _, key in ipairs(monitor_names()) do
		local monitor = host_config.monitors[key]
		if monitor.workspace ~= nil then
			hl.workspace_rule({
				workspace = tostring(monitor.workspace),
				monitor = resolve_output(host_config.monitors, key),
				default = true,
			})
		end
	end
end

local function find_sunshine_output_index(output_name)
	-- Sunshine's Linux output_name is its zero-based Wayland monitor list index,
	-- not Hyprland's monitor ID.
	local monitors = util.capture("hyprctl monitors")
	if monitors == nil then
		return nil
	end

	local index = 0
	for line in monitors:gmatch("[^\n]+") do
		local name = line:match("^Monitor%s+(%S+)%s+%(ID%s+%-?%d+%):")
		if name ~= nil then
			if name == output_name then
				return index
			end
			index = index + 1
		end
	end

	return nil
end

local function start_sunshine()
	local output_index = nil
	for _ = 1, 30 do
		output_index = find_sunshine_output_index(headless.name)
		if output_index ~= nil then
			break
		end
		util.run("sleep 0.1")
	end

	if output_index == nil then
		util.notify("hyprmonitor", "unable to find tablet headless output")
		return
	end

	local pid = util.capture(
		"sh -c " .. util.shell_quote("sunshine output_name=" .. tostring(output_index) .. " >/dev/null 2>&1 & echo $!")
	)
	if pid ~= nil then
		state.sunshine_pid = tonumber(pid:match("%d+"))
	end
end

local function switch_audio(profile)
	local alsa_name = nil
	if profile ~= nil then
		alsa_name = profile.defaultAudioOutputAlsaName
	end
	if alsa_name == nil then
		alsa_name = host_config.defaultAudioOutputAlsaName
	end
	if alsa_name == nil then
		return
	end

	hl.exec_cmd(generated.commands.switchaudio .. " --alsa-name " .. util.shell_quote(alsa_name))
end

function M.apply_profile(label)
	if host_config == nil then
		return
	end

	label = label or default_label
	if not is_valid_profile_label(label) then
		util.notify("hyprmonitor", "unknown monitor profile: " .. tostring(label))
		return
	end

	local profile = get_profile(label)
	local enabled_outputs = profile_enabled_outputs(profile)
	local overrides = profile_overrides(profile)

	stop_sunshine()

	for _, key in ipairs(monitor_names()) do
		local monitor = host_config.monitors[key]
		local output = resolve_output(host_config.monitors, key)
		if enabled_outputs[output] then
			apply_monitor(output, monitor.settings, overrides[output] or {})
		else
			hl.monitor({ output = output, disabled = true })
		end
	end

	if profile ~= nil and profile.useTablet then
		hl.monitor({
			output = headless.name,
			mode = tostring(math.floor(headless.width / headless.downsample)) .. "x" .. tostring(
				math.floor(headless.height / headless.downsample)
			),
			position = headless.position,
			scale = tostring(headless.scale),
			disabled = false,
		})
		start_sunshine()
	end

	state.active_profile = label
	save_state()
	switch_audio(profile)
end

function M.choose_profile()
	local labels = profile_labels()
	local result = util.capture(
		"printf %s "
			.. util.shell_quote(util.join_lines(labels))
			.. " | fuzzel --dmenu --index --prompt "
			.. util.shell_quote("Monitors> ")
	)
	if result == nil or result == "" then
		return
	end

	local index = tonumber(result:match("%d+"))
	if index == nil then
		util.notify("hyprmonitor", "fuzzel returned a non-numeric selection")
		return
	end

	local selected = labels[index + 1]
	if selected ~= nil then
		M.apply_profile(selected)
	end
end

function M.choose_profile_command()
	return generated.commands.monitorProfileSelector
end

local function debounce_reapply()
	if debounce_timer ~= nil then
		debounce_timer:set_enabled(false)
	end
	debounce_timer = hl.timer(function()
		M.apply_profile(state.active_profile)
	end, { timeout = 500, type = "oneshot" })
end

local function poll_profile_request()
	local request_id, label = read_profile_request()
	if request_id == nil or request_id == last_profile_request_id then
		return
	end

	last_profile_request_id = request_id
	M.apply_profile(label)
end

if host_config ~= nil then
	load_state()
	load_desired_profile()
	apply_workspace_rules()
	M.apply_profile(state.active_profile)
	M.profile_request_timer = hl.timer(poll_profile_request, { timeout = 250, type = "repeat" })
	hl.on("monitor.added", debounce_reapply)
	hl.on("monitor.removed", debounce_reapply)
end

return M
