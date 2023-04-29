# cspell.nvim

A companion plugin for [null-ls], adding support for [cspell] diagnostics and code actions.

## Diagnostics

```lua
local cspell = require('cspell')
local sources = { cspell.diagnostics }
```

### Defaults

- Filetypes: `{}`
- Method: `diagnostics`
- Command: `cspell`
- Args: dynamically resolved (see [diagnostics source])


## Code Actions

```lua
local cspell = require('cspell')
local sources = { cspell.diagnostics, cspell.code_actions }
```

### Defaults

- Filetypes: `{}`
- Method: `code_action`

### Configuration options

All the configuration properties are optional.

```lua
cspell.code_actions.with({
  config = {
    -- The CSpell configuration file can take a few different names this option
    -- lets you specify which name you would like to use when creating a new
    -- config file from within the `Add word to cspell json file` action.
    --
    -- See the currently supported files in https://github.com/davidmh/cspell.nvim/blob/main/lua/cspell/helpers.lua
    config_file_preferred_name = 'cspell.json',

    --- A way to define your own logic to find the CSpell configuration file.
    ---@params cwd The same current working directory defined in the source,
    --             defaulting to vim.loop.cwd()
    ---@return string|nil The path of the json file
    find_json = function(cwd)
    end,

    ---@param cspell string The contents of the CSpell config file
    ---@return table
    encode_json = function(cspell_str)
    end,

    ---@param cspell table A lua table with the CSpell config values
    ---@return string
    encode_json = function(cspell_tbl)
    end,
  }
})
```

### Notes

- The code action source depends on the diagnostics, so make sure to register it too.

## Tests

The test suite depends on plenary.nvim.

Run `./tests/run.sh` in the root of the project to run the suite or use [neotest]
to run individual tests from within Neovim.

To avoid a dependency on any plugin managers, the test suite will set up its
plugin runtime under the `./tests` directory to always have a plenary version
available.

If you run into plenary-related issues while running the tests, make sure you
have an up-to-date version of the plugin by clearing that cache with
`rm -rf .tests/`.

All tests expect the latest Neovim master.

# TODO

- [ ] Custom configuration examples

# Credits

These sources were initially written in jose-elias-alvarez/null-ls.nvim, with
contributions from: [@JA-Bar], [@PumpedSardines], [@Saecki], [@Sloff], [@marianozunino],
[@mtoohey31] and [@yoo].

[null-ls]: https://github.com/jose-elias-alvarez/null-ls.nvim
[cspell]: https://github.com/streetsidesoftware/cspell
[diagnostics source]: https://github.com/davidmh/cspell.nvim/blob/main/lua/cspell/diagnostics/init.lua
[@JA-Bar]: https://github.com/JA-Bar
[@PumpedSardines]: https://github.com/PumpedSardines
[@Saecki]: https://github.com/Saecki
[@Sloff]: https://github.com/Sloff
[@marianozunino]: https://github.com/marianozunino
[@mtoohey31]: https://github.com/mtoohey31
[@yoo]: https://github.com/yoo
[neotest]: https://github.com/nvim-neotest/neotest
