# workspaces.nvim

a simple plugin to manage workspace directories in neovim

workspaces.nvim provides a few simple commands for managing workspace
directories in neovim. A workspace is a name and a path, and opening a workspace
will set the current directory to the correct path.

* Register a workspace with `:WorkspacesAdd`
* Open a registered workspace with `:WorkspacesOpen [name]`
* Hooks may be registered to provide additional functionality
* A telescope extension `:Telescope workspaces` is provided for fuzzy finding
  over workspaces

Nothing runs automatically. The idea is that workspace creation is an infrequent
task, so there shouldn't be any need for automatic workspace registration, or
heuristics to determine if a directory is a workspace. A command and telescope
extension are provided to make it simple to open a workspace, but what that
means beyond changing directories is left up to you by customizing the hooks.
See [Examples](#examples) for inspiration on hooks!

Note that this plugin is small in scope and complexity. It has been stable for a
long time. Just because I am not making changes doesn't mean it's been
abandoned! It was designed to be small and stable, and it will stay that way.

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
    path = vim.fn.stdpath("data") .. "/workspaces",

    -- to change directory for nvim (:cd), or only for window (:lcd)
    -- deprecated, use cd_type instead
    -- global_cd = true,

    -- controls how the directory is changed. valid options are "global", "local", and "tab"
    --   "global" changes directory for the neovim process. same as the :cd command
    --   "local" changes directory for the current window. same as the :lcd command
    --   "tab" changes directory for the current tab. same as the :tcd command
    --
    -- if set, overrides the value of global_cd
    cd_type = "global",

    -- sort the list of workspaces by name after loading from the workspaces path.
    sort = true,

    -- sort by recent use rather than by name. requires sort to be true
    mru_sort = true,

    -- option to automatically activate workspace when opening neovim in a workspace directory
    auto_open = false,

    -- enable info-level notifications after adding or removing a workspace
    notify_info = true,

    -- lists of hooks to run after specific actions
    -- hooks can be a lua function or a vim command (string)
    -- lua hooks take a name, a path, and an optional state table
    -- if only one hook is needed, the list may be omitted
    hooks = {
        add = {},
        remove = {},
        rename = {},
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

 * `:WorkspacesAddDir [path]`

  The directory with the specified or current path will be registered
  and each one of its sub folders stored as workspaces.

* `:WorkspacesRemove [name]`

  The workspace with the specified name will be removed.

* `:WorkspacesRemoveDir [name]`

  The directory with the specified name will be removed
  as well as all of its associated workspaces.

* `:WorkspacesRename [name] [new_name]`

  The workspace with the specified name will be renamed to `new_name`.

* `:WorkspacesList`

  Prints all workspaces.

* `:WorkspacesListDirs`

  Prints all directories.

* `:WorkspacesOpen [name]`

  Opens the named workspace. *opening* a workspace means to change the current
  directory to that workspace's path.

* `:WorkspacesSyncDirs`

  Synchronize workspaces from registered directories.

See `:h workspaces-usage` for more information on the commands.

## Lua API

The workspaces commands may also be accessed from Lua

```lua
local workspaces = require("workspaces")

workspaces.add(path: string, name: string)

workspaces.add_dir(path: string)

workspaces.remove(name: string)

workspaces.remove_dir(name: string)

workspaces.rename(name: string, new_name: string)

workspaces.list()

workspaces.list_dirs()

workspaces.open(name: string)

workspaces.get(): table

workspaces.name(): string|nil

workspaces.path(): string|nil

workspaces.sync_dirs()

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
running any registered hooks. `<c-t>` will open the selected workspace in a new tab.

To keep nvim in insert mode (for example, when
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

## Examples

Remember that more than one hook is allowed, so these may be combined in
creative ways! Hooks may also be registered after adding and removing
workspaces, not only after opening a workspace.

See [Configuration
Recipes](https://github.com/natecraddock/workspaces.nvim/wiki/Configuration-Recipes)
and
[Troubleshooting](https://github.com/natecraddock/workspaces.nvim/wiki/Troubleshooting)
on the wiki for more inspiration and help configuring the plugin. Feel free to
contribute your setup!

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
