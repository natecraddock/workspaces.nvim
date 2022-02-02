local util = require("workspaces.util")

local levels = vim.log.levels

local config = {
    -- path to a file to store workspaces data in
    path = vim.fn.stdpath("data") .. util.path.sep .. "workspaces",

    -- lists of hooks to run after specific actions
    -- hooks can be a lua function or a vim command (string)
    hooks = {
        add = {},
        remove = {},
        open_pre = {},
        open = {},
    },
}

-- loads the workspaces from the datafile into a table
-- the workspace file format is:
-- * newline separated workspace entries
-- * NULL (\0) separated (name, path) pairs
local load_workspaces = function()
    local data = util.file.read(config.path)

    -- if the file has not yet been created, add an empty file
    if not data then
        util.file.write(config.path, "")
        data = util.file.read(config.path)
    end

    local lines = vim.split(data, "\n", { trimempty = true })

    local workspaces = {}
    for _, line in ipairs(lines) do
        local data = vim.split(line, "\0")
        table.insert(workspaces, {
            name = data[1],
            path = data[2],
        })
    end

    return workspaces
end

-- writes the workspaces from the table into the datafile
local store_workspaces = function(workspaces)
    local data = ""
    for _, workspace in ipairs(workspaces) do
        data = data .. string.format("%s\0%s\n", workspace.name, workspace.path)
    end
    util.file.write(config.path, data)
end

local run_hook = function(hook)
    if type(hook) == "function" then
        hook()
    elseif type(hook) == "string" then
        vim.cmd(hook)
    else
        vim.notify(string.format("workspaces.nvim: invalid hook '%s'", hook), levels.ERROR)
    end
end

-- given a list of hooks, execute each in the order given
local run_hooks = function(hooks)
    if not hooks then return end

    if type(hooks) == "table" then
        for _, hook in ipairs(hooks) do
            run_hook(hook)
        end
    else
        run_hook(hooks)
    end
end

local M = {}

-- add a workspace to the workspaces list
-- path is optional, if omitted the current directory will be used
-- name is optional, if omitted the path will be used
-- if path is nil and name looks like a path, then name will be used
-- as the path
M.add = function(path, name)
    if not path and not name then
        -- none given, use current directory and name
        path = vim.fn.getcwd()
        name = util.path.basename(path)
    elseif not path then
        if string.find(name, util.path.sep) then
            -- only path given, extract name from path
            path = vim.fn.fnamemodify(name, ":p")
            name = util.path.basename(path)
        else
            -- name given, use cwd as path
            path = vim.fn.getcwd()
        end
    else
        -- both given, ensure the path is expanded
        path = vim.fn.fnamemodify(path, ":p")
    end

    -- ensure path is valid
    if vim.fn.isdirectory(path) == 0 then
        vim.notify(string.format("workspaces.nvim: path `%s` does not exist", path), levels.ERROR)
        return
    end

    -- check if it already exists
    local workspaces = load_workspaces()
    for _, workspace in ipairs(workspaces) do
        if workspace.name == name or workspace.path == path then
            vim.notify("workspaces.nvim: workspace is already registered", levels.WARN)
            return
        end
    end

    table.insert(workspaces, {
        name = name,
        path = path,
    })

    store_workspaces(workspaces)
    run_hooks(config.hooks.add)
end

-- TODO: make this the default api in v1.0
M.add_swap = function(name, path)
    M.add(path, name)
end

local find = function(name)
    if not name then
        name = util.path.basename(vim.fn.getcwd())
    end

    local workspaces = load_workspaces()
    for i, workspace in ipairs(workspaces) do
        if workspace.path == name or workspace.name == name then
            return workspace, i
        end
    end

    return nil
end

-- remove a workspace from the workspaces list by name
-- name is optional, if omitted the current directory will be used
M.remove = function(name)
    local workspace, i = find(name)
    if not workspace then
        vim.notify(string.format("workspaces.nvim: workspace '%s' does not exist", name), levels.WARN)
        return
    end

    local workspaces = load_workspaces()
    table.remove(workspaces, i)
    store_workspaces(workspaces)
    run_hooks(config.hooks.remove)
end

-- returns the list of all workspaces
-- each workspace is formatted as a { name = "", path = "" } table
M.get = function()
    return load_workspaces()
end

-- displays the list of workspaces
M.list = function()
    local workspaces = load_workspaces()
    local ending = "\n"
    for i, workspace in ipairs(workspaces) do
        if #workspaces == i then ending = "" end
        print(string.format("%s %s%s", workspace.name, workspace.path, ending))
    end
end

local current_workspace = nil

-- opens the named workspace
-- this changes the current directory to the path specified in the workspace entry
M.open = function(name)
    if not name then
        vim.notify(string.format("workspaces.nvim: open requires an argument"), levels.ERROR)
        return
    end

    local workspace, i = find(name)
    if not workspace then
        vim.notify(string.format("workspaces.nvim: workspace '%s' does not exist", name), levels.WARN)
        return
    end

    -- change directory
    run_hooks(config.hooks.open_pre)
    vim.api.nvim_set_current_dir(workspace.path)
    current_workspace = workspace.name
    run_hooks(config.hooks.open)
end

---@returns string|nil
---returns the name of the current workspace
M.name = function()
    return current_workspace
end

local subcommands = {"add", "remove", "list", "open"}

local subcommand_complete = function(lead)
    return vim.tbl_filter(function(item)
        return vim.startswith(item, lead)
    end, subcommands)
end


local workspace_name_complete = function(lead)
    local workspaces = vim.tbl_filter(function(workspace)
        if lead == "" then return true end
        return vim.startswith(workspace.name, lead)
    end, load_workspaces())

    return vim.tbl_map(function(workspace)
        return workspace.name
    end, workspaces)
end

-- completion for workspace names only
M.workspace_complete = function(lead, _, _)
    return workspace_name_complete(lead)
end

-- DEPRECATED: will be removed in v1.0
-- used to provide autocomplete for user commands
M.complete = function(lead, line, pos)
    -- remove the command name from the front
    line = string.sub(line, #"Workspaces " + 1)
    pos = pos - #"Workspaces "

    -- completion for subcommands
    if #line == 0 then return subcommands end
    local index = string.find(line, " ")
    if not index or pos < index then
        return subcommand_complete(lead)
    end

    local subcommand = string.sub(line, 1, index - 1)

    -- completion not provided past 2 args
    if string.find(line, " ", index + 1) then return {} end

    -- subcommand completion for remove and open
    if subcommand == "remove" or subcommand == "open" then
        return workspace_name_complete(lead)
    end

    return {}
end

-- entry point to the api from user commands
-- subcommand is one of {add, remove, list, open}
-- and arg1 and arg2 are optional. If set arg1 is a name and arg2 is a path
M.parse_args = function(subcommand, arg1, arg2)
    vim.notify("The command :Workspaces [add|remove|list|open] is deprecated and will be removed in v1.0. Use :Workspaces[Add|Remove|List|Open] instead.", levels.WARN)
    if subcommand == "add" then
        M.add(arg2, arg1)
    elseif subcommand == "remove" then
        M.remove(arg1)
    elseif subcommand == "list" then
        M.list()
    elseif subcommand == "open" then
        M.open(arg1)
    else
        vim.notify(string.format("workspaces.nvim: invalid subcommand '%s'", subcommand), levels.ERROR)
    end
end

-- run to setup user commands and custom config
M.setup = function(opts)
    opts = opts or {}
    config = vim.tbl_deep_extend("force", {}, config, opts)

    vim.cmd[[
    command! -nargs=+ -complete=customlist,v:lua.require'workspaces'.complete Workspaces lua require("workspaces").parse_args(<f-args>)

    command! -nargs=* -complete=file WorkspacesAdd lua require("workspaces").add_swap(<f-args>)
    command! -nargs=? -complete=customlist,v:lua.require'workspaces'.workspace_complete WorkspacesRemove lua require("workspaces").remove(<f-args>)
    command! WorkspacesList lua require("workspaces").list()
    command! -nargs=1 -complete=customlist,v:lua.require'workspaces'.workspace_complete WorkspacesOpen lua require("workspaces").open(<f-args>)
    ]]
end

return M
