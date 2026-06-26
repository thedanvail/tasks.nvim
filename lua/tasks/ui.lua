local config = require("tasks.config")
local git = require("tasks.git")
local storage = require("tasks.storage")

local M = {}

local ns = vim.api.nvim_create_namespace("tasks.nvim")

local state = {
  win = nil,
  buf = nil,
  root = nil,
  tasks = {},
  input = nil,
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.WARN, { title = "tasks.nvim" })
end

local function valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function clamp(value, min, max)
  value = math.max(value, min)
  return math.min(value, max)
end

local function dimension(value, total, fallback, min)
  local resolved = fallback
  if type(value) == "number" then
    if value > 0 and value <= 1 then
      resolved = math.floor(total * value)
    else
      resolved = math.floor(value)
    end
  end

  return clamp(resolved, min, math.max(min, total - 4))
end

local function ensure_highlights()
  local hl = { strikethrough = true }
  local ok, comment = pcall(vim.api.nvim_get_hl, 0, { name = "Comment", link = false })
  if ok and comment and comment.fg then
    hl.fg = comment.fg
  end

  pcall(vim.api.nvim_set_hl, 0, "TasksDone", hl)
end

local function as_keys(value)
  if value == false or value == nil then
    return {}
  end

  if type(value) == "string" then
    return { value }
  end

  return value
end

local function current_index()
  if not valid_win(state.win) then
    return nil
  end

  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  if row < 1 or row > #state.tasks then
    return nil
  end

  return row
end

local function current_task()
  local index = current_index()
  if not index then
    return nil, nil
  end

  return state.tasks[index], index
end

local function set_modifiable(value)
  if valid_buf(state.buf) then
    vim.bo[state.buf].modifiable = value
  end
end

local function render()
  if not valid_buf(state.buf) then
    return
  end

  ensure_highlights()

  local lines = {}
  if #state.tasks == 0 then
    table.insert(lines, "  No tasks")
  else
    for index, task in ipairs(state.tasks) do
      local checkbox = task.done and "[x]" or "[ ]"
      table.insert(lines, string.format("%2d %s %s", index, checkbox, task.text))
    end
  end

  if state.input then
    table.insert(lines, "")
    table.insert(lines, state.input.prompt .. state.input.initial)
    state.input.line = #lines
  end

  set_modifiable(true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

  for index, task in ipairs(state.tasks) do
    if task.done then
      vim.api.nvim_buf_add_highlight(state.buf, ns, "TasksDone", index - 1, 0, -1)
    end
  end

  set_modifiable(state.input ~= nil)

  if valid_win(state.win) then
    vim.wo[state.win].cursorline = true
    if state.input then
      vim.api.nvim_win_set_cursor(state.win, { state.input.line, #state.input.prompt + #state.input.initial })
    elseif #state.tasks > 0 then
      local row = clamp(vim.api.nvim_win_get_cursor(state.win)[1], 1, #state.tasks)
      vim.api.nvim_win_set_cursor(state.win, { row, 0 })
    else
      vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
    end
  end
end

local function reload()
  state.tasks = storage.list(state.root)
end

local function close()
  if valid_win(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  state.win = nil
  state.buf = nil
  state.root = nil
  state.tasks = {}
  state.input = nil
end

local function submit_input()
  if not state.input or not valid_buf(state.buf) then
    return
  end

  local input = state.input
  local line = vim.api.nvim_buf_get_lines(state.buf, input.line - 1, input.line, false)[1] or ""
  local text = line

  if vim.startswith(line, input.prompt) then
    text = line:sub(#input.prompt + 1)
  end

  text = vim.trim(text)
  state.input = nil
  pcall(vim.cmd.stopinsert)

  if text ~= "" then
    if input.kind == "add" then
      storage.add(state.root, text)
    elseif input.kind == "edit" and input.id then
      storage.update(state.root, input.id, { text = text })
    end
  end

  reload()
  render()
end

local function cancel_input()
  state.input = nil
  pcall(vim.cmd.stopinsert)
  render()
end

local function start_input(kind, task)
  if not valid_buf(state.buf) then
    return
  end

  state.input = {
    kind = kind,
    id = task and task.id or nil,
    prompt = kind == "add" and "New: " or "Edit: ",
    initial = task and task.text or "",
    line = nil,
  }

  render()

  vim.schedule(function()
    if valid_win(state.win) and state.input then
      vim.api.nvim_set_current_win(state.win)
      vim.api.nvim_win_set_cursor(state.win, {
        state.input.line,
        #state.input.prompt + #state.input.initial,
      })
      vim.cmd("startinsert!")
    end
  end)
end

local function map(buf, mode, lhs, rhs)
  vim.keymap.set(mode, lhs, rhs, {
    buffer = buf,
    silent = true,
    nowait = true,
  })
end

local function setup_keymaps(buf)
  local mappings = config.get().mappings

  for _, key in ipairs(as_keys(mappings.close)) do
    map(buf, "n", key, close)
  end

  for _, key in ipairs(as_keys(mappings.add)) do
    map(buf, "n", key, function()
      start_input("add")
    end)
  end

  for _, key in ipairs(as_keys(mappings.edit)) do
    map(buf, "n", key, function()
      local task = current_task()
      if task then
        start_input("edit", task)
      end
    end)
  end

  for _, key in ipairs(as_keys(mappings.toggle)) do
    map(buf, "n", key, function()
      local task, index = current_task()
      if not task then
        return
      end

      storage.toggle(state.root, task.id)
      reload()
      render()
      if valid_win(state.win) and #state.tasks > 0 then
        vim.api.nvim_win_set_cursor(state.win, { clamp(index, 1, #state.tasks), 0 })
      end
    end)
  end

  for _, key in ipairs(as_keys(mappings.delete)) do
    map(buf, "n", key, function()
      local task, index = current_task()
      if not task then
        return
      end

      storage.delete(state.root, task.id)
      reload()
      render()
      if valid_win(state.win) and #state.tasks > 0 then
        vim.api.nvim_win_set_cursor(state.win, { clamp(index, 1, #state.tasks), 0 })
      end
    end)
  end

  map(buf, "i", "<CR>", submit_input)
  map(buf, "n", "<CR>", submit_input)
  map(buf, "i", "<Esc>", cancel_input)
end

local function create_window(root)
  local cfg = config.get()
  local popup = cfg.popup or {}
  local columns = vim.o.columns
  local lines = vim.o.lines
  local width = dimension(popup.width, columns, 52, 24)
  local height = dimension(popup.height, lines, 12, 5)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "tasks"

  local title = popup.title or "Tasks"
  local repo_name = git.name(root)
  if repo_name ~= "" then
    title = string.format("%s: %s", title, repo_name)
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((lines - height) / 2),
    col = math.floor((columns - width) / 2),
    style = "minimal",
    border = popup.border or "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"

  state.buf = buf
  state.win = win
  state.root = root
  state.input = nil

  setup_keymaps(buf)

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if state.win == win then
        state.win = nil
        state.buf = nil
        state.root = nil
        state.tasks = {}
        state.input = nil
      end
    end,
  })
end

function M.open(opts)
  opts = opts or {}

  local root = git.root(0)
  if not root then
    notify("Not inside a git repository")
    return false
  end

  if valid_win(state.win) and state.root ~= root then
    close()
  end

  if not valid_win(state.win) then
    create_window(root)
  else
    vim.api.nvim_set_current_win(state.win)
  end

  reload()
  render()

  if opts.action == "add" then
    start_input("add")
  end

  return true
end

function M.toggle()
  if valid_win(state.win) then
    close()
    return false
  end

  return M.open()
end

function M.close()
  close()
end

function M.start_add()
  if M.open() then
    start_input("add")
    return true
  end

  return false
end

function M.is_open()
  return valid_win(state.win)
end

return M
