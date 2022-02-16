local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local telescope = require("telescope")

local workspaces = require("workspaces")

local keep_insert = false

local workspaces_picker = function(opts)
    -- compute spacing
    local workspaces_list = workspaces.get()
    local width = 10
    for _, workspace in ipairs(workspaces_list) do
        if #workspace.name > width then
            width = #workspace.name + 2
        end
    end

    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = width },
            {},
        },
    })

    opts = opts or {}
    pickers.new(opts, {
        prompt_title = "Workspaces",

        finder = finders.new_table({
            results = workspaces_list,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = function(entry)
                        return displayer({
                            { entry.ordinal },
                            { entry.value.path, "String" },
                        })
                    end,
                    ordinal = entry.name,
                }
            end
        }),

        sorter = conf.generic_sorter(opts),

        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)

                -- we could use actions._close(prompt_bufnr, keep_insert), but
                -- this seems to have race conditions.
                -- so instead we schedule a function to run in the future to
                -- maintain insert mode after telescope closes if desired.
                if keep_insert then
                    vim.schedule(function() vim.cmd("startinsert") end)
                end

                local selected = action_state.get_selected_entry()
                if not selected then return end

                local workspace = selected.value
                if workspace and workspace ~= "" then
                    workspaces.open(workspace.name)
                end
            end)
            return true
        end,
    }):find()
end

return telescope.register_extension({
    setup = function(ext_config)
        if ext_config.keep_insert then
            keep_insert = ext_config.keep_insert
        end
    end,

    exports = {
        workspaces = function(opts)
            workspaces_picker(opts)
        end,
    },
})
