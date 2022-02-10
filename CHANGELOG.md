# Changelog

# master

* **feat**: pass workspace name and path to Lua function hooks

  If a hook is a Lua function, the workspace name and path will be passed as
  arguments to the function. This allows hooks to respond differently depending
  on the name and path of the workspace if desired.

* **feat**: add `sort` config option

  Set to true by default. Sorts the list of workspaces by name after loading
  from the workspaces file. All lists of workspaces (commands, completions,
  .get() api) will be sorted.

* **feat**: add `global_cd` config option

  This may be used to only change directory in the current window rather than
  for the entire neovim process.

* **deprecated**: `:Workspaces [add|remove|open|list]` commands

  use `:Workspaces[Add|Remove|Open|List]`. The old command will work until
  version 1.0, but it will warn each time it is called.

* **feat**: improved command completion

  This introduces `:WorkspacesAdd`, `:WorkspacesRemove`, `:WorkspacesList`, and
  `:WorkspacesOpen` commands. See deprecation warning above. The new commands
  offer path completion, are more standard, and are easier to maintain.

* **feat**: add `workspaces.name()` api function to query the current workspace
  name.

* **feat**: add `open_pre` hook support.

# v0.1 Initial Release
