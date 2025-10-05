local M = {}

function M.register(colorscheme) end

function M.normalize(source)
	local colorschemes = {}

	if type(source) == "string" then
		source = { source }
	elseif type(source) == "table" then
		source = source
	else
		source = {}
	end

	for _, d in ipairs(source) do
		if type(d) == "string" then
			colorschemes[#colorschemes + 1] = d
		end
	end

	return colorschemes
end

return M
