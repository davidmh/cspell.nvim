local mock = require("luassert.mock")
local stub = require("luassert.stub")

local diagnostics = require("cspell.diagnostics")
local code_actions = require("cspell.code_actions")
local helpers = require("cspell.helpers")

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

        describe("without code actions", function()
            before_each(function()
                async_get_config_info = stub(helpers, "async_get_config_info")
                get_source = stub(require("null-ls.sources"), "get")
                get_source.returns({})
                args = args_fn({ ft = "lua" })
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
                    "lint",
                    "--language-id",
                    "lua",
                    "stdin",
                }, args)
            end)
        end)

        describe("with code actions", function()
            before_each(function()
                async_get_config_info = stub(helpers, "async_get_config_info")
                get_source = stub(require("null-ls.sources"), "get")
                get_source.returns({ code_actions })
                args = args_fn({
                    ft = "lua",
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
                    "lint",
                    "--language-id",
                    "lua",
                    "stdin",
                }, args)
            end)
        end)
    end)
end)