local oil_git_status = require("oil-git-status")

if not vim.g.oil_git_status_did_setup then
  oil_git_status.validate_oil_config()
  oil_git_status.set_highlights()
  vim.g.oil_git_status_did_setup = true
end

local buffer = vim.api.nvim_get_current_buf()
local current_status = nil

if vim.b[buffer].oil_git_status_started then
  return
end

vim.b[buffer].oil_git_status_started = true

local augroup = vim.api.nvim_create_augroup("oil-git-status", {})

vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
  buffer = buffer,
  callback = function()
    oil_git_status.update_git_status(buffer)
  end,
  group = augroup,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  buffer = buffer,
  callback = function()
    oil_git_status.refresh(buffer)
  end,
  group = augroup,
})
