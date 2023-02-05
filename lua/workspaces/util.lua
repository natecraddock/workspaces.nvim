local M = {}

local levels = vim.log.levels
local uv = vim.loop

-- get datetime
M.date = function()
    return os.date("%Y-%m-%dT%H:%M:%S")
end

-- vim.notify wrappers
M.notify = {}
M.notify.info = function(message)
    vim.notify(message, levels.INFO, { title = "workspaces.nvim" })
end

M.notify.warn = function(message)
    vim.notify(message, levels.WARN, { title = "workspaces.nvim" })
end

M.notify.err = function(message)
    vim.notify(message, levels.ERROR, { title = "workspaces.nvim" })
end

-- system dependent path separator from plenary.nvim
M.path = {}
M.path.sep = (function()
    if jit then
        local os = string.lower(jit.os)
        if os == "linux" or os == "osx" or os == "bsd" then
            return "/"
        else
            return "\\"
        end
    else
        return package.config:sub(1, 1)
    end
end)()

local get_path_parts = function(path_str)
    -- remove ending /
    if string.sub(path_str, #path_str, #path_str) == M.path.sep then
        path_str = string.sub(path_str, 1, #path_str - 1)
    end

    return vim.split(path_str, M.path.sep)
end

M.path.basename = function(path_str)
    local parts = get_path_parts(path_str)
    return parts[#parts]
end

M.path.parent = function(path_str)
    local parts = get_path_parts(path_str)
    local path = ""
    for i, part in ipairs(parts) do
        if part ~= "" and i ~= #parts then
            path = path .. M.path.sep .. part
        end
    end

    return path .. M.path.sep
end

-- read a file into a string (synchronous)
M.file = {}
M.file.read = function(path)
    local fd = uv.fs_open(path, "r", 438)
    if not fd then
        return nil
    end

    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))
    return data
end

-- write a string to a file (synchronous)
M.file.write = function(path, data)
    local fd = assert(uv.fs_open(path, "w", 438))
    assert(uv.fs_write(fd, data, 0))
end

M.dir = {}
M.dir.read = function(path)
    local normalized_path = vim.fs.normalize(path)
    local handle = uv.fs_scandir(normalized_path)

    if not handle then
        return nil, "Directory not found"
    end

    local directories = {}
    local empty = true
    while true do
        local name, type = uv.fs_scandir_next(handle)
        if name == nil then
            break
        end
        if type == "directory" then
            if empty then
                empty = false
            end
            table.insert(directories, normalized_path .. M.path.sep .. name)
        end
    end

    if empty then
        return nil, "There are no folders in this directory"
    else
        return directories
    end
end

return M
