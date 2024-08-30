local Path = require("plenary.path")
local h = require("cspell.helpers")

---@class AddToDictionaryAction
---@field diagnostic Diagnostic
---@field word string
---@field params GeneratorParams
---@field cspell CSpellConfigInfo
---@field dictionary CSpellDictionary

---@param opts AddToDictionaryAction
---@return CodeAction
return function(opts)
    ---@type CSpellSourceConfig
    local code_action_config = opts.params:get_config()
    local on_success = code_action_config.on_success
    local on_add_to_dictionary = code_action_config.on_add_to_dictionary
    -- The null-ls diagnostic reports the wrong range for the CSpell error if
    -- the line contains a unicode character.
    -- As a workaround, we read the misspelled word from the diagnostic's
    -- user_data. And only use the word from the range to trigger a new diagnostic.
    -- See: https://github.com/jose-elias-alvarez/null-ls.nvim/issues/1630
    local misspelled_word = opts.diagnostic.user_data.misspelled

    return {
        title = 'Add "' .. misspelled_word .. '" to dictionary "' .. opts.dictionary.name .. '"',
        action = function()
            if opts.dictionary == nil then
                return
            end
            local dictionary_path = Path:new(vim.fn.expand(opts.dictionary.path))
            local resolved_path = dictionary_path:is_file() and dictionary_path:absolute()
                or Path:new(opts.cspell.path):parent():joinpath(dictionary_path):absolute()
            local dictionary_ok, dictionary_body = pcall(vim.fn.readfile, resolved_path)
            if not dictionary_ok then
                vim.notify("Can't read " .. resolved_path, vim.log.levels.ERROR, { title = "cspell.nvim" })
                return
            end
            table.insert(dictionary_body, misspelled_word)

            vim.fn.writefile(dictionary_body, resolved_path)
            vim.notify(
                'Added "' .. misspelled_word .. '" to ' .. opts.dictionary.path,
                vim.log.levels.INFO,
                { title = "cspell.nvim" }
            )

            -- replace word in buffer to trigger cspell to update diagnostics
            h.set_word(opts.diagnostic, opts.word)
            vim.cmd([[:silent :undo]])

            if on_success then
                vim.notify_once(
                    "The on_success callback is deprecated, use on_add_to_dictionary instead",
                    vim.log.levels.INFO,
                    { title = "cspell.nvim" }
                )
                on_success(opts.cspell.path, opts.params, "add_to_dictionary")
            end

            if on_add_to_dictionary then
                ---@type AddToDictionarySuccess
                local payload = {
                    new_word = misspelled_word,
                    generator_params = opts.params,
                    cspell_config_path = opts.cspell.path,
                    dictionary_path = opts.dictionary.path,
                }
                on_add_to_dictionary(payload)
            end
        end,
    }
end
