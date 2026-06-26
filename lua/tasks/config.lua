local M = {}

local function default_data_path()
  return vim.fs.joinpath(vim.fn.stdpath("data"), "tasks.nvim", "tasks.json")
end

local defaults = {
  keymap = nil,
  data_path = nil,
  popup = {
    width = 68,
    height = 16,
    border = "rounded",
    title = "Tasks",
  },
  mappings = {
    close = { "q", "<Esc>" },
    add = "a",
    edit = "e",
    toggle = { "x", "<Space>" },
    delete = "d",
  },
}

M.options = nil

function M.setup(opts)
  opts = opts or {}

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  if not merged.data_path or merged.data_path == "" then
    merged.data_path = default_data_path()
  end

  M.options = merged
  return M.options
end

function M.get()
  if not M.options then
    return M.setup()
  end

  return M.options
end

function M.defaults()
  local copy = vim.deepcopy(defaults)
  copy.data_path = default_data_path()
  return copy
end

return M
