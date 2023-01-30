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

M.path.basename = function(path_str)
	-- remove ending /
	if string.sub(path_str, #path_str, #path_str) == M.path.sep then
		path_str = string.sub(path_str, 1, #path_str - 1)
	end
	local parts = vim.split(path_str, M.path.sep)
	return parts[#parts]
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
	-- TODO make it work for windows
	local last_char = string.sub(path, string.len(path))
	local end_path_command = "/*/"

	if last_char == "/" then
		end_path_command = "*/"
	end

	local pdir, err = io.popen("ls -d " .. path .. end_path_command)
	if not pdir or err then
		return nil
	end

	local directories = {}
	for line in pdir:lines() do
		if line then
			table.insert(directories, line)
		end
	end

	pdir.close(pdir)

	return directories
end

return M
