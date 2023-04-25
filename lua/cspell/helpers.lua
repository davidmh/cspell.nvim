local Path = require("plenary.path")
local uv = vim.loop

local M = {}

local CSPELL_CONFIG_FILES = {
    "cspell.json",
    ".cspell.json",
    "cSpell.json",
    ".cspell.json",
    ".cspell.config.json",
}

---@type table<string, CSpellConfigInfo|nil>
local CONFIG_INFO_BY_CWD = {}

--- create a bare minimum cspell.json file
---@param params GeneratorParams
---@return CSpellConfigInfo
M.create_cspell_json = function(params)
    local config = params:get_config()
    local config_file_preferred_name = config.config_file_preferred_name or "cspell.json"

    if not vim.tbl_contains(CSPELL_CONFIG_FILES, config_file_preferred_name) then
        vim.notify(
            "Invalid config_file_preferred_name for cspell json file: "
                .. config_file_preferred_name
                .. '. The name "cspell.json" will be used instead',
            vim.log.levels.WARN
        )
        config_file_preferred_name = "cspell.json"
    end

    local cspell_json = {
        version = "0.2",
        language = "en",
        words = {},
        flagWords = {},
    }

    local cspell_json_str = vim.json.encode(cspell_json)
    local cspell_json_file_path = require("null-ls.utils").path.join(params.cwd, config_file_preferred_name)

    Path:new(cspell_json_file_path):write(cspell_json_str, "w")
    vim.notify("Created a new cspell.json file at " .. cspell_json_file_path, vim.log.levels.INFO)

    local info = {
        config = cspell_json,
        path = cspell_json_file_path,
    }

    CONFIG_INFO_BY_CWD[params.cwd] = info

    return info
end

---@param filename string
---@param cwd string
---@return string|nil
local function find_file(filename, cwd)
    ---@type string|nil
    local current_dir = cwd
    local root_dir = "/"

    repeat
        local file_path = current_dir .. "/" .. filename
        local stat = uv.fs_stat(file_path)
        if stat and stat.type == "file" then
            return file_path
        end

        current_dir = uv.fs_realpath(current_dir .. "/..")
    until current_dir == root_dir

    return nil
end

--- Find the first cspell.json file in the directory tree
---@param cwd string
---@return string|nil
local find_cspell_config_path = function(cwd)
    for _, file in ipairs(CSPELL_CONFIG_FILES) do
        local path = find_file(file, cwd or vim.loop.cwd())
        if path then
            return path
        end
    end
    return nil
end

---@class CSpellCodeActionSourceConfig
---@field config_file_preferred_name string
---@field find_json function

---@class GeneratorParams
---@field bufnr number
---@field row number
---@field col number
---@field cwd string
---@field get_config function

---@param params GeneratorParams
---@return CSpellConfigInfo|nil
M.get_cspell_config = function(params)
    ---@type CSpellCodeActionSourceConfig
    local config = params:get_config()
    local find_json = config.find_json or find_cspell_config_path

    local cspell_json_path = find_json(params.cwd)

    if cspell_json_path == nil or cspell_json_path == "" then
        return
    end

    local content = Path:new(cspell_json_path):read()
    local ok, cspell_config = pcall(vim.json.decode, content)

    if not ok then
        vim.notify("\nCannot parse cspell json file as JSON.\n", vim.log.levels.ERROR)
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
---@return CSpellConfigInfo|nil
M.async_get_config_info = function(params)
    ---@type uv_async_t|nil
    local async
    async = vim.loop.new_async(function()
        if CONFIG_INFO_BY_CWD[params.cwd] == nil then
            local config = M.get_cspell_config(params)
            CONFIG_INFO_BY_CWD[params.cwd] = config
        end
        async:close()
    end)

    async:send()

    return CONFIG_INFO_BY_CWD[params.cwd]
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

---@class CSpellConfigInfo
---@field config CSpellConfig
---@field path string

---@class CSpellConfig
---@field flagWords table<number, string>
---@field language string
---@field version string
---@field words table<number, string>
---@field dictionaryDefinitions table<number, CSpellDictionary>|nil

---@class CSpellDictionary
---@field name string
---@field path string
---@field addWords boolean|nil
