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
    local encode_json = code_action_config.encode_json or vim.json.encode

    return {
        title = 'Add "' .. opts.word .. '" to cspell json file',
        action = function()
            local cspell = opts.cspell or h.create_cspell_json(opts.params)

            if not cspell.config.words then
                cspell.config.words = {}
            end

            table.insert(cspell.config.words, opts.word)

            local encoded = encode_json(cspell.config) or ""
            local lines = {}
            for line in encoded:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end

            vim.fn.writefile(lines, cspell.path)

            -- replace word in buffer to trigger cspell to update diagnostics
            h.set_word(opts.diagnostic, opts.word)

            if on_success then
                on_success(cspell.path, opts.params, "add_to_json")
            end
        end,
    }
end
