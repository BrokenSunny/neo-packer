local M = {
	keymaps = {},
	filetypes = {},
	events = {},
}

local KeymapOptsMap = {
	noremap = true,
	nowait = true,
	silent = true,
	script = true,
	expr = true,
	unique = true,
	callback = true,
	desc = true,
	replace_keycodes = true,
	buffer = true,
	remap = true,
}

function M.normalize(source)
	local keys = source
	if type(source) ~= "table" then
		keys = {}
	end

	return keys
end

local function collect_filetype_keymap(filetype, callback)
	if type(filetype) == "string" then
		M.filetypes[filetype] = M.filetypes[filetype] or {}
		table.insert(M.filetypes[filetype], function()
			callback()
		end)
		return
	end

	if type(filetype) == "table" then
		for _, ft in ipairs(filetype) do
			collect_filetype_keymap(ft, callback)
		end
	end
end

local function collect_event_keymap(event, callback)
	if type(event) == "string" then
		M.events[event] = M.events[event] or {}
		table.insert(M.events[event], callback)
		return
	end

	if type(event) == "table" then
		for _, e in ipairs(event) do
			collect_event_keymap(e, callback)
		end
	end
end

local function get_opts(data)
	local opts = {}
	for key, value in pairs(data) do
		if type(key) == "string" then
			opts[key] = value
		end
	end

	return opts
end

local function get_keymap_opts(opts)
	local keymap_opts = {}
	for key, value in pairs(opts) do
		if KeymapOptsMap[key] then
			keymap_opts[key] = value
		end
	end
	return keymap_opts
end

--- @param rhs any
--- @return boolean
local function is_rhs(rhs)
	return type(rhs) == "string" or type(rhs) == "function"
end

local function set_keymap(lhs, rhs, mode, opts, load)
	if not is_rhs(rhs) then
		vim.notify("rhs must be string or function")
		return
	end

	if type(mode) ~= "string" then
		vim.notify("mode must be string or table<string>")
		return
	end

	local keymap_opts = get_keymap_opts(opts)

	if not M.keymaps[lhs] then
		M.keymaps[lhs] = {
			[mode] = {
				rhs = rhs,
			},
		}
	else
		M.keymaps[lhs][mode] = {
			rhs = rhs,
		}
	end

	M.keymaps[lhs][mode] = vim.tbl_extend("force", M.keymaps[lhs][mode], opts)

	if opts.filetype then
		collect_filetype_keymap(opts.filetype, function()
			pcall(vim.keymap.set, mode, lhs, rhs, keymap_opts)
		end)
		return
	end

	if opts.event then
		collect_event_keymap(opts.event, function()
			pcall(vim.keymap.set, mode, lhs, rhs, keymap_opts)
		end)
		return
	end

	pcall(vim.keymap.set, mode, lhs, function()
		load()
		vim.keymap.set(mode, lhs, rhs, keymap_opts)
		lhs = vim.api.nvim_replace_termcodes(lhs, true, true, true)
		vim.api.nvim_feedkeys(lhs, "m", false)
	end, keymap_opts)
end

local function parse_mode(lhs, rhs, modes, parent_opts, load)
	local opts = vim.tbl_extend("force", parent_opts, get_opts(modes))
	for _, mode in ipairs(modes) do
		if type(mode) == "string" then
			set_keymap(lhs, rhs, mode, opts, load)
		elseif type(mode) == "table" then
			parse_mode(lhs, rhs, mode, opts, load)
		end
	end
end

local function parse_one_rhs(lhs, data, parent_opts, load)
	local rhs = data[1]
	local mode = data[2]
	local opts = vim.tbl_extend("force", parent_opts, get_opts(data))

	if type(mode) == "string" then
		set_keymap(lhs, rhs, mode, opts, load)
	elseif type(mode) == "table" then
		parse_mode(lhs, rhs, mode, opts, load)
	end
end

local function parse_more_rhs(lhs, data, parent_opts, load)
	local opts = vim.tbl_extend("force", parent_opts, get_opts(data))
	for _, value in ipairs(data) do
		parse_one_rhs(lhs, value, opts, load)
	end
end

local function parse_keymap(lhs, data, load)
	if type(data) ~= "table" then
		vim.notify("lhs = value must be table")
		return
	end

	local opts = get_opts(data)

	if type(data[1]) == "table" then
		parse_more_rhs(lhs, data, opts, load)
	elseif is_rhs(data[1]) then
		parse_one_rhs(lhs, data, opts, load)
	end
end

function M.register(plugin)
	local keys = plugin.keys

	for lhs, data in pairs(keys) do
		parse_keymap(lhs, data, function()
			require("neo-packer.core")._load(plugin.name)
		end)
	end
end

return M
