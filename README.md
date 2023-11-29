# oil-git-status.nvim

Add Git Status to [oil.nvim](https://github.com/stevearc/oil.nvim) directory listings. Git status is added to the listing asynchronously after creating the `oil` directory listing so it won't slow `oil` down on big repositories.

![image](https://github.com/refractalize/oil-git-status.nvim/assets/123917/ec179eee-0e04-4bd2-8674-56e3a8b0f13c)

## Configuration

### Lazy

```lua
{
  "refractalize/oil-git-status",

  dependencies = {
    "stevearc/oil.nvim",
  },

  config = true,
},
```

Change the `oil` configuration to allow at least 2 sign columns:

```lua
require("oil").setup({
  win_options = {
    signcolumn = "yes:2",
  },
})
```
