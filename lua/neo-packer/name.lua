local M = {}

function M.normalize(source, repo)
  local packpaths = vim.opt.packpath:get()
  local name = source
  local path
  local error

  if source ~= nil then
    if type(source) ~= "string" then
      name = nil
      path = nil
      error = true
      vim.notify("neo-packer: name is not a string", vim.log.levels.ERROR)
    else
      if not repo then
        for _, p in ipairs(packpaths) do
          local files = vim.fn.glob(p .. "/pack/*/opt/" .. name, true, true)
          if #files > 0 then
            path = files[1]
            break
          end
        end

        if not path then
          name = nil
          path = nil
          error = true
          vim.notify("neo-packer: name:" .. source .. "pack is't in packpath", vim.log.levels.ERROR)
        end
      end
    end
  else
    if not repo then
      name = nil
      path = nil
      error = true
      vim.notify("neo-packer: name or repo must have one!", vim.log.levels.ERROR)
    end
  end

  return name, path, error
end

return M
