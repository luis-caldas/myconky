--[[
Conky, a system monitor, based on torsmo

Any original torsmo code is licensed under the BSD license

All code written since the fork of torsmo is licensed under the GPL

Please see COPYING for details

Copyright (c) 2004, Hannu Saransaari and Lauri Hakkarainen
Copyright (c) 2005-2019 Brenden Matthews, Philip Kovacs, et. al. (see AUTHORS)
All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- [[ Dev variables ]]
local bar = {
    length = 100,
    char = "-"
}
local graphs = {
    per_line = 4,
    height = 50,
    width = 175
}
local devices = {
    battery = "/sys/class/power_supply/rk-bat"
}

conky.config = {
    alignment = 'top_right',
    background = false,
    border_width = 20,
    cpu_avg_samples = 2,
    default_bar_height = graphs.height,
    default_color = 'white',
    default_outline_color = 'white',
    default_shade_color = 'white',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    extra_newline = false,
    font = 'RobotoMono:size=9',
    gap_x = 100,
    gap_y = 126,
    minimum_height = 5,
    minimum_width = 5,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_colour = '0D0D0D',
    own_window_transparent = false,
    own_window_argb_visual = true,
    own_window_type = 'desktop',
    own_window_argb_value = 240,
    show_graph_range = false,
    show_graph_scale = false,
    stippled_borders = 0,
    update_interval = 1,
    uppercase = false,
    use_spacer = 'none',
    use_xft = true,
	lua_load = '~/.conkyrc.functions.lua'
}

-- [[ Command execution function ]]
local function run_command (command_string)
    return io.popen(command_string):read('*a'):sub(1, -2)
end

-- [[ Check if the system has battery ]]
local function has_battery()
    return run_command("test -d " .. devices.battery .. " && echo true || echo false") == "true"
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
cpu_web_string = cpu_web_string .. "All Cores\n" .. "${lua gover_all}\n" .. "${lua conky_justify_core 0 25}" .. "\n"
cpu_web_string = cpu_web_string .. "${cpugraph cpu0 " .. graphs.height .. "," .. graphs.width * graphs.per_line .. "}"

-- [[ Memory graph string ]]
mem_web_string = "Memory\n"
mem_web_string = mem_web_string .. "${mem} / ${memmax} -- ${memperc}%\n"
mem_web_string = mem_web_string .. "${memgraph " .. graphs.height .. "," .. graphs.width * graphs.per_line .. "}"

-- [[ Battery graph string ]]
bat_web_string = ""
if has_battery() then
    bat_web_string = bat_web_string .. "\n\n" .. bar.char:rep(bar.length) .. "\n"
    bat_web_string = bat_web_string .. "\nBattery\n"
    bat_web_string = bat_web_string .. "${exec cat " .. devices.battery .. "/status" .. "}"
    bat_web_string = bat_web_string .. " / "
    bat_web_string = bat_web_string .. "${exec cat " .. devices.battery .. "/health" .. "}"
    bat_web_string = bat_web_string .. " -- "
    bat_web_string = bat_web_string .. "${exec cat " .. devices.battery .. "/capacity" .. "} %\n"
    bat_web_string = bat_web_string .. "${execbar cat " .. devices.battery .. "/capacity" .. "}"
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
Kernel: ${kernel}
OS: #{os_name} #{os_version}
Uptime: ${uptime}
Shell: #{bash_version}

#{bar}

#{cpu_name}

#{cpu_graphs}

#{bar}

#{mem_graph}#{bat_graph}
]]

-- [[ Generate interpolated string ]]
local interpolated_string = string_interpolation(raw_string, init_table)

-- [[ Send interpolated string to conky ]]
conky.text = interpolated_string
