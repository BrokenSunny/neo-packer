local M = {}

function M.normalize(source)
  local error
  local repo

  if source ~= nil then
    if type(source) == "string" then
      repo = source
    else
      vim.notify("neo-packer: plugin repo is not a string", vim.log.levels.ERROR)
      error = true
    end
  end

  return repo, error
end

return M
