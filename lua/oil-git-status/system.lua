local function system(cmd, opts, cb)
  local stdout

  vim.fn.jobstart(cmd, {
    cwd = opts.cwd,
    stdout_buffered = true,
    on_exit = function(_, code)
      cb({ code = code, stdout = stdout })
    end,
    on_stdout = function(_, lines)
      stdout = vim.fn.join(lines, "\n")
    end,
  })
end

return {
  system = vim.system or system,
}
