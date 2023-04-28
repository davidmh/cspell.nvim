local h = require("cspell.helpers")

---@param diagnostic Diagnostic
---@param word string
---@param params GeneratorParams
---@param cspell CSpellConfigInfo|nil
---@return CodeAction
return function(diagnostic, word, params, cspell)
    ---@type CSpellCodeActionSourceConfig
    local code_action_config = params:get_config()
    local encode_json = code_action_config.encode_json or vim.json.encode

    return {
        title = 'Add "' .. word .. '" to cspell json file',
        action = function()
            cspell = cspell or h.create_cspell_json(params)

            if not cspell.config.words then
                cspell.config.words = {}
            end

            table.insert(cspell.config.words, word)

            local encoded = encode_json(cspell.config) or ""
            local lines = {}
            for line in encoded:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end

            vim.fn.writefile(lines, cspell.path)

            -- replace word in buffer to trigger cspell to update diagnostics
            h.set_word(diagnostic, word)
        end,
    }
end
