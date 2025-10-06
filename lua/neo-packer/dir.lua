local M = {}

function M.normalize(source)
	local dir = source
	local error

	if source ~= nil then
		if type(source) ~= "string" then
			dir = nil
			error = true
			vim.notify("neo-packer: dir is not a string", vim.log.levels.ERROR)
		else
			local stat = vim.loop.fs_stat(source)
			if not stat or (stat and stat.type ~= "directory") then
				dir = nil
				error = true
				vim.notify("neo-packer: dir:" .. source .. " not exist or not a directory", vim.log.levels.ERROR)
			end
		end
	end
	return dir, error
end

return M
