local h = require("cspell.helpers")

---@param diagnostic Diagnostic
---@param word string
---@param params GeneratorParams
---@param cspell CSpellConfigInfo|nil
---@return CodeAction
return function(diagnostic, word, params, cspell)
    return {
        title = 'Add "' .. word .. '" to cspell json file',
        action = function()
            cspell = cspell or h.create_cspell_json(params)

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
