local M = {}

function M.normalize(cmd)
	local cmds = {}

	if type(cmd) == "string" then
		cmds = { cmd }
	end

	if type(cmd) == "table" then
		for _, c in ipairs(cmd) do
			if type(c) == "string" then
				cmds[#cmds + 1] = c
			end
		end
	end

	return cmds
end

local function register(cmd, loader)
	vim.api.nvim_create_user_command(cmd, function(event)
		---@cast event vim.api.keyset.user_command
		local command = {
			cmd = cmd,
			bang = event.bang or nil,
			---@diagnostic disable-next-line: undefined-field
			mods = event.smods,
			---@diagnostic disable-next-line: undefined-field
			args = event.fargs,
			count = event.count >= 0 and event.range == 0 and event.count or nil,
		}

		if event.range == 1 then
			---@diagnostic disable-next-line: undefined-field
			command.range = { event.line1 }
		elseif event.range == 2 then
			---@diagnostic disable-next-line: undefined-field
			command.range = { event.line1, event.line2 }
		end

		loader()

		local info = vim.api.nvim_get_commands({})[cmd] or vim.api.nvim_buf_get_commands(0, {})[cmd]
		if not info then
			return
		end
		command.nargs = info.nargs
		---@diagnostic disable-next-line: undefined-field
		if event.args and event.args ~= "" and info.nargs and info.nargs:find("[1?]") then
			---@diagnostic disable-next-line: undefined-field
			command.args = { event.args }
		end

		vim.cmd(command)
	end, {
		bang = true,
		range = true,
		nargs = "*",
		complete = function(_, line)
			loader()
			return vim.fn.getcompletion(line, "cmdline")
		end,
	})
end

function M.register(plugin)
	local cmds = plugin.cmd
	for _, cmd in ipairs(cmds) do
		register(cmd, function()
			require("neo-packer.core").load(plugin.name)
		end)
	end
end

function M.clean(plugin)
	for _, cmd in ipairs(plugin.cmd) do
		pcall(vim.api.nvim_del_user_command, cmd)
	end
end

return M
