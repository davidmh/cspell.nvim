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

    return {
        title = 'Add "' .. opts.word .. '" to dictionary "' .. opts.dictionary.name .. '"',
        action = function()
            if opts.dictionary == nil then
                return
            end
            local dictionary_path = vim.fn.expand(opts.dictionary.path)
            local dictionary_ok, dictionary_body = pcall(vim.fn.readfile, dictionary_path)
            if not dictionary_ok then
                vim.notify("Can't read " .. dictionary_path, vim.log.levels.ERROR)
                return
            end
            table.insert(dictionary_body, opts.word)

            vim.fn.writefile(dictionary_body, dictionary_path)
            vim.notify('Added "' .. opts.word .. '" to ' .. opts.dictionary.path, vim.log.levels.INFO)

            -- replace word in buffer to trigger cspell to update diagnostics
            h.set_word(opts.diagnostic, opts.word)

            if on_success then
                on_success(opts.cspell.path, opts.params, "add_to_dictionary")
            end
        end,
    }
end
