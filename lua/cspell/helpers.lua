local Path = require("plenary.path")
local logger = require("null-ls.logger")

local M = {}
local CACHED_JSON_WORDS = {}

local CSPELL_CONFIG_FILES = {
    "cspell.json",
    ".cspell.json",
    "cSpell.json",
    ".cSpell.json",
    ".cspell.config.json",
}
---@type table<string, CSpellConfigInfo|nil>
local CONFIG_INFO_BY_PATH = {}
---@type table<string, string|nil>
local PATH_BY_DIRECTORY = {}

local create_cspell_json = function(params, cspell_json, cspell_json_file_path)
    ---@type CSpellSourceConfig
    local code_action_config = params:get_config()
    local encode_json = code_action_config.encode_json or vim.json.encode
    local cspell_json_str = encode_json(cspell_json)

    local cspell_json_directory_path = vim.fs.dirname(cspell_json_file_path)
    Path:new(cspell_json_directory_path):mkdir({ parents = true })
    Path:new(cspell_json_file_path):write(cspell_json_str, "w")

    local debug_message =
        M.format('Created a new cspell.json file at "${file_path}"', { file_path = cspell_json_file_path })
    logger:debug(debug_message)

    local info = {
        config = cspell_json,
        path = cspell_json_file_path,
    }

    CONFIG_INFO_BY_PATH[cspell_json_file_path] = info
    return info
end

local set_create = function(itable)
    local set = {}
    for _, value in pairs(itable) do
        set[value] = true
    end
    return set
end

local set_compare = function(expected_values, new_values)
    for key, _ in pairs(expected_values) do
        if new_values[key] == nil then
            return false
        end
    end
    return true
end

---@param params GeneratorParams
M.get_merged_cspell_json_path = function(params)
    local vim_cache = vim.fn.stdpath("cache")
    local plugin_name = "cspell.nvim"
    local merged_config_key = Path:new(params.cwd):joinpath("cspell.json"):absolute():gsub("/", "%%")
    local merged_config_path = Path:new(vim_cache):joinpath(plugin_name):joinpath(merged_config_key):absolute()

    return merged_config_path
end

--- create a merged cspell.json file that imports all cspell configs defined in cspell_config_dirs
---@param params GeneratorParams
---@param cspell_config_mapping table<number|string, string>
---@return CSpellConfigInfo
M.create_merged_cspell_json = function(params, cspell_config_mapping)
    local merged_config_path = M.get_merged_cspell_json_path(params)

    local cspell_config_paths = {}

    if CONFIG_INFO_BY_PATH[merged_config_path] ~= nil then
        return CONFIG_INFO_BY_PATH[merged_config_path]
    end

    for _, cspell_config_path in pairs(cspell_config_mapping) do
        local path_exists = cspell_config_path ~= nil
            and cspell_config_path ~= ""
            and Path:new(cspell_config_path):exists()
        if path_exists then
            table.insert(cspell_config_paths, cspell_config_path)
        else
            local debug_message = M.format(
                'Unable to find file at "${file_path}", skipping adding to merged cspell config.',
                { file_path = cspell_config_path }
            )
            logger:debug(debug_message)
        end
    end

    local cspell_json = {
        version = "0.2",
        language = "en",
        words = {},
        flagWords = {},
        import = cspell_config_paths,
    }

    local existing_config = M.get_cspell_config(params, merged_config_path)

    if existing_config ~= nil then
        local existing_import_set = set_create(existing_config.config.import)
        local new_import_set = set_create(cspell_json.import)

        if set_compare(existing_import_set, new_import_set) and set_compare(new_import_set, existing_import_set) then
            CONFIG_INFO_BY_PATH[merged_config_path] = existing_config
            return CONFIG_INFO_BY_PATH[merged_config_path]
        end
    end

    return create_cspell_json(params, cspell_json, merged_config_path)
end

--- Update the import field from a merged config file
---@param params GeneratorParams
---@param cspell_config_path string
function M.update_merged_config_imports(params, cspell_config_path)
    local merged_config_path = M.get_merged_cspell_json_path(params)
    local merged_config = vim.json.decode(Path:new(merged_config_path):read())

    merged_config.import = merged_config.import or {}
    table.insert(merged_config.import, cspell_config_path)

    Path:new(merged_config_path):write(vim.json.encode(merged_config), "w")
end

--- create a bare minimum cspell.json file
---@param params GeneratorParams
---@param cspell_json_file_path string
---@return CSpellConfigInfo
M.create_default_cspell_json = function(params, cspell_json_file_path)
    local cspell_json = {
        version = "0.2",
        language = "en",
        words = {},
        flagWords = {},
    }
    return create_cspell_json(params, cspell_json, cspell_json_file_path)
end

---@param word string
M.cache_word_for_json = function(word)
    CACHED_JSON_WORDS[#CACHED_JSON_WORDS + 1] = word
end

---@param params GeneratorParams
---@param words table<number, string>
---@param cspell_json_path string
M.add_words_to_json = function(params, words, cspell_json_path)
    if not words or #words == 0 then
        return
    end

    ---@type CSpellSourceConfig
    local code_action_config = params:get_config()
    local on_success = code_action_config.on_success
    local on_add_to_json = code_action_config.on_add_to_json
    local encode_json = code_action_config.encode_json or vim.json.encode

    local cspell = M.sync_get_config_info(params, cspell_json_path)

    if not cspell.config.words then
        cspell.config.words = {}
    end

    vim.list_extend(cspell.config.words, words)
    local misspelled_words = table.concat(words, ", ")

    local encoded = encode_json(cspell.config) or ""
    Path:new(cspell.path):write(encoded, "w")
    vim.notify('Added "' .. misspelled_words .. '" to ' .. cspell.path, vim.log.levels.INFO, { title = "cspell.nvim" })

    if on_success then
        vim.notify_once(
            "The on_success callback is deprecated, use on_add_to_json instead",
            vim.log.levels.INFO,
            { title = "cspell.nvim" }
        )
        on_success(cspell.path, params, "add_to_json")
    end

    if on_add_to_json then
        ---@type AddToJSONSuccess
        local add_to_json_success = {
            new_word = misspelled_words,
            cspell_config_path = cspell.path,
            generator_params = params,
        }
        on_add_to_json(add_to_json_success)
    end
end

--- Find the first cspell.json file in the directory tree
---@param directory string
---@return string|nil
M.find_cspell_config_path = function(directory)
    directory = vim.fs.normalize(directory)
    local files = vim.fs.find(CSPELL_CONFIG_FILES, { path = directory, upward = true, type = "file" })
    if files and files[1] then
        return files[1]
    end

    return nil
end

--- Generate a cspell json path
---@param params GeneratorParams
---@param directory string
---@return string
M.generate_cspell_config_path = function(params, directory)
    local code_action_config = params:get_config()
    local config_file_preferred_name = code_action_config.config_file_preferred_name or "cspell.json"
    if not vim.tbl_contains(CSPELL_CONFIG_FILES, config_file_preferred_name) then
        vim.notify(
            "Invalid config_file_preferred_name for cspell json file: "
                .. config_file_preferred_name
                .. '. The name "cspell.json" will be used instead',
            vim.log.levels.WARN,
            { title = "cspell.nvim" }
        )
        config_file_preferred_name = "cspell.json"
    end

    local config_path = require("null-ls.utils").path.join(directory, config_file_preferred_name)
    return vim.fs.normalize(config_path)
end

---@class GeneratorParams
---@field bufnr number
---@field bufname string
---@field ft string
---@field row number
---@field col number
---@field cwd string
---@field get_config function

---@param params GeneratorParams
---@param cspell_json_path string
---@return CSpellConfigInfo|nil
M.get_cspell_config = function(params, cspell_json_path)
    ---@type CSpellSourceConfig
    local code_action_config = params:get_config()
    local decode_json = code_action_config.decode_json or vim.json.decode

    local path_exists = cspell_json_path ~= nil and cspell_json_path ~= "" and Path:new(cspell_json_path):exists()
    if not path_exists then
        return
    end

    local content = Path:new(cspell_json_path):read()
    local ok, cspell_config = pcall(decode_json, content)

    if not ok then
        vim.schedule(function()
            vim.notify("\nCannot parse cspell json file as JSON.\n", vim.log.levels.ERROR, { title = "cspell.nvim" })
        end)
        return
    end

    return {
        config = cspell_config,
        path = cspell_json_path,
    }
end

--- Non-blocking config parser
--- The first run is meant to be a cache warm up
---@param params GeneratorParams
---@param cspell_json_path string
---@return CSpellConfigInfo|nil
M.async_get_config_info = function(params, cspell_json_path)
    ---@type uv_async_t|nil
    local async
    async = vim.loop.new_async(function()
        M.sync_get_config_info(params, cspell_json_path)
        M.add_words_to_json(params, CACHED_JSON_WORDS, cspell_json_path)
        CACHED_JSON_WORDS = {}
        async:close()
    end)

    async:send()

    return CONFIG_INFO_BY_PATH[cspell_json_path]
end

---@param params GeneratorParams
---@param cspell_json_path string
---@return CSpellConfigInfo|nil
M.sync_get_config_info = function(params, cspell_json_path)
    if CONFIG_INFO_BY_PATH[cspell_json_path] == nil then
        local config = M.get_cspell_config(params, cspell_json_path)
        CONFIG_INFO_BY_PATH[cspell_json_path] = config
    end
    return CONFIG_INFO_BY_PATH[cspell_json_path]
end

---@param params GeneratorParams
---@param directory string
---@return string|nil
M.get_config_path = function(params, directory)
    if PATH_BY_DIRECTORY[directory] == nil then
        local code_action_config = params:get_config()
        local find_json = code_action_config.find_json or M.find_cspell_config_path
        local cspell_json_path = find_json(directory)
        PATH_BY_DIRECTORY[directory] = cspell_json_path
    end
    return PATH_BY_DIRECTORY[directory]
end

--- Checks that both sources use the same config
--- We need to do that so we can start reading and parsing the cspell
--- configuration asynchronously as soon as we get the first diagnostic.
---@param code_actions_config CSpellSourceConfig
---@param diagnostics_config CSpellSourceConfig
M.matching_configs = function(code_actions_config, diagnostics_config)
    return (vim.tbl_isempty(code_actions_config) and vim.tbl_isempty(diagnostics_config))
        or code_actions_config == diagnostics_config
end

--- Get the word associated with the diagnostic
---@param diagnostic Diagnostic
---@return string
M.get_word = function(diagnostic)
    return vim.api.nvim_buf_get_text(
        diagnostic.bufnr,
        diagnostic.lnum,
        diagnostic.col,
        diagnostic.end_lnum,
        diagnostic.end_col,
        {}
    )[1]
end

--- Replace the diagnostic's word with a new word
---@param diagnostic Diagnostic
---@param new_word string
M.set_word = function(diagnostic, new_word)
    vim.api.nvim_buf_set_text(
        diagnostic.bufnr,
        diagnostic.lnum,
        diagnostic.col,
        diagnostic.end_lnum,
        diagnostic.end_col,
        { new_word }
    )
end

M.clear_cache = function()
    CONFIG_INFO_BY_PATH = {}
    PATH_BY_DIRECTORY = {}
end

--- Convert a given path to a format using as few characters as possible
--- @param path string
--- @return string
M.shorten_path = function(path)
    return Path:new(path):expand():gsub(Path:new("."):expand(), "."):gsub(vim.env.HOME, "~")
end

--- Formats a string using a table of substitutions.
--- E.g. `M.format("Hello ${subject}", { subject = "world" })` returns `Hello world`
---
--- @param str string The string to format
--- @param tbl table k-v pairs of string substitutions
--- @return string, number
M.format = function(str, tbl)
    ---@param param string
    return str:gsub("$%b{}", function(param)
        return (tbl[string.sub(param, 3, -2)] or param)
    end)
end

return M

---@class Diagnostic
---@field bufnr number Buffer number
---@field lnum number The starting line of the diagnostic
---@field end_lnum number The final line of the diagnostic
---@field col number The starting column of the diagnostic
---@field end_col number The final column of the diagnostic
---@field severity number The severity of the diagnostic
---@field message string The diagnostic text
---@field source string The source of the diagnostic
---@field code number The diagnostic code
---@field user_data UserData

---@class CodeAction
---@field title string
---@field action function

---@class UserData
---@field suggestions table<number, string> Suggested words for the diagnostic
---@field misspelled string The misspelled word

---@class CSpellConfigInfo
---@field config CSpellConfig
---@field path string

---@class CSpellConfig
---@field flagWords table<number, string>
---@field language string
---@field version string
---@field words table<number, string>
---@field dictionaryDefinitions table<number, CSpellDictionary>|nil
---@field import table<number, string>|nil

---@class CSpellDictionary
---@field name string
---@field path string
---@field addWords boolean|nil

---@class CSpellSourceConfig
---@field config_file_preferred_name string|nil
---@field cspell_config_dirs table|nil
--- Will find and read the cspell config file synchronously, as soon as the
--- code actions generator gets called.
---
--- If you experience UI-blocking during the first run of this code action, try
--- setting this option to false.
--- See: https://github.com/davidmh/cspell.nvim/issues/25
---@field read_config_synchronously boolean|nil
---@field find_json function|nil
---@field decode_json function|nil
---@field encode_json function|nil
---@field on_success function|nil
---@field on_add_to_json function|nil
---@field on_add_to_dictionary function|nil
---@field on_use_suggestion function|nil

---@class UseSuggestionSuccess
---@field misspelled_word string
---@field suggestion string
---@field cspell_config_path string|nil
---@field generator_params GeneratorParams

---@class AddToJSONSuccess
---@field new_word string
---@field cspell_config_path string
---@field generator_params GeneratorParams

---@class AddToDictionarySuccess
---@field new_word string
---@field cspell_config_path string
---@field generator_params GeneratorParams
---@field dictionary_path string
