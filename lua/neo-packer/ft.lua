local M = {}

function M.normalize(source)
	local fts = {}

	if type(source) == "string" then
		source = { source }
	elseif type(source) == "table" then
		source = source
	else
		source = {}
	end

	for _, ft in ipairs(source) do
		if type(ft) == "string" then
			fts[#fts + 1] = ft
		end
	end

	return fts
end

local function register(plugin)
	vim.api.nvim_create_autocmd("FileType", {
		pattern = plugin.ft,
		callback = function()
			require("neo-packer.core").load(plugin.name)
		end,
		once = true,
	})
end

function M.register(plugin)
	local fts = plugin.ft

	for _, ft in ipairs(fts) do
		register(ft)
	end
end

return M
