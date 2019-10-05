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

conky.config = {
    alignment = 'top_right',
    background = false,
    border_width = 10,
    cpu_avg_samples = 2,
    default_color = 'white',
    default_outline_color = 'white',
    default_shade_color = 'white',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    extra_newline = false,
    font = 'RobotoMono:size=8',
    gap_x = 60,
    gap_y = 89,
    minimum_height = 5,
    minimum_width = 5,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_transparent = false,
    own_window_argb_visual = true,
    own_window_type = 'desktop',
    own_window_argb_value = 170,
    show_graph_range = false,
    show_graph_scale = false,
    stippled_borders = 0,
    update_interval = 0.25,
    uppercase = false,
    use_spacer = 'none',
    use_xft = true,
}

-- [[ Dev variables ]]
local bar = {
    length = 100,
    char = "-"
}
local graphs = {
    per_line = 4,
    height = 40,
    width = 150
}

-- [[ String interpolation function ]]
local function string_interpolation (string_input, variable_table)
    return string_input:gsub('(#%b{})', function (variable_name)
        return variable_table[variable_name:sub(3, -2)] or variable_name
    end)
end

-- [[ Command execution function ]]
local function run_command (command_string)
    return io.popen(command_string):read()
end

-- [[ Generate the graph web of CPUs ]]
local cpu_count = run_command("grep -c ^processor /proc/cpuinfo")
local cpu_web_string = ""
for i = 0, cpu_count - 1, graphs.per_line do
    -- First part generates all the naming
    for j = 0, graphs.per_line - 1, 1 do
        if j > cpu_count - 1 then break end
        local core_desc = "Core " ..  i + j + 1
        cpu_web_string = cpu_web_string .. core_desc
        if j ~= (graphs.per_line - 1) then
            cpu_web_string = cpu_web_string .. string.rep(" ", 25 - core_desc:len())
        end
    end
    cpu_web_string = cpu_web_string .. "\n"

    -- Second part generates all the frequencies
    for j = 0, graphs.per_line - 1, 1 do
        if j > cpu_count - 1 then break end
        cpu_web_string = cpu_web_string .. "${freq" .. " " ..  i + j + 1 .. "} MHz"
        if j ~= (graphs.per_line - 1) then
            cpu_web_string = cpu_web_string .. string.rep(" ", 17)
        end
    end
    cpu_web_string = cpu_web_string .. "\n"

    -- Third part generates all the actual graphs
    for j = 0, graphs.per_line - 1, 1 do
        if j > cpu_count - 1 then break end
        cpu_web_string = cpu_web_string .. "${cpugraph" .. " " .. "cpu" .. i + j + 1 .. " " .. graphs.height .. "," .. graphs.width .. "}"
    end
    cpu_web_string = cpu_web_string .. "\n"
end
cpu_web_string = cpu_web_string .. "All Cores\n" .. "${freq cpu0} MHz\n"
cpu_web_string = cpu_web_string .. "${cpugraph cpu0 " .. graphs.height .. "," .. graphs.width * graphs.per_line .. "}"

-- [[ Memory graph string ]]
mem_web_string = "Memory\n"
mem_web_string = mem_web_string .. "${mem} / ${memmax} -- ${memperc}%\n"
mem_web_string = mem_web_string .. "${memgraph " .. graphs.height .. "," .. graphs.width * graphs.per_line .. "}"

-- [[ Bundle all the needed variables at init ]]
local init_table = {
    os_name = run_command("lsb_release -sd"):gsub('"', ""),
    bash_version = "Bash" .. " " .. run_command("bash -c 'echo $BASH_VERSION'"),
    bar = bar.char:rep(bar.length),
    cpu_name = run_command("cat /proc/cpuinfo | grep 'model name' | uniq | cut -f 2 -d ':' | awk '{$1=$1}1'"),
    cpu_graphs = cpu_web_string,
    mem_graph = mem_web_string
}

-- [[ Conky text string with local variable support ]]
local raw_string = [[
Kernel: ${kernel}
OS: #{os_name} ${exec lsb_release -s}
Uptime: ${uptime}
Shell: #{bash_version}

#{bar}

#{cpu_name}

#{cpu_graphs}

#{bar}

#{mem_graph}

]]

-- [[ Generate interpolated string ]]
local interpolated_string = string_interpolation(raw_string, init_table)

-- [[ Send interpolated string to conky ]]
conky.text = interpolated_string
