local h = require("cspell.helpers")

---@param diagnostic Diagnostic
---@param word string
---@param dictionary CSpellDictionary
return function(diagnostic, word, dictionary)
    return {
        title = 'Add "' .. word .. '" to dictionary "' .. dictionary.name .. '"',
        action = function()
            if dictionary == nil then
                return
            end
            local dictionary_path = vim.fn.expand(dictionary.path)
            local dictionary_ok, dictionary_body = pcall(vim.fn.readfile, dictionary_path)
            if not dictionary_ok then
                vim.notify("Can't read " .. dictionary_path, vim.log.levels.ERROR)
                return
            end
            table.insert(dictionary_body, word)

            vim.fn.writefile(dictionary_body, dictionary_path)
            vim.notify('Added "' .. word .. '" to ' .. dictionary.path, vim.log.levels.INFO)

            -- replace word in buffer to trigger cspell to update diagnostics
            h.set_word(diagnostic, word)
        end,
    }
end
