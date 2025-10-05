local M = {}

function M.normalize(source)
	local depends = {}

	if type(source) == "string" then
		source = { source }
	elseif type(source) == "table" then
		source = source
	else
		source = {}
	end

	for _, d in ipairs(source) do
		if type(d) == "string" then
			depends[#depends + 1] = d
		end
	end

	return depends
end

return M
