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

```lua
cspell.code_actions.with({
  config = {
    -- The CSpell configuration file can take a few different names this option
    -- lets you specify which name you would like to use when creating a new
    -- config file from within the `Add word to cspell json file` action.
    --
    -- See the currently supported files in https://github.com/davidmh/cspell.nvim/blob/main/lua/cspell/helpers.lua
    config_file_preferred_name = 'cspell.json',
  }
})
```

### Notes

- The code action source depends on the diagnostics, so make sure to register it too.

# TODO

- [ ] Read formatting options to encode the JSON file and the custom dictionary
      definitions
- [ ] Custom configuration examples
- [ ] Tests

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
