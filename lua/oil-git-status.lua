local oil = require("oil")
local namespace = vim.api.nvim_create_namespace("oil-git-status")

local function set_filename_status_code(filename, index_status_code, working_status_code, status)
  local dir_index = filename:find("/")
  if dir_index ~= nil then
    filename = filename:sub(1, dir_index - 1)

    if not status[filename] then
      status[filename] = { index_status_code, working_status_code }
    else
      if index_status_code ~= " " then
        status[filename][1] = "M"
      end
      if working_status_code ~= " " then
        status[filename][2] = "M"
      end
    end
  else
    status[filename] = { index_status_code, working_status_code }
  end
end

local function parse_git_status(git_status_stdout)
  local status_lines = vim.split(git_status_stdout, "\n")
  local status = {}
  for _, line in ipairs(status_lines) do
    local index_status_code = line:sub(1, 1)
    local working_status_code = line:sub(2, 2)
    local filename = line:sub(4)

    if vim.endswith(filename, "/") then
      filename = filename:sub(1, -2)
    end

    set_filename_status_code(filename, index_status_code, working_status_code, status)
  end

  return status
end

local function add_status_extmarks(buffer, status)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  for n = 1, vim.api.nvim_buf_line_count(buffer) do
    local entry = oil.get_entry_on_line(buffer, n)
    if entry then
      local name = entry.name
      local status_codes = status[name]

      if status_codes then
        vim.api.nvim_buf_set_extmark(buffer, namespace, n - 1, 0, {
          sign_text = status_codes[1],
          sign_hl_group = "DiagnosticSignInfo",
          priority = 1,
        })
        vim.api.nvim_buf_set_extmark(buffer, namespace, n - 1, 0, {
          sign_text = status_codes[2],
          sign_hl_group = "DiagnosticSignWarn",
          priority = 2,
        })
      end
    end
  end
end

local function load_git_status(buffer, callback)
  local oil_url = vim.api.nvim_buf_get_name(buffer)
  local file_url = oil_url:gsub("^oil", "file")
  local path = vim.uri_to_fname(file_url)
  vim.system(
    { "git", "-c", "status.relativePaths=true", "st", ".", "--short" },
    { text = true, cwd = path },
    function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          callback(obj.stdout)
        else
          vim.notify("Failed to load git status", vim.log.levels.ERROR)
        end
      end)
    end
  )
end

local function setup()
  vim.api.nvim_create_autocmd({ "FileType" }, {
    pattern = { "oil" },

    callback = function()
      local buffer = vim.api.nvim_get_current_buf()
      local current_status = nil

      if vim.b[buffer].oil_git_status_started then
        return
      end

      vim.b[buffer].oil_git_status_started = true

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        buffer = buffer,

        callback = function()
          load_git_status(buffer, function(stdout)
            current_status = parse_git_status(stdout)
            add_status_extmarks(buffer, current_status)
          end)
        end,
      })

      vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
        buffer = buffer,

        callback = function()
          if current_status then
            add_status_extmarks(buffer, current_status)
          end
        end,
      })
    end,
  })
end

return {
  setup = setup,
}
