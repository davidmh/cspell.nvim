nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('plenary.test_harness').test_directory_command('tests/spec {minimal_init = \"tests/minimal_init.lua\"}')"
