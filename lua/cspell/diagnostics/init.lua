local h = require("null-ls.helpers")
local methods = require("null-ls.methods")
local helpers = require("cspell.helpers")
local parser = require("cspell.diagnostics.parser")

local DIAGNOSTICS = methods.internal.DIAGNOSTICS

local needs_warning = true

return h.make_builtin({
    name = "cspell",
    meta = {
        url = "https://github.com/streetsidesoftware/cspell",
        description = "cspell is a spell checker for code.",
    },
    method = DIAGNOSTICS,
    filetypes = {},
    generator_opts = {
        command = "cspell",
        ---@param params GeneratorParams
        args = function(params)
            params.cwd = params.cwd or vim.loop.cwd()

            local cspell_args = {
                "lint",
                "--language-id",
                params.ft,
                "stdin://" .. params.bufname,
            }

            local config_path = helpers.get_config_path(params)
            if config_path then
                cspell_args = vim.list_extend({ "-c", config_path }, cspell_args)
            end

            local code_action_source = require("null-ls.sources").get({
                name = "cspell",
                method = methods.internal.CODE_ACTION,
            })[1]

            if code_action_source ~= nil then
                -- only enable suggestions when using the code actions built-in, since they slow down the command
                cspell_args = vim.list_extend({ "--show-suggestions" }, cspell_args)

                local code_action_config = code_action_source.config or {}
                local diagnostics_config = params and params:get_config() or {}

                if helpers.matching_configs(code_action_config, diagnostics_config) then
                    -- warm up the config cache so we have the config ready by the time we call the code action
                    helpers.async_get_config_info(params)
                elseif needs_warning then
                    needs_warning = false
                    vim.notify(
                        "You should use the same config for both sources",
                        vim.log.levels.WARN,
                        { title = "cspell.nvim" }
                    )
                end
            end

            return cspell_args
        end,
        to_stdin = true,
        ignore_stderr = true,
        format = "line",
        check_exit_code = function(code)
            return code <= 1
        end,
        on_output = parser,
    },
    factory = h.generator_factory,
})
