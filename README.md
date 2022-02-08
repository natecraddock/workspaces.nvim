# workspaces.nvim

a simple plugin to manage workspace directories in neovim

workspaces.nvim provides a few simple commands for managing workspace
directories in neovim. A workspace is a name and a path, and opening a workspace
will set the current directory to the correct path.

* Register a workspace with `:Workspaces add`
* Open a registered workspace with `:Workspaces open [name]`
* Hooks may be registered to provide additional functionality
* A telescope extension `:Telescope workspaces` is provided for fuzzy finding
  over workspaces

Nothing runs automatically. The idea is that workspace creation is an infrequent
task, so there shouldn't be any need for automatic workspace registration, or
heuristics to determine if a directory is a workspace. A command and telescope
extension are provided to make it simple to open a workspace, but what that
means beyond changing directories is left up to you by customizing the hooks.
See [Examples](#examples) for inspiration on hooks!

## Installation

Install with your favorite neovim package manager. Be sure to run the setup
function if you wish to change the default configuration or register the user
commands.

```lua
require("workspaces").setup()
```

The setup function accepts a table to modify the default configuration:

```lua
{
    -- path to a file to store workspaces data in
    -- on a unix system this would be ~/.local/share/nvim/workspaces
    path = vim.fn.stdpath("data") .. util.path.sep .. "workspaces",

    -- to change directory for all of nvim (:cd) or only for the current window (:lcd)
    -- if you are unsure, you likely want this to be true.
    global_cd = true,

    -- sort the list of workspaces by name after loading from the workspaces path.
    sort = true,

    -- lists of hooks to run after specific actions
    -- hooks can be a lua function or a vim command (string)
    -- if only one hook is needed, the list may be omitted
    hooks = {
        add = {},
        remove = {},
        open_pre = {},
        open = {},
    },
}
```

For example, the following settings will add a hook to run `:Telescope
find_files` after opening a workspace, and keep the default workspaces path:

```lua
require("workspaces").setup({
    hooks = {
        open = { "Telescope find_files" },
    }
})
```

## Commands

The setup function registers the following user commands:

* `:WorkspacesAdd [name] [path]`

  The workspace with the specified name and path will be registered.

* `:WorkspacesRemove [name]`

  The workspace with the specified name will be removed.

* `:WorkspacesList`

  Prints all workspaces.

* `:WorkspacesOpen [name]`

  Opens the named workspace. *opening* a workspace means to change the current
  directory to that workspace's path.

See `:h workspaces-usage` for more information on the commands.

## Auto reload NvimTree

Just add this option in your workspaces setup:
```lua
hooks = {
  open = {
    "NvimTreeRefresh",
  },
}
```

And activate this property in the nvimTree setup:
```lua
require("nvim-tree").setup({
  update_cwd = true,
})
```

Remember: If you're using lazy-loading you will get an error, if this is your case, only activate the nvimTree option.

## Lua API

The workspaces commands may also be accessed from Lua

```lua
local workspaces = require("workspaces")

workspaces.add(path: string, name: string)

workspaces.remove(name: string)

workspaces.list()

workspaces.open(name: string)

workspaces.get(): table

workspaces.name(): string|nil
```

See `:h workspaces-api` for more information on the API functions.

## Telescope Picker

workspaces.nvim is bundled with a
[telescope](https://github.com/nvim-telescope/telescope.nvim) picker extension.
To enable, add the following to your config

```lua
telescope.load_extension("workspaces")
```

The picker will list all workspaces. `<cr>` will open the selected workspace,
running any registered hooks. To keep nvim in insert mode (for example, when
chaining multiple telescope pickers), add the following to your telescope setup
function.

```lua
require("telescope").setup({
  extensions = {
    workspaces = {
      -- keep insert mode after selection in the picker, default is false
      keep_insert = true,
    }
  }
})
```

## Demo

https://user-images.githubusercontent.com/7967463/151685936-53c8e2f8-fca8-4a72-a710-58d41925c832.mp4

## Examples

Remember that more than one hook is allowed, so these may be combined in
creative ways! Hooks may also be registered after adding and removing
workspaces, not only after opening a workspace.

### fzf file finder

Change directory to the workspace and run fzf.

```lua
require("workspaces").setup({
    hooks = {
        open = "FZF",
    }
})
```

### Open a file tree

Open [nvim-tree](https://github.com/kyazdani42/nvim-tree.lua).

```lua
require("workspaces").setup({
    hooks = {
        open = "NvimTreeOpen",
    }
})
```

### Load a saved session

Load any saved sessions using
[natecraddock/sessions.nvim](https://github.com/natecraddock/sessions.nvim).

```lua
require("workspaces").setup({
    hooks = {
        open = function()
          require("sessions").load(nil, { silent = true })
        end,
    }
})
```

### Combo

Open nvim-tree and a telescope file picker.

```lua
require("workspaces").setup({
    hooks = {
        open = { "NvimTreeOpen", "Telescope find_files" },
    }
})
```

If you create a hook you think is useful, let me know and I might just add it to
this list!

## Related

workspaces.nvim is a simple plugin with the ability to be extended through
hooks. Nothing is registered or opened automatically. If you want a plugin to be
less manual, try an alternative:

* [ahmedkhalf/project.nvim](https://github.com/ahmedkhalf/project.nvim)
  Automatically tracks workspace directories based on pattern matching
  heuristics.
