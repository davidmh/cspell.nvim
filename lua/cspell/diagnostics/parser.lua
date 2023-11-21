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

--- CSpell doesn't care about multi-byte characters when calculating the
--- column number for the start of the error. Forwarding the column number
--- as reported by CSpell, would cause the error to be diagnostic to highlight
--- the wrong range.
--- So we delegate that value as a helper property that will help us find the
--- start and end of the word.
local custom_from_quote = {
    end_col = function(entries, line)
        local quote = entries["_quote"]
        --- We use the column reported by CSpell as the start index to find the
        --- current word in the line, in case the word shows up multiple times
        --- in the same line.
        local col, end_col = line:find(quote, entries["_col"], true)
        --- HACK: Since the column reported by CSpell may not match the column
        --- as counted by lua, we're mutating the entries table to define the
        --- column property here, so we can account for special characters.
        entries["col"] = col
        return end_col + 1
    end,
}

-- Finds the messages including a suggestions array, which comes from passing
-- the --show-suggestions flag to cspell.
-- That flag is only available when the user has registered the code action.
local matcher_with_suggestions = {
    pattern = ".*:(%d+):(%d+)%s*-%s*(.*%((.*)%))%s*Suggestions:%s*%[(.*)%]",
    groups = { "row", "_col", "message", "_quote", "_suggestions" },
    overrides = {
        adapters = {
            custom_from_quote,
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
    groups = { "row", "_col", "message", "_quote" },
    overrides = {
        adapters = {
            custom_from_quote,
        },
    },
}

-- To see the difference between the two matchers, see:
-- https://github.com/davidmh/cspell.nvim/issues/32#issuecomment-1815780887
return h.diagnostics.from_patterns({
    matcher_with_suggestions,
    matcher_without_suggestions,
})
