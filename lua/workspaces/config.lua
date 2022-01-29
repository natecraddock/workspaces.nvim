local util = require("workspaces.util")

local default = {
    -- path to a file to store workspaces data in
    path = vim.fn.stdpath("data") .. util.path.sep .. "workspaces",

    -- lists of hooks to run after specific actions
    -- hooks can be a lua function or a vim command (string)
    hooks = {
        add = {},
        remove = {},
        open = {},
    },

    -- set to true to keep the telescope workspaces picker in insert mode after
    -- selection, useful when chaining multiple pickers with hooks
    telescope_keep_insert = false,
}

local M = {}

M.config = default

M.setup = function(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", {}, default, opts)
end

return M
