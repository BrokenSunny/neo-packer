local M = {}
M.plugin_map = {}
M.plugin_runtimepath = {}
M.plugin_runtimepath_map = {}

local function config_plugin(plugin)
	if not plugin then
		return
	end
	M.plugin_runtimepath_map[plugin.path] = nil

	if type(plugin.config) ~= "function" then
		return
	end
	plugin.config()
end

local function fix_start_missing_plugin_dir(start, finish)
	local paths = vim.list_slice(M.plugin_runtimepath, start, finish)
	for _, path in ipairs(paths) do
		config_plugin(M.plugin_runtimepath_map[path].plugin)
	end
end

local function fix_next_missing_plugin_dir(next)
	if next > #M.plugin_runtimepath then
		return
	end

	local plugins = {}

	for i = next, #M.plugin_runtimepath do
		local path = M.plugin_runtimepath[i]
		local data = M.plugin_runtimepath_map[path]
		if data.total == 0 then
			table.insert(plugins, data)
		else
			break
		end
	end
	for _, data in ipairs(plugins) do
		config_plugin(data.plugin)
	end
end

local function on_source_post()
	local first
	vim.api.nvim_create_autocmd("SourcePost", {
		pattern = "*/plugin/*.lua",
		callback = function(e)
			if vim.tbl_count(M.plugin_runtimepath_map) == 0 then
				return true
			end

			local path = e.file:match("^(.-)/plugin/")
			local data = M.plugin_runtimepath_map[path]
			if data then
				if not first then
					fix_start_missing_plugin_dir(1, data.index - 1)
					first = true
				end
				data.finished = data.finished + 1
				if data.finished == data.total then
					config_plugin(data.plugin)
					fix_next_missing_plugin_dir(data.index + 1)
				end
			end
		end,
	})
end

local function rewrite_runtimepath()
	local rtps = vim.opt.runtimepath:get()
	local new_rtps = {}
	local index

	for _, path in ipairs(rtps) do
		if not M.plugin_runtimepath_map[path] then
			table.insert(new_rtps, path)
		end
		if not index and vim.fn.fnamemodify(path, ":t") == "neo-packer" then
			index = #new_rtps
		end
	end

	if index then
		for _, p in ipairs(M.plugin_runtimepath) do
			table.insert(new_rtps, index + 1, p)
			index = index + 1
		end
	end
	vim.opt.runtimepath = new_rtps
end

local function get_sorted_depend_specs(spec_map, depend)
	local depend_priority_map = {}
	local depend_priority_list = {}

	for _, name in ipairs(depend) do
		local dp = spec_map[name]
		local priority = dp.data.priority or 50
		if not depend_priority_map[priority] then
			depend_priority_map[priority] = { dp, priority = priority }
			table.insert(depend_priority_list, depend_priority_map[priority])
		else
			table.insert(depend_priority_map[priority], dp)
		end
	end
	table.sort(depend_priority_list, function(a, b)
		return a.priority > b.priority
	end)

	local depend_specs = {}
	for _, dps in ipairs(depend_priority_list) do
		for _, dp in ipairs(dps) do
			table.insert(depend_specs, dp)
		end
	end

	return depend_specs
end

local function set_depend_startup(spec_map, depend_specs)
	local next = {}

	for _, dp in ipairs(depend_specs) do
		if not dp.data.startup then
			table.insert(next, dp.data.depend_specs)
			dp.data.startup = true
		else
		end
	end

	for _, dps in ipairs(next) do
		set_depend_startup(spec_map, dps)
	end
end

local function normalize(plugin)
	plugin.cmd = require("neo-packer.cmd").normalize(plugin.cmd)
	plugin.ft = require("neo-packer.ft").normalize(plugin.ft)
	plugin.event = require("neo-packer.event").normalize(plugin.event)
	plugin.keys = require("neo-packer.keys").normalize(plugin.keys)
	plugin.colorscheme = require("neo-packer.colorscheme").normalize(plugin.colorscheme)
	plugin.depend = require("neo-packer.depend").normalize(plugin.depend)
end

local function final_sort(spec, _specs)
	if spec.data.is_pending then
		return
	end

	local depend_specs = spec.data.depend_specs
	if #depend_specs > 0 then
		for _, dp_spec in ipairs(depend_specs) do
			final_sort(dp_spec, _specs)
		end
	end
	spec.data.is_pending = true
	table.insert(_specs, spec)
end

local function get_spec_data(plugin)
	local data = {
		_name = plugin[1],
		startup = true,
		lazy = nil,
	}
	for k, v in pairs(plugin) do
		if type(k) ~= "number" then
			data[k] = v
		end
	end
	normalize(data)

	if #data.cmd > 0 or #data.ft > 0 or #data.event > 0 or #data.colorscheme > 0 or vim.tbl_count(data.keys) > 0 then
		data.lazy = true
		data.startup = nil
	end

	return data
end

local function create_spec(source)
	local data = get_spec_data(source)
	local spec = {
		src = "https://github.com/" .. data._name,
		data = data,
		version = source.version,
	}
	return spec
end

--- @param sources Neo-packer.Plugin[]
local function build_specs(sources)
	sources = vim.tbl_deep_extend("force", {}, sources)

	local specs = {}
	local spec_map = {}
	local spec_priority_list = {}
	local spec_priority_map = {}

	for _, source in ipairs(sources) do
		local spec = create_spec(source)
		spec_map[spec.data._name] = spec

		local priority = spec.data.priority or 50
		if not spec_priority_map[priority] then
			spec_priority_map[priority] = { spec, priority = priority }
			table.insert(spec_priority_list, spec_priority_map[priority])
		else
			table.insert(spec_priority_map[priority], spec)
		end
	end
	table.sort(spec_priority_list, function(a, b)
		return a.priority > b.priority
	end)
	for _, item in ipairs(spec_priority_list) do
		for _, spec in ipairs(item) do
			table.insert(specs, spec)
		end
	end

	for _, spec in ipairs(specs) do
		local depend_specs = get_sorted_depend_specs(spec_map, spec.data.depend)
		spec.data.depend_specs = depend_specs
		if spec.data.startup then
			set_depend_startup(spec_map, depend_specs)
		end
	end

	local _specs = {}
	for _, spec in ipairs(specs) do
		if spec.data.startup then
			final_sort(spec, _specs)
		else
			table.insert(_specs, spec)
		end
	end
	return _specs
end

function M._load(name)
	local plugin = M.plugin_map[name]
	if not plugin then
		return
	end

	for _, depend_spec in ipairs(plugin.depend_specs) do
	end

	require("neo-packer.cmd").clean(plugin)
	pcall(vim.cmd.packadd, name)
end

--- @param plugins Neo-packer.Plugin[]
function M.load(plugins)
	local specs = build_specs(plugins)
	local total = #specs
	local current = 0
	on_source_post()
	pcall(vim.pack.add, specs, {
		load = function(plug)
			local plugin = plug.spec.data
			plugin.name = plug.spec.name
			plugin.path = plug.path
			M.plugin_map[plugin.name] = plugin

			if plugin.startup then
				plugin.depend_specs = nil
				if plugin.lazy then
				end
				table.insert(M.plugin_runtimepath, plugin.path)
				M.plugin_runtimepath_map[plugin.path] = {
					index = #M.plugin_runtimepath,
					plugin = plugin,
					total = #vim.fn.glob(plugin.path .. "*/plugin/**/*.lua", true, true),
					finished = 0,
				}
			else
				if plugin.lazy then
					require("neo-packer.cmd").register(plugin)
					require("neo-packer.keys").register(plugin)
					require("neo-packer.event").register(plugin)
					require("neo-packer.ft").register(plugin)
					require("neo-packer.colorscheme").register(plugin)
				end
			end

			current = current + 1
			if current == total then
				rewrite_runtimepath()
			end
		end,
		confirm = true,
	})
end

function M.update() end

function M.del() end

return M
