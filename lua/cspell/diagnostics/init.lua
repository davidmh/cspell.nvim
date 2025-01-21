local h = require("null-ls.helpers")
local u = require("null-ls.utils")
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
            local cspell_args = {
                "lint",
                "--language-id",
                params.ft,
                "stdin://" .. params.bufname,
            }
            helpers.update_params_cwd(params)

            ---@type CSpellSourceConfig
            local diagnostics_config = params and params:get_config() or {}

            ---@type table<number|string, string>
            local cspell_config_paths = params and params:get_config().cspell_import_files or {}

            local cspell_config_directories = diagnostics_config.cspell_config_dirs or {}
            table.insert(cspell_config_directories, params.cwd)

            for _, cspell_config_directory in pairs(cspell_config_directories) do
                local cspell_config_path = helpers.get_config_path(params, cspell_config_directory)
                if cspell_config_path == nil then
                    cspell_config_path = helpers.generate_cspell_config_path(params, cspell_config_directory)
                end
                cspell_config_paths[cspell_config_directory] = cspell_config_path
            end
            local merged_config = helpers.create_merged_cspell_json(params, cspell_config_paths)

            cspell_args = vim.list_extend({ "-c", merged_config.path }, cspell_args)

            local code_action_source = require("null-ls.sources").get({
                name = "cspell",
                method = methods.internal.CODE_ACTION,
            })[1]

            if code_action_source ~= nil then
                -- only enable suggestions when using the code actions built-in, since they slow down the command
                cspell_args = vim.list_extend({ "--show-suggestions" }, cspell_args)

                local code_action_config = code_action_source.config or {}

                if helpers.matching_configs(code_action_config, diagnostics_config) then
                    -- warm up the config cache so we have the config ready by the time we call the code action
                    helpers.async_get_config_info(params, cspell_config_paths[params.cwd])
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
