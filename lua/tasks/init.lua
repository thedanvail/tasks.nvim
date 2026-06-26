local config = require("tasks.config")
local git = require("tasks.git")
local storage = require("tasks.storage")
local ui = require("tasks.ui")

local M = {}

local configured = false
local active_keymap = nil

local function ensure_setup()
  if not configured then
    config.setup()
    configured = true
  end
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.WARN, { title = "tasks.nvim" })
end

function M.setup(opts)
  opts = opts or {}
  local options = config.setup(opts)

  if active_keymap and active_keymap ~= options.keymap then
    pcall(vim.keymap.del, "n", active_keymap)
    active_keymap = nil
  end

  if options.keymap and options.keymap ~= "" then
    vim.keymap.set("n", options.keymap, function()
      require("tasks").toggle()
    end, {
      desc = "Toggle repo tasks",
      silent = true,
    })
    active_keymap = options.keymap
  end

  configured = true
  return options
end

function M.open()
  ensure_setup()
  return ui.open()
end

function M.toggle()
  ensure_setup()
  return ui.toggle()
end

function M.add(text)
  ensure_setup()

  if text == nil or vim.trim(text) == "" then
    return ui.start_add()
  end

  local root = git.root(0)
  if not root then
    notify("Not inside a git repository")
    return nil
  end

  return storage.add(root, text)
end

return M
