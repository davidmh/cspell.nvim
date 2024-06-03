local Path = require("plenary.path")
local h = require("cspell.helpers")

---@class AddToJSONAction
---@field diagnostic Diagnostic
---@field word string
---@field cspell_config_path string
---@field params GeneratorParams

---@param opts AddToJSONAction
---@return CodeAction
return function(opts)
    -- The null-ls diagnostic reports the wrong range for the CSpell error if
    -- the line contains a unicode character.
    -- As a workaround, we read the misspelled word from the diagnostic's
    -- user_data. And only use the word from the range to trigger a new diagnostic.
    -- See: https://github.com/jose-elias-alvarez/null-ls.nvim/issues/1630
    local misspelled_word = opts.diagnostic.user_data.misspelled

    return {
        title = h.format(
            'Add "${word}" to "${config_path}"',
            { word = misspelled_word, config_path = h.shorten_path(opts.cspell_config_path) }
        ),

        action = function()
            local cspell_config_path = opts.cspell_config_path
            -- get a fresh config when the action is performed, which can be much later than when the action was generated
            local cspell = h.async_get_config_info(opts.params, cspell_config_path)
            local path_exists = Path:new(cspell_config_path):exists()
            if not cspell and path_exists then
                h.cache_word_for_json(misspelled_word)
                return
            end

            cspell = cspell or h.create_default_cspell_json(opts.params, cspell_config_path)

            if not cspell.config.words then
                cspell.config.words = {}
            end

            h.add_words_to_json(opts.params, { misspelled_word }, cspell_config_path)

            -- replace word in buffer to trigger cspell to update diagnostics
            h.set_word(opts.diagnostic, opts.word)
            vim.cmd([[:silent :undo]])
        end,
    }
end
