local M = {}

local uv = vim.loop
local levels = vim.log.levels

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

M.path.basename = function(path_str)
    local parts = vim.split(path_str, M.path.sep)
    return parts[#parts]
end

-- read a file into a string (synchronous)
M.file = {}
M.file.read = function(path)
    local fd = uv.fs_open(path, "r", 438)
    if not fd then return nil end

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

return M
