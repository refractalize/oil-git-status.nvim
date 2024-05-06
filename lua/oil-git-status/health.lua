local oil_git_status = require("oil-git-status")

local h = vim.health

local function check()
  h.start("Checking if oil.nvim is installed")
  local is_oil_installed = pcall(require, "oil")
  if is_oil_installed then
    h.ok("oil.nvim is installed")
    h.start("Checking oil.nvim config")
    if oil_git_status.is_valid_oil_config() then
      h.ok("oil.nvim is configured correctly")
    else
      h.error("oil-git-status requires win_options.signcolumn to be set to at least 'yes:2' or 'auto:2'")
    end
  else
    h.error("oil.nvim is not installed")
  end
end

return {
  check = check,
}
