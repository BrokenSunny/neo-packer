local M = {}
M.plugin_map = {}
M._plugin_map = {}
M.repo_plugin_map = {}
M.local_plugin_map = {}
M.plugin_runtimepath = {}
M.plugin_runtimepath_map = {}

local function is_local_plugin(plugin)
	return plugin.type == "local"
end

local function is_enabled(plugin)
	if plugin.enabled == nil then
		return true
	end
	if type(plugin.enabled) == "function" then
		return plugin.enabled()
	end
	if type(plugin.enabled) == "boolean" then
		return plugin.enabled
	end
end

-- clean something no need in plugin
local function clean_plugin(plugin)
	plugin.right_priority_place = nil
end

-- clean lazy plugin load handle
local function clean_lazy_handle(plugin)
	require("neo-packer.cmd").clean(plugin)
	require("neo-packer.keys").clean(plugin)
	require("neo-packer.event").clean(plugin)
	require("neo-packer.ft").clean(plugin)
	require("neo-packer.colorscheme").clean(plugin)
end

-- execute plugin.config
local function config(plugin)
	if type(plugin.config) == "function" then
		plugin.config()
	end
end

-- register lazy plugin load handle
local function register_lazy_plugin(plugin)
	require("neo-packer.cmd").register(plugin)
	require("neo-packer.keys").register(plugin)
	require("neo-packer.event").register(plugin)
	require("neo-packer.ft").register(plugin)
	require("neo-packer.colorscheme").register(plugin)
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

--[[
  Startup plugin need to use packadd! {plugin_name} or rewirite runtimepath
  to startup.
  But no direct way to config plugin after the plugin "plugin/**/*.lua" sourced
  So I use SourcePost to listen all plugin "plugin/**/*.lua" sourced 
--]]
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

	vim.opt.runtimepath = new_rtps
end

local function create_spec_data(plugin)
	local data = {}
	local repo, e2 = require("neo-packer.repo").normalize(plugin[1])
	if e2 then
		return
	end
	local name, path, e1 = require("neo-packer.name").normalize(plugin.name, repo)
	if e1 then
		return
	end
	local version, e3 = require("neo-packer.version").normalize(plugin.version)
	if e3 then
		return
	end
	-- 1. repo and name
	-- 2. repo no name
	-- 3. name no repo

	if repo then
		data.type = "repo"
	else
		data.type = "local"
	end

	data.startup = true
	data.lazy = plugin.lazy
	data.version = version
	data.name = name
	data.path = path
	data.repo = repo and repo or name
	data.run = type(plugin.run) == "function" and plugin.run or nil
	data.priority = plugin.priority or 50
	data.before = type(plugin.before) == "function" and plugin.before or nil
	data.cmd = require("neo-packer.cmd").normalize(plugin.cmd)
	data.ft = require("neo-packer.ft").normalize(plugin.ft)
	data.event = require("neo-packer.event").normalize(plugin.event)
	data.keys = require("neo-packer.keys").normalize(plugin.keys)
	data.colorscheme = require("neo-packer.colorscheme").normalize(plugin.colorscheme)
	data.depend = require("neo-packer.depend").normalize(plugin.depend)
	data.config = type(plugin.config) == "function" and plugin.config or nil

	if
		data.lazy
		or #data.cmd > 0
		or #data.ft > 0
		or #data.event > 0
		or #data.colorscheme > 0
		or vim.tbl_count(data.keys) > 0
	then
		data.lazy = true
		data.startup = nil
	end

	return data
end

local function create_spec(source)
	if not is_enabled(source) then
		return
	end

	local data = create_spec_data(source)

	if not data then
		return
	end

	local spec = {
		data = data,
	}

	if data.type == "repo" then
		spec.src = "https://github.com/" .. data.repo
		spec.version = data.version
	end

	return spec
end

-- depend need to be sorted by priority(just depend name or not depend spec, Because spec !=== plugin)
local function get_sorted_depends(spec_map, depend, skiped_specs)
	local priority_map = {}
	local priority_list = {}

	for _, name in ipairs(depend) do
		local dp = spec_map[name]

		if not dp then
			dp = create_spec({
				name,
			})
			table.insert(skiped_specs, dp)
			spec_map[name] = dp
		end

		if dp then
			local priority = dp.data.priority
			if not priority_map[priority] then
				priority_map[priority] = { name, priority = priority }
				table.insert(priority_list, priority_map[priority])
			else
				table.insert(priority_map[priority], name)
			end
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

	return depends, skiped_specs
end

-- When a plugin need to startup, so all depends(ALL) need to marked startup
local function set_depend_startup(spec_map, depends)
	local next = {}

	for _, name in ipairs(depends) do
		local dp = spec_map[name]
		if not dp.data.startup then
			table.insert(next, dp.data.depend)
			dp.data.startup = true
		else
		end
	end

	for _, dps in ipairs(next) do
		set_depend_startup(spec_map, dps)
	end
end

local function low_priority_depend_up_plugin(spec_map, spec, all_specs)
	if spec.data.right_priority_place then
		return
	end

	local depends = spec.data.depend
	if #depends > 0 then
		for _, name in ipairs(depends) do
			local dp_spec = spec_map[name]
			low_priority_depend_up_plugin(spec_map, dp_spec, all_specs)
		end
	end
	spec.data.right_priority_place = true
	table.insert(all_specs, spec)
	spec.data.index = #all_specs
end

local function set_spec_depend_startup(specs, spec_map)
	local skiped_specs = {}
	for _, spec in ipairs(specs) do
		local depends = get_sorted_depends(spec_map, spec.data.depend, skiped_specs)
		spec.data.depend = depends
		if spec.data.startup then
			set_depend_startup(spec_map, depends)
		end
	end
	for _, spec in ipairs(skiped_specs) do
		table.insert(specs, spec)
	end
end

--[[
  build repo spec list and all(repo and local) spec list
  spec list: 
    1. sort spec by priority 
      - same priority plugin sort by insert order 
    2. sort spec.depend by priority 
    3. the depend of startup plugin need startup 
      - so all depend of startup plugin need startup 
    4. the low priority depend of startup plugin need insert before the plugin    
    5. some plugin in depend but not in spec list, so add to spec list 
]]

--- @param sources Neo-packer.Plugin[]
local function build_specs(sources)
	sources = vim.tbl_deep_extend("force", {}, sources)

	local specs = {}
	local spec_map = {}
	local spec_priority_list = {}
	local spec_priority_map = {}

	for _, source in ipairs(sources) do
		local spec = create_spec(source)
		if spec then
			spec_map[spec.data.repo] = spec
			local priority = spec.data.priority

			if not spec_priority_map[priority] then
				spec_priority_map[priority] = { spec, priority = priority }
				table.insert(spec_priority_list, spec_priority_map[priority])
			else
				table.insert(spec_priority_map[priority], spec)
			end
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

	set_spec_depend_startup(specs, spec_map)

	local all_specs = {}
	for _, spec in ipairs(specs) do
		if spec.data.startup then
			low_priority_depend_up_plugin(spec_map, spec, all_specs)
		else
			table.insert(all_specs, spec)
			spec.data.index = #all_specs
		end
	end

	local repo_specs = vim.iter(all_specs)
		:filter(function(spec)
			if is_local_plugin(spec.data) then
				return false
			end
			return true
		end)
		:totable()

	return repo_specs, all_specs
end

local function load_depend(plugin)
	for _, depend_name in ipairs(plugin.depend) do
		local dp = M._plugin_map[depend_name]
		if not dp.loaded then
			M.load(dp)
		end
	end
end

function M.load(plugin)
	load_depend(plugin)
	clean_lazy_handle(plugin)
	if type(plugin.before) == "function" then
		plugin.before()
	end
	vim.cmd.packadd(plugin.name)
	config(plugin)
	plugin.loaded = true
	clean_plugin(plugin)
end

local function register_startup_plugin(plugin)
	-- no need reigster lazy handle just real set something, eg: real keymaps
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

local function packadd(spec)
	local plugin = spec.data

	if is_local_plugin(plugin) then
		M.local_plugin_map[plugin.name] = plugin
	else
		M.repo_plugin_map[plugin.name] = plugin
	end
	M.plugin_map[plugin.name] = plugin
	M._plugin_map[plugin.repo] = plugin
	if plugin.startup then
		register_startup_plugin(plugin)
	else
		register_lazy_plugin(plugin)
	end
end

--[[
  local plugins can't in repo spec list 
  so need to process skiped local plugins
  if one or more local plugin in all spec list last
  the last repo plugin need to process the remain local plugins
--]]

local function create_finised_handle(total, all_specs)
	local current = 0
	return function(plug)
		current = current + 1
		if current == total then
			if #all_specs > plug.spec.data.index then
				local skip_specs = vim.list_slice(all_specs, plug.spec.data.index + 1, #all_specs)
				for _, spec in ipairs(skip_specs) do
					packadd(spec)
				end
			end
			rewrite_runtimepath()
		end
	end
end

--[[
  local plugins can't in repo spec list 
  so need to process skiped local plugins
  the every repo loader need to process the skiped local plugins before  
--]]

local function create_skiped_handle(all_specs)
	local pre_index = 0

	return function(plug)
		local current_index = plug.spec.data.index
		if current_index > pre_index + 1 then
			local skip_specs = vim.list_slice(all_specs, pre_index + 1, current_index - 1)
			for _, spec in ipairs(skip_specs) do
				packadd(spec)
			end
		end
		pre_index = current_index
	end
end

local function on_pack_changed()
	vim.api.nvim_create_autocmd("PackChanged", {
		pattern = "*",
		callback = function(e)
			local p = e.data
			local run_task = (p.spec.data or {}).run
			if p.kind ~= "delete" and type(run_task) == "function" then
				pcall(run_task, p)
			end
		end,
	})
end

--- @param plugins Neo-packer.Plugin[]
function M.add(plugins)
	local repo_specs, all_specs = build_specs(plugins)
	local finised_handle = create_finised_handle(#repo_specs, all_specs)
	local skiped_handle = create_skiped_handle(all_specs)
	on_source_post()
	on_pack_changed()
	pcall(vim.pack.add, repo_specs, {
		load = function(plug)
			local spec = plug.spec
			spec.data.path = plug.path
			spec.data.name = plug.spec.name
			skiped_handle(plug)
			packadd(spec)
			finised_handle(plug)
		end,
	})
	-- vim.schedule(function()
	-- 	vim.print(M.plugin_map)
	-- end)
end

function M.get_all_plugin_names()
	return vim.tbl_keys(M.plugin_map)
end

function M.get_all_repo_plugin_names()
	return vim.tbl_keys(M.repo_plugin_map)
end

function M.update(names, opts)
	pcall(vim.pack.update, names, opts)
end

function M.del(names)
	pcall(vim.pack.del, names)
end

return M
