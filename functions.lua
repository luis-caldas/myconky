-- [[ Custom functions to be used by conky ]]
local SEPARATOR = " "
local MAX_NUMBERS_FREQ = 4
local STRING_FORMAT = "%.3f"

local CPU_FOLDER = "/sys/devices/system/cpu"

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

-- [[ Mean function ]]
function average(table)
	local sum = 0
	for i = 1, #table do
		sum = sum + table[i]
	end
	return sum/#table
end


-- [[ Functions to be passed to conky ]]
function conky_get_core(core_number_input)
	-- Translate strings to usable numbers
	local core_number = tonumber(core_number_input)

	-- Initialize var
	local freq_now = nil

	-- Acquire the cpu freqs
	local freq_list = run_command("grep 'cpu MHz' /proc/cpuinfo | awk '{print $4}'"):split("\n")

	-- Check if a average is needed or a specific frequency
	if core_number == 0 then
		freq_now = string.format(STRING_FORMAT, average(freq_list))
	else
		freq_now = freq_list[core_number]
	end

	-- Check if the method before was successful and if not get frequency through other methods
	if freq_now == nil or freq_now == "" then
		if core_number > 0 then
			freq_now = string.format(
				STRING_FORMAT,
				tonumber(run_command("cat /sys/devices/system/cpu/cpu" .. core_number - 1 .. "/cpufreq/scaling_cur_freq")) / 1000
			)
		end
	end

	-- Add a leading padding if the frequency has not 4 numbers
	if freq_now ~= nil and freq_now ~= "" then
		local first_number_len = freq_now:split(".")[1]:len()
		if first_number_len < MAX_NUMBERS_FREQ then
			freq_now = string.rep(SEPARATOR, MAX_NUMBERS_FREQ - first_number_len) .. freq_now
		end
	else
		freq_now = "Undefined"
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

-- List the processor governor
function conky_justify_gover(core_number_input, total_size_input)
	return conky_justify(run_command("cat " .. CPU_FOLDER .. "/cpu" .. tonumber(core_number_input) - 1 .. "/cpufreq/scaling_governor"), total_size_input)
end

-- List the governor of all processors
function conky_gover_all()
	-- Check if all the governors are the same
	local governor_count = run_command("cat " .. CPU_FOLDER .. "/cpu*/cpufreq/scaling_governor | uniq | wc -l")

	-- Output string
	local return_string = ""

	-- If they are the same print the first
	if governor_count == "1" then
		return_string = run_command("cat " .. CPU_FOLDER .. "/cpu0/cpufreq/scaling_governor")
	else
		return_string = "mixed"
	end

	return return_string
end
