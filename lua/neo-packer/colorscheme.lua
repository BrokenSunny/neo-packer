local M = {}

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

function M.register(plugin)
  local colorschemes = plugin.colorscheme
  if #colorschemes == 0 then
    return
  end

  local group = vim.api.nvim_create_augroup(plugin.name .. ":colorscheme", { clear = true })
  vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = group,
    callback = function(e)
      local colorscheme = e.match
      if vim.list_contains(colorschemes, colorscheme) then
        require("neo-packer.core").load(plugin)
        return true
      end
    end,
    nested = true,
  })
end

function M.clean(plugin)
  if #plugin.colorscheme == 0 then
    return
  end
  pcall(vim.api.nvim_del_augroup_by_name, plugin.name .. ":colorscheme")
end

return M
