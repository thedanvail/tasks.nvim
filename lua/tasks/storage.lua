local config = require("tasks.config")

local M = {}

local uv = vim.uv or vim.loop

local function empty_db()
  return {
    version = 1,
    repos = {},
  }
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.WARN, { title = "tasks.nvim" })
end

local function read_json(path)
  if not path or path == "" then
    return empty_db()
  end

  if not uv.fs_stat(path) then
    return empty_db()
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    notify("Could not read task storage: " .. tostring(lines), vim.log.levels.ERROR)
    return empty_db()
  end

  local raw = table.concat(lines, "\n")
  if raw == "" then
    return empty_db()
  end

  local decoded_ok, decoded = pcall(vim.json.decode, raw)
  if not decoded_ok or type(decoded) ~= "table" then
    notify("Could not parse task storage; starting with an empty database", vim.log.levels.ERROR)
    return empty_db()
  end

  decoded.version = decoded.version or 1
  decoded.repos = type(decoded.repos) == "table" and decoded.repos or {}

  return decoded
end

local function write_json(path, db)
  local parent = vim.fs.dirname(path)
  if parent and parent ~= "" then
    local mkdir_ok, mkdir_err = pcall(vim.fn.mkdir, parent, "p")
    if not mkdir_ok then
      notify("Could not create task storage directory: " .. tostring(mkdir_err), vim.log.levels.ERROR)
      return false
    end
  end

  local encoded = vim.json.encode(db)
  local ok, err = pcall(vim.fn.writefile, { encoded }, path)
  if not ok then
    notify("Could not write task storage: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

local function storage_path(opts)
  return (opts and opts.data_path) or config.get().data_path
end

local function ensure_repo(db, root)
  db.repos[root] = db.repos[root] or { tasks = {} }
  db.repos[root].tasks = type(db.repos[root].tasks) == "table" and db.repos[root].tasks or {}
  return db.repos[root]
end

local function timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function clean_text(text)
  return vim.trim(tostring(text or ""):gsub("[\r\n]+", " "):gsub("%s+", " "))
end

local function new_id()
  local seed = table.concat({
    tostring(os.time()),
    tostring(uv.hrtime()),
    tostring(math.random(1000000, 9999999)),
  }, ":")

  return vim.fn.sha256(seed):sub(1, 16)
end

local function find_task(tasks, id)
  for index, task in ipairs(tasks) do
    if task.id == id then
      return task, index
    end
  end

  return nil, nil
end

function M.load(opts)
  return read_json(storage_path(opts))
end

function M.save(db, opts)
  db.version = db.version or 1
  db.repos = type(db.repos) == "table" and db.repos or {}
  return write_json(storage_path(opts), db)
end

function M.list(root, opts)
  local db = M.load(opts)
  local repo = db.repos[root]
  if not repo or type(repo.tasks) ~= "table" then
    return {}
  end

  return vim.deepcopy(repo.tasks)
end

function M.replace(root, tasks, opts)
  local db = M.load(opts)
  ensure_repo(db, root).tasks = vim.deepcopy(tasks or {})
  return M.save(db, opts)
end

function M.with_tasks(root, fn, opts)
  local db = M.load(opts)
  local tasks = ensure_repo(db, root).tasks
  local result = fn(tasks)
  M.save(db, opts)
  return result
end

function M.add(root, text, opts)
  local clean = clean_text(text)
  if clean == "" then
    return nil
  end

  return M.with_tasks(root, function(tasks)
    local now = timestamp()
    local task = {
      id = new_id(),
      text = clean,
      done = false,
      created_at = now,
      updated_at = now,
    }

    table.insert(tasks, task)
    return vim.deepcopy(task)
  end, opts)
end

function M.update(root, id, attrs, opts)
  attrs = attrs or {}

  return M.with_tasks(root, function(tasks)
    local task = find_task(tasks, id)
    if not task then
      return nil
    end

    if attrs.text ~= nil then
      local clean = clean_text(attrs.text)
      if clean == "" then
        return nil
      end
      task.text = clean
    end

    if attrs.done ~= nil then
      task.done = attrs.done and true or false
    end

    task.updated_at = timestamp()
    return vim.deepcopy(task)
  end, opts)
end

function M.toggle(root, id, opts)
  return M.with_tasks(root, function(tasks)
    local task = find_task(tasks, id)
    if not task then
      return nil
    end

    task.done = not task.done
    task.updated_at = timestamp()
    return vim.deepcopy(task)
  end, opts)
end

function M.delete(root, id, opts)
  return M.with_tasks(root, function(tasks)
    local _, index = find_task(tasks, id)
    if not index then
      return false
    end

    table.remove(tasks, index)
    return true
  end, opts)
end

return M
