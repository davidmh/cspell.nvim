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

## Configuration options

All the configuration properties are optional and they're used for the code actions.

But if you define them, make sure to add them to both the diagnostics **and** the code_actions.
We need to do that to start reading and parsing the CSpell configuration asynchronously as soon
as we get the first diagnostic.

```lua
local config = {
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

  -- Will find and read the cspell config file synchronously, as soon as the
  -- code actions generator gets called.
  --
  -- If you experience UI-blocking during the first run of this code action, try
  -- setting this option to false.
  -- See: https://github.com/davidmh/cspell.nvim/issues/25
  read_config_synchronously = true,

  ---@param cspell string The contents of the CSpell config file
  ---@return table
  decode_json = function(cspell_str)
  end,

  ---@param cspell table A lua table with the CSpell config values
  ---@return string
  encode_json = function(cspell_tbl)
  end,


  --- Callback after a successful execution of a code action.
  ---@param cspell_config_file_path string|nil
  ---@param params GeneratorParams
  ---@action_name 'use_suggestion'|'add_to_json'|'add_to_dictionary'
  on_success = function(cspell_config_file_path, params, action_name)
      -- For example, you can format the cspell config file after you add a word
      if action_name == 'add_to_json' then
          os.execute(
              string.format(
                  "cat %s | jq -S '.words |= sort' | tee %s > /dev/null",
                  cspell_config_file_path,
                  cspell_config_file_path
              )
          )
      end

      -- Note: The cspell_config_file_path param could be nil for the
      -- 'use_suggestion' action
  end
}

local cspell = require('cspell')
local sources = {
  cspell.diagnostics.with({ config = config }),
  cspell.code_actions.with({ config = config }),
}
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
