local oil = require("oil")
local namespace = vim.api.nvim_create_namespace("oil-git-status")
local system = require("oil-git-status.system").system

local default_config = {
  show_ignored = true,
  symbols = {
    index = {},
    working_tree = {},
  },
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

--- @param s string
--- @return string
local function unquote_git_file_name(s)
  -- git-ls-tree and git-status show '\file".md' as `"\\file\".md"`.
  local out, _ = s:gsub('"(.*)"', "%1"):gsub('\\"', '"'):gsub("\\\\", "\\")
  return out
end

local function parse_git_status(git_status_stdout, git_ls_tree_stdout)
  local status_lines = vim.split(git_status_stdout, "\n")
  local status = {}
  for _, line in ipairs(status_lines) do
    local index_status_code = line:sub(1, 1)
    local working_status_code = line:sub(2, 2)
    local filename = unquote_git_file_name(line:sub(4))

    if vim.endswith(filename, "/") then
      filename = filename:sub(1, -2)
    end

    set_filename_status_code(filename, index_status_code, working_status_code, status)
  end

  for _, filename in ipairs(vim.split(git_ls_tree_stdout, "\n")) do
    filename = unquote_git_file_name(filename)
    if not status[filename] then
      status[filename] = { index = " ", working_tree = " " }
    end
  end

  return status
end

local highlight_group_suffix_for_status_code = {
  ["!"] = "Ignored",
  ["?"] = "Untracked",
  ["A"] = "Added",
  ["C"] = "Copied",
  ["D"] = "Deleted",
  ["M"] = "Modified",
  ["R"] = "Renamed",
  ["T"] = "TypeChanged",
  ["U"] = "Unmerged",
  [" "] = "Unmodified",
}

local function highlight_group(code, index)
  local location = index and "Index" or "WorkingTree"

  return "OilGitStatus" .. location .. (highlight_group_suffix_for_status_code[code] or "Unmodified")
end

local function get_symbol(symbols, code)
  return symbols[code] or code
end

local function add_status_extmarks(buffer, status)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  if status then
    for n = 1, vim.api.nvim_buf_line_count(buffer) do
      local entry = oil.get_entry_on_line(buffer, n)
      if entry and entry.name ~= '..' then
        local name = entry.name

        local status_codes = status[name] or (current_config.show_ignored and { index = "!", working_tree = "!" })

        if status_codes then
          vim.api.nvim_buf_set_extmark(buffer, namespace, n - 1, 0, {
            sign_text = get_symbol(current_config.symbols.index, status_codes.index),
            sign_hl_group = highlight_group(status_codes.index, true),
            priority = 2,
          })
          vim.api.nvim_buf_set_extmark(buffer, namespace, n - 1, 0, {
            sign_text = get_symbol(current_config.symbols.working_tree, status_codes.working_tree),
            sign_hl_group = highlight_group(status_codes.working_tree, false),
            priority = 1,
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
  if vim.fn.has("win32") == 1 then
    file_url = file_url:gsub("file:///([A-Za-z])/", "file:///%1:/")
  end
  local path = vim.uri_to_fname(file_url)
  concurrent({
    function(cb)
      -- quotepath=false - don't escape UTF-8 paths.
      system(
        { "git", "-c", "core.quotepath=false", "-c", "status.relativePaths=true", "status", ".", "--short" },
        { text = true, cwd = path },
        cb
      )
    end,
    function(cb)
      if current_config.show_ignored then
        -- quotepath=false - don't escape UTF-8 paths.
        system(
          { "git", "-c", "core.quotepath=false", "ls-tree", "HEAD", ".", "--name-only" },
          { text = true, cwd = path },
          cb
        )
      else
        cb({ code = 0, stdout = "" })
      end
    end,
  }, function(results)
    vim.schedule(function()
      local git_status_results = results[1]
      local git_ls_tree_results = results[2]

      if git_ls_tree_results.code ~= 0 or git_status_results.code ~= 0 then
        return callback()
      end

      callback(parse_git_status(git_status_results.stdout, git_ls_tree_results.stdout))
    end)
  end)
end

local function validate_oil_config()
  local oil_config = require("oil.config")
  local signcolumn = oil_config.win_options.signcolumn
  if not (vim.startswith(signcolumn, "yes") or vim.startswith(signcolumn, "auto")) then
    vim.notify(
      "oil-git-status requires win_options.signcolumn to be set to at least 'yes:2' or 'auto:2'",
      vim.log.levels.WARN,
      {
        title = "oil-git-status",
      }
    )
  end
end

local function generate_highlight_groups()
  local highlight_groups = {}
  for status_code, suffix in pairs(highlight_group_suffix_for_status_code) do
    table.insert(
      highlight_groups,
      { hl_group = "OilGitStatusIndex" .. suffix, index = true, status_code = status_code }
    )
    table.insert(
      highlight_groups,
      { hl_group = "OilGitStatusWorkingTree" .. suffix, index = false, status_code = status_code }
    )
  end
  return highlight_groups
end

--- @type table<string, {hl_group: string, index: boolean, status_code: string}>
local highlight_groups = generate_highlight_groups()

--- @param config {show_ignored: boolean}
local function setup(config)
  current_config = vim.tbl_extend("force", default_config, config or {})

  validate_oil_config()

  vim.api.nvim_create_autocmd({ "FileType" }, {
    pattern = { "oil" },

    callback = function()
      local buffer = vim.api.nvim_get_current_buf()
      local current_status = nil

      -- Ignore ssh and trash buffers
      local oil_url = vim.api.nvim_buf_get_name(buffer)
      if nil == oil_url:find("^oil:") then
          return
      end

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

  vim.api.nvim_set_hl(0, "OilGitStatusIndex", { link = "DiagnosticSignInfo", default = true })
  vim.api.nvim_set_hl(0, "OilGitStatusWorkingTree", { link = "DiagnosticSignWarn", default = true })

  for _, hl_group in ipairs(highlight_groups) do
    if hl_group.index then
      vim.api.nvim_set_hl(0, hl_group.hl_group, { link = "OilGitStatusIndex", default = true })
    else
      vim.api.nvim_set_hl(0, hl_group.hl_group, { link = "OilGitStatusWorkingTree", default = true })
    end
  end
end

return {
  setup = setup,
  highlight_groups = highlight_groups,
}
