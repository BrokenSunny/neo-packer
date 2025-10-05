local M = {}
M.plugin_map = {}
M._plugin_map = {}
M.plugin_runtimepath = {}
M.plugin_runtimepath_map = {}

-- clean something no need in plugin
local function clean_plugin(plugin)
	plugin._depend = nil
	plugin.is_pending = nil
end

-- clean lazy plugin load handle
local function clean_lazy_handle(plugin)
	require("neo-packer.cmd").clean(plugin)
end

-- register lazy plugin load handle
local function register_lazy_plugin(plugin)
	require("neo-packer.cmd").register(plugin)
	require("neo-packer.keys").register(plugin)
	require("neo-packer.event").register(plugin)
	require("neo-packer.ft").register(plugin)
	require("neo-packer.colorscheme").register(plugin)
end

-- execute plugin.config
local function config(plugin)
	if type(plugin.config) == "function" then
		plugin.config()
	end
end

local function on_plugin_source_post(plugin)
	M.plugin_runtimepath_map[plugin.path] = nil
	config(plugin)
	clean_plugin(plugin)
end

-- Some plugins no "plugin/*.lua" dir
-- Can't trigger source post. And Can't execute plugin.config
-- So the fisrt plugin which have "plugin/*.lua" need to fix pre plugins to execute plugin.config
local function fix_start_missing_plugin_dir(start, finish)
	local paths = vim.list_slice(M.plugin_runtimepath, start, finish)
	for _, path in ipairs(paths) do
		on_plugin_source_post(M.plugin_runtimepath_map[path].plugin)
	end
end

-- Same as above, but help next plugin
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
		on_plugin_source_post(data.plugin)
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
					on_plugin_source_post(data.plugin)
					fix_next_missing_plugin_dir(data.index + 1)
				end
			end
		end,
	})
end

-- packadd! {name} can't process priority: I sort plugin to packadd! {plugin_name}
-- But seem at some time the runtimepath had sorted
-- So I sort this has no effect
-- So I need rewrite runtimepath
--   1. get current runtimepath
--   2. reset runtimepath
--   3. get plugin sorted runtimepath
--   4. insert 3. to 2.
--   5. replaced the old rtp
local function rewrite_runtimepath()
	-- 1. get current runtimepath
	local rtps = vim.opt.runtimepath:get()
	local new_rtps = {}

	-- 2. reset runtimepath
	local index
	for _, path in ipairs(rtps) do
		if not M.plugin_runtimepath_map[path] then
			table.insert(new_rtps, path)
		end
		if not index and vim.fn.fnamemodify(path, ":t") == "neo-packer" then
			index = #new_rtps
		end
	end

	-- 3
	-- 4.
	if index then
		for _, p in ipairs(M.plugin_runtimepath) do
			table.insert(new_rtps, index + 1, p)
			index = index + 1
		end
	end

	-- 5.
	vim.opt.runtimepath = new_rtps
end

-- depend need to be sorted by priority(just depend name or not depend spec, Because spec !=== plugin)
local function get_sorted_depends(spec_map, depend)
	local priority_map = {}
	local priority_list = {}

	for _, name in ipairs(depend) do
		local dp = spec_map[name]
		local priority = dp.data.priority or 50
		if not priority_map[priority] then
			priority_map[priority] = { name, priority = priority }
			table.insert(priority_list, priority_map[priority])
		else
			table.insert(priority_map[priority], name)
		end
	end
	table.sort(priority_list, function(a, b)
		return a.priority > b.priority
	end)

	local depends = {}
	for _, dps in ipairs(priority_list) do
		for _, name in ipairs(dps) do
			table.insert(depends, name)
		end
	end

	return depends
end

-- When a plugin need to startup, so all depends(ALL) need to marked startup
local function set_depend_startup(spec_map, depends)
	local next = {}

	for _, name in ipairs(depends) do
		local dp = spec_map[name]
		if not dp.data.startup then
			table.insert(next, dp.data._depend)
			dp.data.startup = true
		else
		end
	end

	for _, dps in ipairs(next) do
		set_depend_startup(spec_map, dps)
	end
end

--- Change single to table<single>
local function normalize(plugin)
	plugin.cmd = require("neo-packer.cmd").normalize(plugin.cmd)
	plugin.ft = require("neo-packer.ft").normalize(plugin.ft)
	plugin.event = require("neo-packer.event").normalize(plugin.event)
	plugin.keys = require("neo-packer.keys").normalize(plugin.keys)
	plugin.colorscheme = require("neo-packer.colorscheme").normalize(plugin.colorscheme)
	plugin.depend = require("neo-packer.depend").normalize(plugin.depend)
end

local function low_priority_depend_up_plugin(spec_map, spec, _specs)
	if spec.data.is_pending then
		return
	end

	local depends = spec.data._depend
	if #depends > 0 then
		for _, name in ipairs(depends) do
			local dp_spec = spec_map[name]
			low_priority_depend_up_plugin(spec_map, dp_spec, _specs)
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
		local depends = get_sorted_depends(spec_map, spec.data.depend)
		spec.data._depend = depends
		if spec.data.startup then
			set_depend_startup(spec_map, depends)
		end
	end

	local _specs = {}
	for _, spec in ipairs(specs) do
		if spec.data.startup then
			low_priority_depend_up_plugin(spec_map, spec, _specs)
		else
			table.insert(_specs, spec)
		end
	end
	return _specs
end

local function load_depend(plugin)
	for _, depend_name in ipairs(plugin._depend) do
		local dp = M._plugin_map[depend_name]
		if not dp.loaded then
			M.load(dp.name)
		end
	end
end

function M.load(plugin)
	load_depend(plugin)
	pcall(vim.cmd.packadd, plugin.name)
	config(plugin)
	clean_lazy_handle(plugin)
	clean_plugin(plugin)
end

local function create_runtimepath_rewriter(total)
	local current = 0
	return function()
		current = current + 1
		if current == total then
			rewrite_runtimepath()
		end
	end
end

local function register_startup_plugin(plugin)
	if plugin.lazy then
		require("neo-packer.keys").add(plugin.keys)
	end
	table.insert(M.plugin_runtimepath, plugin.path)
	M.plugin_runtimepath_map[plugin.path] = {
		index = #M.plugin_runtimepath,
		plugin = plugin,
		total = #vim.fn.glob(plugin.path .. "*/plugin/**/*.lua", true, true),
		finished = 0,
	}
	plugin.loaded = true
end

--- @param plugins Neo-packer.Plugin[]
function M.packadd(plugins)
	local specs = build_specs(plugins)
	local runtimepath_rewriter = create_runtimepath_rewriter(#specs)
	on_source_post()
	pcall(vim.pack.add, specs, {
		load = function(plug)
			local plugin = plug.spec.data
			plugin.name = plug.spec.name
			plugin.path = plug.path
			-- This name is pack name(for pack name find plugin)
			M.plugin_map[plugin.name] = plugin
			-- This name is source name(for depend find plugin)
			M._plugin_map[plugin._name] = plugin

			if plugin.startup then
				register_startup_plugin(plugin)
			else
				register_lazy_plugin(plugin)
			end
			runtimepath_rewriter()
		end,
	})
end

function M.update() end

function M.del() end

return M
