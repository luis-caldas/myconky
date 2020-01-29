-- [[ Custom functions to be used by conky ]]
local SEPARATOR = " "
local MAX_NUMBERS_FREQ = 4

-- [[ String string function ]]
function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) table.insert(fields, c) end)
	return fields
end

-- [[ Command execution function ]]
local function run_command (command_string)
    return io.popen(command_string):read('*a'):sub(1, -2)
end

-- [[ Functions to be passed to conky ]]
function conky_get_core(core_number_input)
	-- Translate strings to usable numbers
	local core_number = tonumber(core_number_input)

	-- Initialize var
	local freq_now = ""

	-- Acquire the cpu freqs
	if core_number == 0 then
		freq_now = run_command("lscpu | grep \"CPU MHz\" | awk '{print $3}'")
	else
		freq_now = run_command("grep 'cpu MHz' /proc/cpuinfo | awk '{print $4}'"):split("\n")[core_number]
	end

	-- Add a leading padding if the frequency has not 4 numbers
	local first_number_len = freq_now:split(".")[1]:len()
	if first_number_len < MAX_NUMBERS_FREQ then
		freq_now = string.rep(SEPARATOR, MAX_NUMBERS_FREQ - first_number_len) .. freq_now
	end

	-- Return the frequency
	return freq_now
end

function conky_justify(string_input, total_size_input)
	-- Sanitize inputs
	local total_size = tonumber(total_size_input)
	local len_string = string_input:len()

	-- Create output string
	local out_string = ""

	-- Add the padding if the given size is greater than the input string
	if total_size > len_string then
		out_string = string_input .. string.rep(SEPARATOR, total_size - len_string)
	else
		out_string = string_input
	end

	-- Return the string
	return out_string
end

-- Join functions for ease of use
function conky_justify_core(core_number_input, total_size_input)
	return conky_justify(conky_get_core(core_number_input) .. " MHz", total_size_input)
end
