local M = {}

function M.normalize(source, dir)
	local error
	local repo

	if type(source) == "string" then
		repo = source
	else
		if not dir then
			vim.notify("neo-packer: plugin repo is not a string", vim.log.levels.ERROR)
			error = true
		end
	end

	return repo, error
end

return M
