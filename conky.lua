-- {{{ HiDPI

local function get_scaler()
	return tonumber(os.getenv("GDK_SCALE"))
end

local scaler = get_scaler()

-- }}}
-- {{{ Functions

-- [[ Command execution function ]]
local function run_command (command_string)
	return io.popen(command_string):read('*a'):sub(1, -2)
end

-- [[ Check if the system has battery ]]

local battery_path = {
	base = "/sys/class/power_supply",
	variants = {"rk-bat", "BAT0", "BAT1", "BAT2"},
	has_health = nil
}

local function has_battery()

	-- Iterate the paths and check for a valid battery
	for index, bat_var in pairs(battery_path.variants) do
		if run_command("test -d " .. battery_path.base .. "/" .. bat_var .. " && echo true || echo false") == "true" then
			battery_path.has_health = run_command("test -f " .. battery_path.base .. "/" .. bat_var .. "/" .. "health" .. " && echo true || echo false") == "true"
			return index
		end
	end

	-- If no battery was found return null
	return 0
end

-- [[ String interpolation function ]]
local function string_interpolation (string_input, variable_table)
	return string_input:gsub('(#%b{})', function (variable_name)
		return variable_table[variable_name:sub(3, -2)] or variable_name
	end)
end

-- [[ String string function ]]
function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) table.insert(fields, c) end)
	return fields
end

-- }}}
-- {{{ XResource

local xrdb_prefix = "conky"
local function get_xrdb_item(item_name)
	return run_command("xrdb -q | grep " .. xrdb_prefix .. "." .. item_name .. " | head -n1 | awk '{print $2}'")
end

-- }}}
-- {{{ Variable

-- [[ Dev variables ]]

local bar = {
	length = tonumber(get_xrdb_item("bar")),
	char = "-"
}

local graphs = {
	per_line = 4,
	height = tonumber(get_xrdb_item("graph-height")) * scaler,
	width = tonumber(get_xrdb_item("graph-width")) * scaler
}

-- }}}
-- {{{ Config

local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)") or ""
end

local my_functions = script_path() .. 'functions.lua'

conky.config = {
	own_window_class = 'Conky';
	own_window_title = 'Main_Conky_Window',
	alignment = 'top_right',
	background = false,
	border_width = tonumber(get_xrdb_item("border")) * scaler,
	cpu_avg_samples = 2,
	default_bar_height = graphs.height,
	default_color = 'black',
	default_outline_color = 'black',
	double_buffer = true,
	draw_borders = false,
	draw_graph_borders = true,
	draw_outline = false,
	draw_shades = false,
	extra_newline = false,
	default_color = get_xrdb_item("foreground"),
	font = 'Mono:size=12',
	gap_x = tonumber(get_xrdb_item("gapx")) * scaler,
	gap_y = tonumber(get_xrdb_item("gapy")) * scaler,
	minimum_height = 5 * scaler,
	minimum_width = 5 * scaler,
	net_avg_samples = 2,
	no_buffers = true,
	out_to_console = false,
	out_to_ncurses = false,
	out_to_stderr = false,
	out_to_x = true,
	own_window = true,
	own_window_transparent = false,
	own_window_type = 'override',
	own_window_colour = get_xrdb_item("background"),
	own_window_argb_visual = true,
	own_window_argb_value = 210,
	show_graph_range = false,
	show_graph_scale = false,
	stippled_borders = 0,
	update_interval = 1,
	uppercase = false,
	use_spacer = 'none',
	use_xft = true,
	lua_load = my_functions
}

-- }}}
-- {{{ Main

-- [[ Pregenerate the needed variables ]] --
local pregenerated = {
	release = run_command("lsb_release -sd"):gsub("\"", ""),
	release_version = run_command("lsb_release -s"):gsub("\"", ""),
	bash_version = run_command("bash -c 'echo $BASH_VERSION'"),
	cpu_name = run_command("grep 'model name' /proc/cpuinfo | uniq | cut -f 2 -d ':' | awk '{$1=$1}1'")
}

-- [[ Generate the graph web of CPUs ]]
local cpu_count = run_command("grep -c ^processor /proc/cpuinfo")
local cpu_web_string = ""
for i = 0, cpu_count - 1, graphs.per_line do
	-- First part generates all the naming
	for j = 0, graphs.per_line - 1, 1 do
		if j + i > cpu_count - 1 then break end
		local core_desc = "Core " ..  i + j + 1
		cpu_web_string = cpu_web_string .. core_desc
		if j ~= (graphs.per_line - 1) then
			cpu_web_string = cpu_web_string .. string.rep(" ", 25 - core_desc:len())
		end
	end
	cpu_web_string = cpu_web_string .. "\n"

	-- Second part lists all the governors
	for j = 0, graphs.per_line - 1, 1 do
		if j + i > cpu_count - 1 then break end
		local gover_desc = "${lua justify_gover " .. i + j + 1 .. " 25}"
		cpu_web_string = cpu_web_string .. gover_desc
	end
	cpu_web_string = cpu_web_string .. "\n"

	-- Third part generates all the frequencies
	for j = 0, graphs.per_line - 1, 1 do
		if j + i > cpu_count - 1 then break end
		-- Use custom frequency command
		local freq_desc = "${lua justify_core " .. i + j + 1 .. " 25}"
		cpu_web_string = cpu_web_string .. freq_desc
	end
	cpu_web_string = cpu_web_string .. "\n"

	-- Fourth part generates all the actual graphs
	for j = 0, graphs.per_line - 1, 1 do
		if j + i > cpu_count - 1 then break end
		cpu_web_string = cpu_web_string .. "${cpugraph" .. " " .. "cpu" .. i + j + 1 .. " " .. graphs.height .. "," .. graphs.width .. "}"
	end
	cpu_web_string = cpu_web_string .. "\n"
end

-- Final part generates the all cores graph
cpu_web_string = cpu_web_string .. "All Cores\n" .. "${lua gover_all}\n" .. "${lua justify_core 0 25}" .. "\n"
cpu_web_string = cpu_web_string .. "${cpugraph cpu0 " .. graphs.height .. "," .. graphs.width * graphs.per_line .. "}"

-- [[ Memory graph string ]]
mem_web_string = "Memory\n"
mem_web_string = mem_web_string .. "${mem} / ${memmax} -- ${memperc}%\n"
mem_web_string = mem_web_string .. "${memgraph " .. graphs.height .. "," .. graphs.width * graphs.per_line .. "}"

-- [[ Battery graph string ]]
bat_web_string = ""
local battery_nr = has_battery()
if battery_nr > 0 then
	battery_full_path = battery_path.base .. "/" .. battery_path.variants[battery_nr]
	bat_web_string = bat_web_string .. "\n\n" .. bar.char:rep(bar.length) .. "\n"
	bat_web_string = bat_web_string .. "\nBattery\n"
	bat_web_string = bat_web_string .. "${exec cat " .. battery_full_path .. "/status" .. "}"
	if battery_path.has_health then
		bat_web_string = bat_web_string .. " / "
		bat_web_string = bat_web_string .. "${exec cat " .. battery_full_path .. "/health" .. "}"
	end
	bat_web_string = bat_web_string .. " -- "
	bat_web_string = bat_web_string .. "${exec cat " .. battery_full_path .. "/capacity" .. "} %\n"
	bat_web_string = bat_web_string .. "${execbar cat " .. battery_full_path .. "/capacity" .. "}"
end

-- [[ Bundle all the needed variables at init ]]
local init_table = {
	os_name = pregenerated.release,
	os_version = pregenerated.release_version,
	bash_version = "Bash" .. " " .. pregenerated.bash_version,
	bar = bar.char:rep(bar.length),
	cpu_name = pregenerated.cpu_name,
	cpu_graphs = cpu_web_string,
	mem_graph = mem_web_string,
	bat_graph = bat_web_string
}

-- [[ Conky text string with local variable support ]]
local raw_string = [[
Uptime: ${uptime}

#{cpu_name}

#{cpu_graphs}
#{mem_graph}
]]

-- [[ Generate interpolated string ]]
local interpolated_string = string_interpolation(raw_string, init_table)

-- [[ Send interpolated string to conky ]]
conky.text = interpolated_string

-- }}}
