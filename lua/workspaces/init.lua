local levels = vim.log.levels
local util = require("workspaces.util")

-- path in which to store the list of workspaces
local workspaces_path = vim.fn.stdpath("data") .. util.path.sep .. "workspaces"

-- loads the workspaces from the datafile into a table
-- the workspace file format is:
-- * newline separated workspace entries
-- * NULL (\0) separated (name, path) pairs
local load_workspaces = function()
    local data = util.file.read(workspaces_path)

    -- if the file has not yet been created, add an empty file
    if not data then
        util.file.write(workspaces_path, "")
        data = util.file.read(workspaces_path)
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
    util.file.write(workspaces_path, data)
end

local workspaces = {}

-- add a workspace to the workspaces list
-- path is optional, if omitted the current directory will be used
-- name is optional, if omitted the path will be used
workspaces.add = function(path, name)
    path = path or vim.fn.getcwd()
    if not name then
        name = util.path.basename(path)
    end

    local w = load_workspaces()
    for _, workspace in ipairs(w) do
        if workspace.name == name or workspace.path == path then
            vim.notify("workspaces.nvim: workspace is already registered", levels.WARN)
            return
        end
    end

    table.insert(w, {
        name = name,
        path = path,
    })

    store_workspaces(w)
end

local find = function(name)
    if not name then
        name = util.path.basename(vim.fn.getcwd())
    end

    local w = load_workspaces()
    for i, workspace in ipairs(w) do
        if workspace.path == name or workspace.name == name then
            return workspace, i
        end
    end

    return nil
end

-- remove a workspace from the workspaces list by name
-- name is optional, if omitted the current directory will be used
workspaces.remove = function(name)
    local workspace, i = find(name)
    if not workspace then
        vim.notify(string.format("workspaces.nvim: workspace '%s' does not exist", name), levels.WARN)
        return
    end

    local w = load_workspaces()
    table.remove(w, i)
    store_workspaces(w)
end

-- returns the list of all workspaces
-- each workspace is formatted as { name = "", path = "" } tables
workspaces.list = function()
    print(vim.inspect(load_workspaces()))
end

-- opens the named workspace
-- this changes the current directory to the path specified in the workspace entry
workspaces.open = function(name)
    local workspace, i = find(name)
    if not workspace then
        vim.notify(string.format("workspaces.nvim: workspace '%s' does not exist", name), levels.WARN)
        return
    end

    -- change directory and open a new scratch buffer
    vim.cmd(string.format("cd %s | noswapfile hide enew", workspace.path))
    vim.cmd[[
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    ]]
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

-- used to provide autocomplete for user commands
workspaces.complete = function(lead, line, pos)
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
workspaces.parse_args = function(subcommand, arg1, arg2)
    if subcommand == "add" then
        workspaces.add(arg2, arg1)
    elseif subcommand == "remove" then
        workspaces.remove(arg1)
    elseif subcommand == "list" then
        workspaces.list()
    elseif subcommand == "open" then
        workspaces.open(arg1)
    else
        vim.notify(string.format("workspaces.nvim: invalid subcommand '%s'", subcommand), levels.ERROR)
    end
end

-- run to setup user commands
workspaces.setup = function(opts)
    vim.cmd[[
    command! -nargs=+ -complete=customlist,v:lua.require'workspaces'.complete Workspaces lua require("workspaces").parse_args(<f-args>)
    ]]
end

return workspaces
