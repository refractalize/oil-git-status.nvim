local oil = require("oil")
local namespace = vim.api.nvim_create_namespace("oil-git-status")

local default_config = {
  show_ignored = true,
}

local current_config = vim.tbl_extend("force", default_config, {})

local function set_filename_status_code(filename, index_status_code, working_status_code, status)
  local dir_index = filename:find("/")
  if dir_index ~= nil then
    filename = filename:sub(1, dir_index - 1)

    if not status[filename] then
      status[filename] = {
        index = index_status_code,
        working_tree = working_status_code,
      }
    else
      if index_status_code ~= " " then
        status[filename].index = "M"
      end
      if working_status_code ~= " " then
        status[filename].working_tree = "M"
      end
    end
  else
    status[filename] = {
      index = index_status_code,
      working_tree = working_status_code,
    }
  end
end

local function parse_git_status(git_status_stdout, git_fs_tree_stdout)
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

  for _, filename in ipairs(vim.split(git_fs_tree_stdout, "\n")) do
    if not status[filename] then
      status[filename] = { index = " ", working_tree = " " }
    end
  end

  return status
end

local function add_status_extmarks(buffer, status)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  if status then
    for n = 1, vim.api.nvim_buf_line_count(buffer) do
      local entry = oil.get_entry_on_line(buffer, n)
      if entry then
        local name = entry.name
        local status_codes = status[name] or (current_config.show_ignored and { index = "!", working_tree = "!" })

        if status_codes then
          vim.api.nvim_buf_set_extmark(buffer, namespace, n - 1, 0, {
            sign_text = status_codes.index,
            sign_hl_group = "DiagnosticSignInfo",
            priority = 1,
          })
          vim.api.nvim_buf_set_extmark(buffer, namespace, n - 1, 0, {
            sign_text = status_codes.working_tree,
            sign_hl_group = "DiagnosticSignWarn",
            priority = 2,
          })
        end
      end
    end
  end
end

local function concurrent(fns, callback)
  local number_of_results = 0
  local results = {}

  for i, fn in ipairs(fns) do
    fn(function(args, ...)
      number_of_results = number_of_results + 1
      results[i] = args

      if number_of_results == #fns then
        callback(results, ...)
      end
    end)
  end
end

local function load_git_status(buffer, callback)
  local oil_url = vim.api.nvim_buf_get_name(buffer)
  local file_url = oil_url:gsub("^oil", "file")
  local path = vim.uri_to_fname(file_url)
  concurrent({
    function(cb)
      vim.system({ "git", "rev-parse", "--is-inside-work-tree" }, { text = true, cwd = path }, cb)
    end,
    function(cb)
      vim.system({ "git", "-c", "status.relativePaths=true", "st", ".", "--short" }, { text = true, cwd = path }, cb)
    end,
    function(cb)
      if current_config.show_ignored then
        vim.system({ "git", "ls-tree", "HEAD", ".", "--name-only" }, { text = true, cwd = path }, cb)
      else
        cb({ code = 0, stdout = "" })
      end
    end,
  }, function(results)
    vim.schedule(function()
      local in_git_dir_results = results[2]
      local git_status_results = results[2]
      local git_fs_tree_results = results[3]

      if in_git_dir_results.code ~= 0 then
        return callback()
      end

      if git_status_results.code ~= 0 then
        vim.notify("Failed to load git status", vim.log.levels.ERROR)
        return callback()
      end

      if git_fs_tree_results.code ~= 0 then
        vim.notify("Failed to load git fs-tree", vim.log.levels.ERROR)
        return callback()
      end

      callback(parse_git_status(git_status_results.stdout, git_fs_tree_results.stdout))
    end)
  end)
end

local function setup(config)
  current_config = vim.tbl_extend("force", default_config, config or {})
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
          load_git_status(buffer, function(status)
            current_status = status
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
