local M = {}

--- @class Neo-packer.Plugin.Key.Mode.Config: vim.keymap.set.Opts
--- @field [integer] string|Neo-packer.Plugin.Key.Mode.Config

--- @alias Neo-packer.Plugin.Key.Mode
--- |string
--- |Neo-packer.Plugin.Key.Mode.Config

--- @class Neo-packer.Plugin.OneModeKey: vim.keymap.set.Opts
--- @field [1] string|fun()
--- @field [2] Neo-packer.Plugin.Key.Mode

--- @class Neo-packer.Plugin.MultiModeKey: vim.keymap.set.Opts
--- @field [integer] Neo-packer.Plugin.OneModeKey

--- @alias Neo-packer.Plugin.Key
--- | Neo-packer.Plugin.OneModeKey
--- | Neo-packer.Plugin.MultiModeKey
--- @alias Neo-packer.Plugin.Cmd string|string[]
--- @alias Neo-packer.Plugin.Ft string|string[]
--- @alias Neo-packer.Plugin.Colorscheme string|string[]
--- @alias Neo-packer.Plugin.Event
---   | string
---   | string[]
---   | { event: string, pattern?: string }
---   | { event: string, pattern?: string }[]
--- @alias Neo-packer.Plugin.Keys table<string, Neo-packer.Plugin.Key>

--- @class Neo-packer.Plugin.PluginSpec
--- @field config? fun()
--- @field before? fun()
--- @field enabled? boolean|fun():boolean
--- @field priority? number
--- @field event? Neo-packer.Plugin.Event
--- @field cmd? Neo-packer.Plugin.Cmd
--- @field ft? Neo-packer.Plugin.Ft
--- @field keys? Neo-packer.Plugin.Keys
--- @field depend? string | string[]
--- @field colorscheme? Neo-packer.Plugin.Colorscheme
--- @field version? string|vim.VersionRange
--- @field name? string

--- @class Neo-packer.Plugin.LocalPlugin: Neo-packer.Plugin.PluginSpec
--- @field dir string

--- @class Neo-packer.RemotePlugin: Neo-packer.Plugin.PluginSpec
--- @field [1] string

--- @alias Neo-packer.Plugin
--- | Neo-packer.Plugin.LocalPlugin
--- | Neo-packer.RemotePlugin

--- @param plugins Neo-packer.Plugin[]
function M.setup(plugins)
	require("neo-packer.core").add(plugins)
end

return M
