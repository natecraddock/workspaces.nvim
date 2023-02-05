local util = require("workspaces.util")
local notify = util.notify

local config = {
    -- path to a file to store workspaces data in
    -- on a unix system this would be ~/.local/share/nvim/workspaces
    path = vim.fn.stdpath("data") .. util.path.sep .. "workspaces",

    -- to change directory for nvim (:cd), or only for window (:lcd)
    -- deprecated, use cd_type instead
    global_cd = true,

    -- controls how the directory is changed. valid options are "global", "local", and "tab"
    --   "global" changes directory for the neovim process. same as the :cd command
    --   "local" changes directory for the current window. same as the :lcd command
    --   "tab" changes directory for the current tab. same as the :tcd command
    --
    -- if set, overrides the value of global_cd, not set here to preserve backwards compatibility
    -- cd_type = "global",

    -- sort the list of workspaces after loading from the workspaces path
    sort = true,

    -- sort by recent use rather than by name. requires sort to be true
    mru_sort = true,

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

-- loads the workspaces from the datafile into a table
-- the workspace file format is:
-- * newline separated workspace entries
-- * NULL (\0) separated (name, path) pairs
local load_workspaces = function()
    local file = util.file.read(config.path)

    -- if the file has not yet been created, add an empty file
    if not file then
        util.file.write(config.path, "")
        file = util.file.read(config.path)
    end

    local lines = vim.split(file, "\n", { trimempty = true })

    local workspaces = {}
    for _, line in ipairs(lines) do
        local data = vim.split(line, "\0")
        table.insert(workspaces, {
            name = data[1],
            path = vim.fn.fnamemodify(data[2], ":p"),
            last_opened = data[3],
            type = data[4],
        })
    end

    if config.sort and #workspaces > 0 then
        table.sort(workspaces, function(a, b)
            if config.mru_sort then
                if a.last_opened then
                    if b.last_opened then
                        return a.last_opened > b.last_opened
                    end
                    return true
                elseif b.last_opened then
                    return false
                else
                    return a.name < b.name
                end
            else
                return a.name < b.name
            end
        end)
    end

    return workspaces
end

-- writes the workspaces from the table into the datafile
local store_workspaces = function(workspaces)
    local data = ""
    for _, workspace in ipairs(workspaces) do
        -- not all workspaces have a date
        local date_str = workspace.last_opened or ""
        local type = workspace.type or ""
        data = data .. string.format("%s\0%s\0%s\0%s\n", workspace.name, workspace.path, date_str, type)
    end
    util.file.write(config.path, data)
end

local cwd = function()
    return vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
end

local direq = function(a, b)
    a = vim.fn.fnamemodify(a, ":p")
    b = vim.fn.fnamemodify(b, ":p")
    return a == b
end

---@param hook function|string
---@param name string
---@param path string
---@param state table|nil
local run_hook = function(hook, name, path, state)
    if type(hook) == "function" then
        if hook(name, path, state) == false then
            return false
        end
    elseif type(hook) == "string" then
        vim.cmd(hook)
    else
        notify.err(string.format("Invalid workspace hook '%s'", hook))
    end

    return true
end

---given a list of hooks, execute each in the order given
---@param hooks table|function|string
---@param name string
---@param path string
---@param state table|nil
local run_hooks = function(hooks, name, path, state)
    if not hooks then
        return
    end

    if type(hooks) == "table" then
        for _, hook in ipairs(hooks) do
            if run_hook(hook, name, path, state) == false then
                return false
            end
        end
    else
        if run_hook(hooks, name, path, state) == false then
            return false
        end
    end

    return true
end

---returns the list of workspaces and directories
---@return table
local get_workspaces_and_dirs = function()
    local data = load_workspaces()

    local directories = {}
    local workspaces = {}
    for _, item in ipairs(data) do
        if item.type == "directory" then
            table.insert(directories, item)
        else
            table.insert(workspaces, item)
        end
    end

    return { workspaces = workspaces, directories = directories }
end

---prints the list of workspaces or directories
---@param items table
---@param is_dir boolean|nil
local print_workspaces_or_dirs = function(items, is_dir)
    local type = is_dir and "directories" or "workspaces"
    local command = is_dir and ":WorkspacesAddDir" or ":WorkspacesAdd"

    local ending = "\n"

    if #items == 0 then
        notify.warn(string.format("No %s are registered yet. Add one with %s", type, command))
        return
    end

    for i, item in ipairs(items) do
        if #items == i then
            ending = ""
        end
        print(string.format("%s %s%s", item.name, item.path, ending))
    end
end

---finds a specific workspace or directory based on its name or path
---@param name string|nil
---@param path string|nil
---@param is_dir boolean|nil
local find = function(name, path, is_dir)
    local type = is_dir and "directory" or ""
    if not name then
        name = util.path.basename(path)
    end

    local workspaces = load_workspaces()
    for i, workspace in ipairs(workspaces) do
        if (workspace.name == name or (path and direq(workspace.path, path))) and workspace.type == type then
            return workspace, i
        end
    end

    return nil
end

---adds a workspace or directory to the data file
---path is optional, if omitted the current directory will be used
---name is optional, if omitted the path will be used
---if path is nil and name looks like a path, then name will be used
---as the path
---@param path string|nil
---@param name string|nil
---@param is_dir boolean|nil
---@param no_logs boolean|nil
local add_workspace_or_directory = function(path, name, is_dir, no_logs)
    local type = is_dir and "directory" or ""
    local type_name = is_dir and "Directory" or "Workspace"

    if not path and not name then
        -- none given, use current directory and name
        path = cwd()
        name = util.path.basename(path)
    elseif not name then
        if string.find(path, util.path.sep) then
            -- only path given, extract name from path
            path = vim.fn.fnamemodify(path, ":p")
            name = util.path.basename(path)
        else
            -- name given, use cwd as path
            name = path
            path = cwd()
        end
    else
        -- both given, ensure the path is expanded
        name, path = path, name
        path = vim.fn.fnamemodify(path, ":p")
    end

    -- ensure path is valid
    if vim.fn.isdirectory(path) == 0 then
        notify.err(string.format("Path '%s' does not exist", path))
        return
    end

    -- check if it already exists
    local workspaces = load_workspaces()
    for _, workspace in ipairs(workspaces) do
        if (workspace.name == name or workspace.path == path) and workspace.type == type then
            notify.warn(string.format("%s '%s' is already registered", type_name, workspace.name))
            return
        end
    end

    table.insert(workspaces, {
        name = name,
        path = path,
    })

    store_workspaces(workspaces)
    run_hooks(config.hooks.add, name, path)

    if config.notify_info and not no_logs then
        notify.info(string.format("workspace [%s -> %s] added", name, path))
    end
end

---remove a workspace or directory from the data file by name
---name is optional, if omitted the current directory will be used
---@param name string|nil
---@param is_dir boolean|nil
---@param no_logs boolean|nil
local remove_workspace_or_directory = function(name, is_dir, no_logs)
    local type_name = is_dir and "Directory" or "Workspace"
    local path = cwd()
    local workspace, i = find(name, path, is_dir)
    if not workspace then
        if not name then
            return
        end
        notify.warn(string.format("%s '%s' does not exist", type_name, name))
        return
    end

    local workspaces = load_workspaces()
    table.remove(workspaces, i)
    store_workspaces(workspaces)

    run_hooks(config.hooks.remove, workspace.name, workspace.path)

    if config.notify_info and not no_logs then
        notify.info(string.format("%s [%s -> %s] removed", type_name, workspace.name, workspace.path))
    end
end

---gets workspaces from a specific directory by name
---@param dir_name string
local get_dir_workspaces = function(dir_name)
    local data = get_workspaces_and_dirs()

    local directory_workspaces = {}
    for _, dir in ipairs(data.directories) do
        if dir_name == dir.name then
            for _, workspace in ipairs(data.workspaces) do
                local parent_path = util.path.parent(workspace.path)

                if parent_path == dir.path then
                    table.insert(directory_workspaces, workspace)
                end
            end
        end
    end

    return directory_workspaces
end

local M = {}

---adds a workspace to the data file
---@param path string|nil
---@param name string|nil
M.add = function(path, name)
    add_workspace_or_directory(path, name)
end

--- adds a directory subfolders as workspaces
---@param path string|nil
---@param no_logs boolean|nil
M.add_dir = function(path, no_logs)
    if not path then
        path = cwd()
    end

    local directories, err = util.dir.read(path)
    if not directories then
        return notify.err(err)
    end

    for _, workspace_path in ipairs(directories) do
        local existing_workspace = find(nil, workspace_path)

        if not existing_workspace then
            local workspace_name = util.path.basename(workspace_path)
            add_workspace_or_directory(workspace_name, workspace_path, false, true)
        end
    end

    local existing_dir = find(nil, path, true)
    if existing_dir then
        return
    end

    local workspaces = load_workspaces()

    local dir_name = util.path.basename(path)
    table.insert(workspaces, {
        name = dir_name,
        path = path,
        type = "directory",
    })

    store_workspaces(workspaces)

    if not no_logs then
        notify.info(string.format("Directory [%s -> %s] and associated workspaces added", dir_name, path))
    end
end

-- This function is a legacy of the older api, but it's not worth
-- it to try to merge this with the add function. It works fine, don't touch it!
-- currently it is a mess trying to get it to conform to the old api
---@param name string|nil
---@param path string|nil
M.add_swap = function(name, path)
    if name and path then
        M.add(name, path)
    elseif name and not path then
        M.add(name, path)
    else
        M.add(path, name)
    end
end

---remove a workspace or directory from the data file by name
---name is optional, if omitted the current directory will be used
---@param name string|nil
M.remove = function(name)
    remove_workspace_or_directory(name)
end

---removes directory and associated workspaces
---@param dir_name string
---@param no_logs boolean|nil
M.remove_dir = function(dir_name, no_logs)
    local workspaces = get_dir_workspaces(dir_name)

    for _, workspace in ipairs(workspaces) do
        remove_workspace_or_directory(workspace.name, false, true)
    end

    remove_workspace_or_directory(dir_name, true, true)

    if not no_logs then
        notify.info(string.format("Directory [%s] and associated workspaces removed", dir_name))
    end
end

local current_workspace = nil

---rename an existing workspace
---@param name string
---@param new_name string
M.rename = function(name, new_name)
    local workspace, i = find(name)
    if not workspace or not i then
        if not name then
            return
        end
        notify.warn(string.format("Workspace '%s' does not exist", name))
        return
    end

    workspace.name = new_name
    local workspaces = load_workspaces()
    workspaces[i] = workspace
    store_workspaces(workspaces)

    if current_workspace == name then
        current_workspace = workspace.name
    end

    run_hooks(config.hooks.rename, workspace.name, workspace.path, { previous_name = name })

    if config.notify_info then
        notify.info(string.format("workspace [%s -> %s] renamed", workspace.name, workspace.path))
    end
end

---returns the list of all workspaces
---each workspace is formatted as a { name = "", path = "" } table
---@return table
M.get = function()
    local data = get_workspaces_and_dirs()

    return data.workspaces
end

-- displays the list of workspaces
M.list = function()
    local data = get_workspaces_and_dirs()

    print_workspaces_or_dirs(data.workspaces)
end

-- displays the list of directories
M.list_dirs = function()
    local data = get_workspaces_and_dirs()

    print_workspaces_or_dirs(data.directories)
end

local select_fn = function(item, index)
    -- prevent an infinite open loop
    if not item then
        return
    end
    M.open(item.name)
end

local get_cd_command = function()
    if config.cd_type then
        if config.cd_type == "global" then
            return "cd"
        elseif config.cd_type == "local" then
            return "lcd"
        elseif config.cd_type == "tab" then
            return "tcd"
        end
    elseif config.global_cd or config.global_cd == nil then
        return "cd"
    else
        return "lcd"
    end
end

---opens the named workspace
---this changes the current directory to the path specified in the workspace entry
---@param name string|nil
M.open = function(name)
    if not name then
        local workspaces = load_workspaces()
        vim.ui.select(workspaces, {
            prompt = "Select workspace to open:",
            format_item = function(item)
                return item.name
            end,
        }, select_fn)
        return
    end

    local workspace, index = find(name)
    if not workspace then
        notify.warn(string.format("Workspace '%s' does not exist", name))
        return
    end

    if run_hooks(config.hooks.open_pre, workspace.name, workspace.path) == false then
        -- if any hooks aborted, then do not change directory
        return
    end

    -- register this workspace as having been opened recently
    local workspaces = load_workspaces()
    workspaces[index].last_opened = util.date()
    store_workspaces(workspaces)

    -- change directory
    local cd_command = get_cd_command()
    vim.cmd(string.format("%s %s", cd_command, workspace.path))

    current_workspace = workspace.name
    run_hooks(config.hooks.open, workspace.name, workspace.path)
end

---returns the name of the current workspace
---@return string|nil
M.name = function()
    return current_workspace
end

local workspace_or_dir_name_complete = function(lead, is_dir)
    local data = get_workspaces_and_dirs()
    local list_by_type = is_dir and data.directories or data.workspaces

    local items = vim.tbl_filter(function(item)
        if lead == "" then
            return true
        end
        return vim.startswith(item.name, lead)
    end, list_by_type)

    return vim.tbl_map(function(item)
        return item.name
    end, items)
end

-- completion for workspace names only
M.workspace_complete = function(lead, _, _)
    return workspace_or_dir_name_complete(lead)
end

-- completion for directory names only
M.directory_complete = function(lead, _, _)
    return workspace_or_dir_name_complete(lead, true)
end

--- sync all directories workspaces
M.sync_dirs = function()
    local data = get_workspaces_and_dirs()

    for _, dir in ipairs(data.directories) do
        M.remove_dir(dir.name, true)
        M.add_dir(dir.path, true)
    end

    notify.info(string.format("Directory workspaces have been synced"))
end

-- run to setup user commands and custom config
M.setup = function(opts)
    opts = opts or {}
    config = vim.tbl_deep_extend("force", {}, config, opts)

    vim.api.nvim_create_user_command("WorkspacesAdd", function(cmd_opts)
        require("workspaces").add_swap(unpack(cmd_opts.fargs))
    end, {
        desc = "Add a workspace via name and path.",
        nargs = "*",
        complete = "file",
    })

    vim.api.nvim_create_user_command("WorkspacesAddDir", function(cmd_opts)
        require("workspaces").add_dir(unpack(cmd_opts.fargs))
    end, {
        desc = "Add all workspaces contained in a directory.",
        nargs = "*",
        complete = "file",
    })

    vim.api.nvim_create_user_command("WorkspacesRemove", function(cmd_opts)
        require("workspaces").remove(unpack(cmd_opts.fargs))
    end, {
        desc = "Remove a workspace by name.",
        nargs = "?",
        complete = function(lead)
            return require("workspaces").workspace_complete(lead)
        end,
    })

    vim.api.nvim_create_user_command("WorkspacesRemoveDir", function(cmd_opts)
        require("workspaces").remove_dir(unpack(cmd_opts.fargs))
    end, {
        desc = "Remove a directory and its workspaces.",
        nargs = "*",
        complete = function(lead)
            return require("workspaces").directory_complete(lead)
        end,
    })

    vim.api.nvim_create_user_command("WorkspacesRename", function(cmd_opts)
        require("workspaces").rename(unpack(cmd_opts.fargs))
    end, {
        desc = "Rename a workspace by name to new name.",
        nargs = "*",
        complete = function(lead)
            return require("workspaces").workspace_complete(lead)
        end,
    })

    vim.api.nvim_create_user_command("WorkspacesList", function()
        require("workspaces").list()
    end, {
        desc = "Print all workspaces.",
    })

    vim.api.nvim_create_user_command("WorkspacesListDirs", function()
        require("workspaces").list_dirs()
    end, {
        desc = "Print all directories.",
    })

    vim.api.nvim_create_user_command("WorkspacesOpen", function(cmd_opts)
        require("workspaces").open(unpack(cmd_opts.fargs))
    end, {
        desc = "Open a workspace by name.",
        nargs = "?",
        complete = function(lead)
            return require("workspaces").workspace_complete(lead)
        end,
    })

    vim.api.nvim_create_user_command("WorkspacesSyncDirs", function(cmd_opts)
        require("workspaces").sync_dirs(unpack(cmd_opts.fargs))
    end, {
        desc = "Synchronize all directory workspaces.",
    })
end

return M
