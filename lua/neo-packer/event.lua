local M = {}

local function is_event_config(event)
	return type(event) == "table" and type(event.event) == "string"
end

local function is_event_string(event)
	return type(event) == "string"
end

function M.normalize(source)
	local events = {}

	if is_event_string(source) then
		source = { source }
	elseif type(source) == "table" then
		if is_event_config(source) then
			source = { source }
		end
	else
		source = {}
	end

	for _, e in ipairs(source) do
		local event = {}
		if is_event_string(e) then
			event.event = e
		elseif is_event_config(e) then
			event.event = e.event
			event.pattern = type(e.pattern) == "string" and e.pattern or nil
		end
		table.insert(events, event)
	end

	return events
end

function M.register(plugin)
	local events = plugin.event
	if #events == 0 then
		return
	end

	local group = vim.api.nvim_create_augroup(plugin.name .. ":event", { clear = false })
	for _, event in ipairs(events) do
		local opt = {
			group = group,
			callback = function()
				require("neo-packer.core").load(plugin)
			end,
			pattern = event.pattern,
			once = true,
		}
		vim.api.nvim_create_autocmd(event.event, opt)
	end
end

function M.clean(plugin)
	if #plugin.event == 0 then
		return
	end
	vim.api.nvim_del_augroup_by_name(plugin.name .. ":event")
end

return M
