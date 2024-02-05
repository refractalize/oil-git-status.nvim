# oil-git-status.nvim

Add Git Status to [oil.nvim](https://github.com/stevearc/oil.nvim) directory listings. Git status is added to the listing asynchronously after creating the `oil` directory listing so it won't slow `oil` down on big repositories. The plugin puts the status in two new sign columns, the left being the status of the index, the right being the status of the working directory, just as you'd get if you ran `git status --short`.

![image](https://github.com/refractalize/oil-git-status.nvim/assets/123917/ec179eee-0e04-4bd2-8674-56e3a8b0f13c)

## Configuration

Change the `oil` configuration to allow at least 2 sign columns:

```lua
require("oil").setup({
  win_options = {
    signcolumn = "yes:2",
  },
})
```

### Lazy

```lua
{
  "refractalize/oil-git-status.nvim",

  dependencies = {
    "stevearc/oil.nvim",
  },

  config = true,
},
```

### Packer

```lua
use {
  'refractalize/oil-git-status.nvim',

  after = {
    "oil.nvim",
  },

  config = function()
    require("oil-git-status").setup()
  end,
}
```

### Default Config

```lua
require('oil-git-status').setup({
  show_ignored = true -- show files that match gitignore with !!
})
```

## Highlight Groups

The following highlight groups are defined:

| Status Code | In Index                       | In Working Tree                      |
| ----------- | ------------------------------ | ------------------------------------ |
| ` `         | `OilGitStatusIndexUnmodified`  | `OilGitStatusWorkingTreeUnmodified`  |
| `!`         | `OilGitStatusIndexIgnored`     | `OilGitStatusWorkingTreeIgnored`     |
| `?`         | `OilGitStatusIndexUntracked`   | `OilGitStatusWorkingTreeUntracked`   |
| `A`         | `OilGitStatusIndexAdded`       | `OilGitStatusWorkingTreeAdded`       |
| `C`         | `OilGitStatusIndexCopied`      | `OilGitStatusWorkingTreeCopied`      |
| `D`         | `OilGitStatusIndexDeleted`     | `OilGitStatusWorkingTreeDeleted`     |
| `M`         | `OilGitStatusIndexModified`    | `OilGitStatusWorkingTreeModified`    |
| `R`         | `OilGitStatusIndexRenamed`     | `OilGitStatusWorkingTreeRenamed`     |
| `T`         | `OilGitStatusIndexTypeChanged` | `OilGitStatusWorkingTreeTypeChanged` |
| `U`         | `OilGitStatusIndexUnmerged`    | `OilGitStatusWorkingTreeUnmerged`    |

You can access these programmatically through the `require('oil-git-status').highlight_groups` field:

```lua
for _, hl_group in pairs(require('oil_git_status').highlight_groups) do
  if hl_group.index then
    vim.api.nvim_set_hl(0, hl_group.hl_group, { fg = "#ff0000" })
  else
    vim.api.nvim_set_hl(0, hl_group.hl_group, { fg = "#00ff00" })
  end
end
```
