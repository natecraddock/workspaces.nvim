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
            vim.notify("workspaces.nvim: workspace is already registered", levels.info)
            return
        end
    end

    table.insert(w, {
        name = name,
        path = path,
    })

    store_workspaces(w)
    vim.notify("workspaces.nvim: workspace registered", levels.info)
end

local find = function(name)
    if not name then
        name = util.path.basename(vim.fn.getcwd())
    end

    local w = load_workspaces()
    for i, workspace in ipairs(w) do
        if workspace.path == name or workspace.name == name then
            return w, i
        end
    end

    return nil
end

-- remove a workspace from the workspaces list by name
-- name is optional, if omitted the current directory will be used
workspaces.remove = function(name)
    local workspace, i = find(name)
    if not workspace then
        vim.notify(string.format("workspaces.nvim: workspace '%s' does not exist", name), levels.warn)
        return
    end

    table.remove(workspace, i)
    store_workspaces(workspace)
    vim.notify("workspaces.nvim: workspace removed", levels.info)
end

-- returns the list of all workspaces
-- each workspace is formatted as { name = "", path = "" } tables
workspaces.list = function()
    return load_workspaces()
end

-- opens the named workspace
-- this changes the current directory to the path specified in the workspace entry
workspaces.open = function(name)
    local workspace, i = find(name)
    if not workspace then
        vim.notify(string.format("workspaces.nvim: workspace '%s' does not exist", name), levels.warn)
        return
    end

    vim.cmd(string.format("cd %s | enew", workspace.path))
    vim.notify(string.format("workspace.nvim: opened '%s'", workspace.name), levels.info)
end

-- TODO: user commands

return workspaces
