local M = {}

function M.normalize(source)
  local error
  local version
  if source ~= nil then
    if type(source) == "string" then
      version = source
    elseif type(source) == "table" and source["has"] and source["from"] then
      version = source
    else
      vim.notify("neo-packer: plugin version is not a string or vim.VersionRange", vim.log.levels.ERROR)
      version = nil
      error = true
    end
  end

  return version, error
end

return M
