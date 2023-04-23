local h = require("cspell.helpers")

---@param diagnostic Diagnostic
---@param word string
---@param cspell CSpellConfigInfo
---@return CodeAction
return function(diagnostic, word, cspell)
    return {
        title = 'Add "' .. word .. '" to cspell json file',
        action = function()
            if not cspell.config.words then
                cspell.config.words = {}
            end

            table.insert(cspell.config.words, word)

            vim.fn.writefile({ vim.json.encode(cspell.config) }, cspell.path)

            -- replace word in buffer to trigger cspell to update diagnostics
            h.set_word(diagnostic, word)
        end,
    }
end
