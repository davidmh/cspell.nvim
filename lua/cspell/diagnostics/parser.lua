local h = require("null-ls.helpers")

local custom_user_data = {
    user_data = function(entries, _)
        if not entries then
            return
        end

        local suggestions = {}
        for suggestion in string.gmatch(entries["_suggestions"], "[^, ]+") do
            table.insert(suggestions, suggestion)
        end

        return {
            suggestions = suggestions,
            misspelled = entries["_quote"],
        }
    end,
}

-- Finds the messages including a suggestions array, which comes from passing
-- the --show-suggestions flag to cspell.
-- That flag is only available when the user has registered the code action.
local matcher_with_suggestions = {
    pattern = ".*:(%d+):(%d+)%s*-%s*(.*%((.*)%))%s*Suggestions:%s*%[(.*)%]",
    groups = { "row", "col", "message", "_quote", "_suggestions" },
    overrides = {
        adapters = {
            h.diagnostics.adapters.end_col.from_quote,
            custom_user_data,
        },
    },
}

-- Finds the messages without a suggestions array.
-- This will be the format used when only the cspell.nvim diagnostics are
-- registered. So there's no need to pass the user_data table, since it's only
-- used by the code actions.
local matcher_without_suggestions = {
    pattern = [[.*:(%d+):(%d+)%s*-%s*(.*%((.*)%))]],
    groups = { "row", "col", "message", "_quote" },
    overrides = {
        adapters = {
            h.diagnostics.adapters.end_col.from_quote,
        },
    },
}

-- To see the difference between the two matchers, see:
-- https://github.com/davidmh/cspell.nvim/issues/32#issuecomment-1815780887
return h.diagnostics.from_patterns({
    matcher_with_suggestions,
    matcher_without_suggestions,
})
