local h = require("cspell.helpers")

---@class AddToJSONAction
---@field diagnostic Diagnostic
---@field word string
---@field params GeneratorParams
---@field cspell CSpellConfigInfo|nil

---@param opts AddToJSONAction
---@return CodeAction
return function(opts)
    ---@type CSpellSourceConfig
    local code_action_config = opts.params:get_config()
    local on_success = code_action_config.on_success
    local on_add_to_json = code_action_config.on_add_to_json
    local encode_json = code_action_config.encode_json or vim.json.encode
    -- The null-ls diagnostic reports the wrong range for the CSpell error if
    -- the line contains a unicode character.
    -- As a workaround, we read the misspelled word from the diagnostic's
    -- user_data. And only use the word from the range to trigger a new diagnostic.
    -- See: https://github.com/jose-elias-alvarez/null-ls.nvim/issues/1630
    local misspelled_word = opts.diagnostic.user_data.misspelled

    return {
        title = 'Add "' .. misspelled_word .. '" to cspell json file',
        action = function()
            local cspell = opts.cspell or h.create_cspell_json(opts.params)

            if not cspell.config.words then
                cspell.config.words = {}
            end

            table.insert(cspell.config.words, misspelled_word)

            local encoded = encode_json(cspell.config) or ""
            local lines = {}
            for line in encoded:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end

            vim.fn.writefile(lines, cspell.path)
            vim.notify(
                'Added "' .. misspelled_word .. '" to ' .. cspell.path,
                vim.log.levels.INFO,
                { title = "cspell.nvim" }
            )

            -- replace word in buffer to trigger cspell to update diagnostics
            h.set_word(opts.diagnostic, opts.word)
            vim.cmd([[:silent :undo]])

            if on_success then
                vim.notify_once(
                    "The on_success callback is deprecated, use on_add_to_json instead",
                    vim.log.levels.INFO,
                    { title = "cspell.nvim" }
                )
                on_success(cspell.path, opts.params, "add_to_json")
            end

            if on_add_to_json then
                ---@type AddToJSONSuccess
                local add_to_json_success = {
                    new_word = misspelled_word,
                    cspell_config_path = cspell.path,
                    generator_params = opts.params,
                }
                on_add_to_json(add_to_json_success)
            end
        end,
    }
end
