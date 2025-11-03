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
    else
      vim.notify("neo-packer: ft: string | string[]", vim.log.levels.ERROR)
    end
  end

  return fts
end

function M.register(plugin)
  local fts = plugin.ft
  if #fts == 0 then
    return
  end

  local group = vim.api.nvim_create_augroup(plugin.name .. ":ft", { clear = false })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function()
      local ft = vim.o.ft
      if vim.list_contains(fts, ft) then
        require("neo-packer.core").load(plugin)
        return true
      end
    end,
  })
end

function M.clean(plugin)
  if #plugin.ft == 0 then
    return
  end
  pcall(vim.api.nvim_del_augroup_by_name, plugin.name .. ":ft")
end

return M
