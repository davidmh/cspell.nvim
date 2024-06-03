local mock = require("luassert.mock")
local stub = require("luassert.stub")

local Path = require("plenary.path")

local diagnostics = require("cspell.diagnostics")
local code_actions = require("cspell.code_actions")
local helpers = require("cspell.helpers")

local uv = vim.loop

local CSPELL_CONFIG_PATH = uv.fs_realpath("./cspell.json")

local CACHE_KEY = Path:new("."):joinpath("cspell.json"):absolute():gsub("/", "%%")

local CSPELL_MERGED_CONFIG_PATH = Path:new(".tests/cache/nvim/cspell.nvim"):joinpath(CACHE_KEY):expand()

mock(require("null-ls.logger"), true)

describe("diagnostics", function()
    local content = [[local misspelled_variabl = 'hi']]

    describe("parser", function()
        local parser = diagnostics._opts.on_output

        it("should create a diagnostic", function()
            local output = "/some/path/file.lua:1:18 - Unknown word (variabl)"
            local diagnostic = parser(output, { content = content })

            assert.same({
                col = "18",
                message = "Unknown word (variabl)",
                row = "1",
            }, diagnostic)
        end)

        it("includes suggestions", function()
            local output =
                "/some/path/file.lua:1:18 - Unknown word (variabl) Suggestions: [variable, variably, variables, variant, variate]"
            local diagnostic = parser(output, { content = content })

            assert.same({
                col = "18",
                message = "Unknown word (variabl)",
                row = "1",
                user_data = {
                    misspelled = "variabl",
                    suggestions = { "variable", "variably", "variables", "variant", "variate" },
                },
            }, diagnostic)
        end)
    end)

    describe("args", function()
        local args
        local get_source
        local async_get_config_info
        local args_fn = diagnostics._opts.args

        -- fixtures
        local misspelled = "variabl"
        local buf_diagnostics = {
            {
                bufnr = 1890,
                col = 17,
                end_col = 24,
                end_lnum = 0,
                lnum = 0,
                message = string.format("Unknown word (%s)", misspelled),
                namespace = 35,
                row = "1",
                severity = 2,
                source = "cspell",
                user_data = {
                    misspelled = misspelled,
                    suggestions = { "variable", "variably", "varia", "varian", "variant" },
                },
            },
        }

        local get_add_to_json_action = function(generator_params)
            local add_to_json_action
            local actions = code_actions.generator.fn(generator_params)
            for _, action in ipairs(actions) do
                local expected_action_title = 'to "' .. helpers.shorten_path(generator_params.cwd)
                if action.title:match(expected_action_title) then
                    add_to_json_action = action
                    break
                end
            end
            return add_to_json_action
        end

        describe("without code actions", function()
            before_each(function()
                helpers.clear_cache()
                async_get_config_info = stub(helpers, "async_get_config_info")
                get_source = stub(require("null-ls.sources"), "get")
                get_source.returns({})
                args = args_fn({
                    ft = "lua",
                    bufname = "file.txt",
                    get_config = function()
                        return {}
                    end,
                })
            end)

            after_each(function()
                get_source:revert()
                async_get_config_info:revert()
            end)

            it("won't try to load the cspell config file", function()
                assert.stub(async_get_config_info).was_not_called()
            end)

            it("does not include a suggestions param", function()
                assert.same({
                    "-c",
                    CSPELL_MERGED_CONFIG_PATH,
                    "lint",
                    "--language-id",
                    "lua",
                    "stdin://file.txt",
                }, args)
            end)
        end)

        describe("with code actions", function()
            before_each(function()
                helpers.clear_cache()
                async_get_config_info = stub(helpers, "async_get_config_info")
                get_source = stub(require("null-ls.sources"), "get")
                get_source.returns({ code_actions })
                args = args_fn({
                    ft = "lua",
                    bufname = "file.txt",
                    get_config = function()
                        return {}
                    end,
                })
            end)

            after_each(function()
                get_source:revert()
                async_get_config_info:revert()
            end)

            it("warms up the config cache", function()
                assert.stub(async_get_config_info).was_called()
            end)

            it("includes a suggestions param", function()
                assert.same({
                    "--show-suggestions",
                    "-c",
                    CSPELL_MERGED_CONFIG_PATH,
                    "lint",
                    "--language-id",
                    "lua",
                    "stdin://file.txt",
                }, args)
            end)
        end)

        describe("with custom json config file", function()
            before_each(function()
                helpers.clear_cache()
                async_get_config_info = stub(helpers, "async_get_config_info")
                get_source = stub(require("null-ls.sources"), "get")
                get_source.returns({})
            end)

            after_each(function()
                get_source:revert()
                async_get_config_info:revert()
                Path:new(CSPELL_MERGED_CONFIG_PATH):rm({})
            end)

            it("includes a suggestions param", function()
                args = args_fn({
                    ft = "lua",
                    bufname = "file.txt",
                    get_config = function()
                        return {
                            find_json = function()
                                return "some/custom/path/cspell.json"
                            end,
                        }
                    end,
                })

                assert.same({
                    "-c",
                    CSPELL_MERGED_CONFIG_PATH,
                    "lint",
                    "--language-id",
                    "lua",
                    "stdin://file.txt",
                }, args)

                local merged_config = vim.json.decode(Path:new(CSPELL_MERGED_CONFIG_PATH):read())

                assert.is_table(merged_config)
                assert.truthy(merged_config["import"] ~= nil)

                assert.is_table(merged_config.import)
                assert.truthy(vim.tbl_contains(merged_config.import, "some/custom/path/cspell.json"))
            end)
        end)

        describe("when there are no existing config files", function()
            local vim_diagnostic
            local vim_api_nvim_buf_get_text
            local vim_api_nvim_buf_set_text
            -- fixtures
            local generator_params = {
                cwd = vim.loop.cwd(),
                ft = "lua",
                bufnr = 1890,
                row = "1",
                col = 17,
                get_config = function()
                    return {
                        config_file_preferred_name = ".cSpell.json",
                        find_json = function(_)
                            local path = Path:new("."):joinpath(".cSpell.json")
                            if path:exists() then
                                return path:absolute()
                            end
                        end,
                    }
                end,
            }

            before_each(function()
                helpers.clear_cache()
                vim_diagnostic = stub(vim.diagnostic, "get")
                vim_diagnostic.returns(buf_diagnostics)
                async_get_config_info = stub(helpers, "async_get_config_info")
                vim_api_nvim_buf_get_text = stub(vim.api, "nvim_buf_get_text")
                vim_api_nvim_buf_get_text.returns({ { misspelled } })
                vim_api_nvim_buf_set_text = stub(vim.api, "nvim_buf_set_text")
            end)
            after_each(function()
                vim_diagnostic:revert()
                async_get_config_info:revert()
                vim_api_nvim_buf_get_text:revert()
                vim_api_nvim_buf_set_text:revert()
                Path:new("./.cSpell.json"):rm()
            end)

            it("creates a new config file in cwd", function()
                local add_to_json_action = get_add_to_json_action(generator_params)

                assert.is_not_nil(add_to_json_action)
                add_to_json_action.action({
                    diagnostic = buf_diagnostics[1],
                    word = misspelled,
                    params = generator_params,
                })
                assert.truthy(Path:new("./.cSpell.json"):exists())
            end)
        end)

        describe("with read_config_synchronously = false,", function()
            local orig_config_str = Path:new(CSPELL_CONFIG_PATH):read()
            local config
            local vim_diagnostic
            local vim_api_nvim_buf_get_text
            local vim_api_nvim_buf_set_text
            local existing_word = "foo"
            local sync_get_config_info
            local vim_loop_new_async = vim.loop.new_async

            -- fixtures
            local generator_params = {
                cwd = vim.loop.cwd(),
                ft = "lua",
                bufnr = 1890,
                row = "1",
                col = 17,
                get_config = function()
                    return {
                        read_config_synchronously = false,
                    }
                end,
            }

            before_each(function()
                helpers.clear_cache()
                config = vim.json.decode(orig_config_str)
                config.words[#config.words + 1] = existing_word
                Path:new(CSPELL_CONFIG_PATH):write(vim.json.encode(config), "w")

                vim_diagnostic = stub(vim.diagnostic, "get")
                vim_diagnostic.returns(buf_diagnostics)
                vim_api_nvim_buf_get_text = stub(vim.api, "nvim_buf_get_text")
                vim_api_nvim_buf_get_text.returns({ { misspelled } })
                vim_api_nvim_buf_set_text = stub(vim.api, "nvim_buf_set_text")

                -- avoid async otherwise it writes after our tests
                vim.loop.new_async = function(callback)
                    return {
                        send = callback,
                        close = function() end,
                    }
                end
            end)

            after_each(function()
                Path:new(CSPELL_CONFIG_PATH):write(orig_config_str, "w")
                vim_diagnostic:revert()
                vim_api_nvim_buf_get_text:revert()
                vim_api_nvim_buf_set_text:revert()
                vim.loop.new_async = vim_loop_new_async
            end)

            describe("config file has been read", function()
                before_each(function()
                    async_get_config_info = stub(helpers, "async_get_config_info")
                    async_get_config_info.returns({
                        config = config,
                        path = CSPELL_CONFIG_PATH,
                    })
                end)

                after_each(function()
                    async_get_config_info:revert()
                end)

                it("can add the misspelled word to JSON via an action", function()
                    local add_to_json_action = get_add_to_json_action(generator_params)

                    assert.is_not_nil(add_to_json_action)
                    add_to_json_action.action({
                        diagnostic = buf_diagnostics[1],
                        word = misspelled,
                        params = generator_params,
                    })

                    assert.stub(vim_api_nvim_buf_get_text).was_called()
                    assert.stub(vim_api_nvim_buf_set_text).was_called()

                    local updated_config = vim.json.decode(Path:new(CSPELL_CONFIG_PATH):read())
                    assert.is_table(updated_config.words)
                    assert.truthy(vim.tbl_contains(updated_config.words, misspelled))
                    assert.truthy(vim.tbl_contains(updated_config.words, existing_word))
                end)
            end)

            describe("config reading is in progress", function()
                before_each(function()
                    async_get_config_info = stub(helpers, "async_get_config_info")
                    async_get_config_info.returns(nil)
                    sync_get_config_info = stub(helpers, "sync_get_config_info")
                    sync_get_config_info.returns({ config = config, path = CSPELL_CONFIG_PATH })
                end)

                after_each(function()
                    async_get_config_info:revert()
                    sync_get_config_info:revert()
                end)

                it("caches the misspelled word and adds it to JSON after reading", function()
                    local add_to_json_action = get_add_to_json_action(generator_params)

                    assert.is_not_nil(add_to_json_action)
                    add_to_json_action.action({
                        diagnostic = buf_diagnostics[1],
                        word = misspelled,
                        params = generator_params,
                    })

                    local updated_config = vim.json.decode(Path:new(CSPELL_CONFIG_PATH):read())
                    assert.is_table(updated_config.words)
                    assert.truthy(vim.tbl_contains(updated_config.words, existing_word))
                    assert.stub(async_get_config_info).was_called()
                    assert.stub(sync_get_config_info).was_not_called()
                    assert.stub(vim_api_nvim_buf_get_text).was_called()
                    assert.stub(vim_api_nvim_buf_set_text).was_not_called()

                    async_get_config_info:revert()
                    get_add_to_json_action(generator_params)

                    updated_config = vim.json.decode(Path:new(CSPELL_CONFIG_PATH):read())
                    assert.is_table(updated_config.words)
                    assert.truthy(vim.tbl_contains(updated_config.words, existing_word))
                    assert.truthy(vim.tbl_contains(updated_config.words, misspelled))
                    assert.stub(sync_get_config_info).was_called()
                end)
            end)
        end)
    end)
end)
