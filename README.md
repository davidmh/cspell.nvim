# cspell.nvim

A companion plugin for null-ls, adding support for CSpell diagnostics and code actions.

```lua
local null_ls = require('null-ls')
local cspell = require('cspell')

null_ls.setup {
  sources = {
    cspell.diagnostics,
    cspell.code_actions,
  }
}
```

# TODO

- [ ] Read formatting options to encode the JSON file and the custom dictionary
      definitions
- [ ] Custom configuration examples
- [ ] Tests

# Credits

These sources were initially written in jose-elias-alvarez/null-ls.nvim, with
contributions from: @JA-Bar, @PumpedSardines, @Saecki, @Sloff, @marianozunino,
@mtoohey31 and @yoo.
