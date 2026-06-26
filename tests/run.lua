local root = vim.uv.cwd()
package.path = table.concat({
  vim.fs.joinpath(root, "lua", "?.lua"),
  vim.fs.joinpath(root, "lua", "?", "init.lua"),
  package.path,
}, ";")

local config = require("tasks.config")
local git = require("tasks.git")
local storage = require("tasks.storage")
local tasks = require("tasks")

local function join(...)
  return vim.fs.joinpath(...)
end

local function mkdir(path)
  vim.fn.mkdir(path, "p")
end

local function touch(path)
  vim.fn.writefile({ "" }, path)
end

local tmp = vim.fn.tempname()
mkdir(tmp)

local repo_a = join(tmp, "repo-a")
local repo_b = join(tmp, "repo-b")
mkdir(join(repo_a, ".git"))
mkdir(join(repo_a, "sub"))
mkdir(join(repo_b, ".git"))
touch(join(repo_a, "sub", "file.txt"))
touch(join(repo_b, "file.txt"))

local data_path = join(tmp, "data", "tasks.json")

local function assert_eq(expected, actual, message)
  if expected ~= actual then
    error(string.format(
      "%s\nexpected: %s\nactual:   %s",
      message or "values differ",
      vim.inspect(expected),
      vim.inspect(actual)
    ), 2)
  end
end

local function assert_true(value, message)
  if not value then
    error(message or "expected truthy value", 2)
  end
end

local tests = {}

tests[#tests + 1] = {
  "detects git root from current buffer",
  function()
    vim.cmd.edit(vim.fn.fnameescape(join(repo_a, "sub", "file.txt")))
    assert_eq(repo_a, git.root(0))
    assert_eq("repo-a", git.name(repo_a))
  end,
}

tests[#tests + 1] = {
  "returns nil outside a git repository",
  function()
    local outside = join(tmp, "outside")
    mkdir(outside)
    touch(join(outside, "file.txt"))
    vim.cmd.edit(vim.fn.fnameescape(join(outside, "file.txt")))
    assert_eq(nil, git.root(0))
  end,
}

tests[#tests + 1] = {
  "persists tasks separately by repo root",
  function()
    config.setup({ data_path = data_path })
    local task_a = storage.add(repo_a, "write plugin")
    local task_b = storage.add(repo_b, "different repo")

    assert_true(task_a and task_a.id, "repo A task was not created")
    assert_true(task_b and task_b.id, "repo B task was not created")

    local list_a = storage.list(repo_a)
    local list_b = storage.list(repo_b)
    assert_eq(1, #list_a)
    assert_eq(1, #list_b)
    assert_eq("write plugin", list_a[1].text)
    assert_eq("different repo", list_b[1].text)
  end,
}

tests[#tests + 1] = {
  "updates toggles and deletes tasks",
  function()
    config.setup({ data_path = data_path })
    storage.replace(repo_a, {})

    local task = storage.add(repo_a, "draft")
    storage.update(repo_a, task.id, { text = "ship" })
    storage.toggle(repo_a, task.id)

    local list = storage.list(repo_a)
    assert_eq("ship", list[1].text)
    assert_eq(true, list[1].done)

    assert_eq(true, storage.delete(repo_a, task.id))
    assert_eq(0, #storage.list(repo_a))

    storage.add(repo_a, "multi\nline\t task")
    assert_eq("multi line task", storage.list(repo_a)[1].text)
  end,
}

tests[#tests + 1] = {
  "sets up opt-in keymap and public add api",
  function()
    tasks.setup({
      data_path = data_path,
      keymap = "<leader>tt",
    })

    vim.cmd.edit(vim.fn.fnameescape(join(repo_a, "sub", "file.txt")))
    storage.replace(repo_a, {})
    tasks.add("from api")

    local list = storage.list(repo_a)
    assert_eq(1, #list)
    assert_eq("from api", list[1].text)
    assert_true(vim.fn.maparg("<leader>tt", "n") ~= "", "expected opt-in keymap")

    tasks.setup({ data_path = data_path })
    assert_eq("", vim.fn.maparg("<leader>tt", "n"), "expected disabled plugin keymap to be removed")
  end,
}

tests[#tests + 1] = {
  "opens and closes the floating ui in a git repository",
  function()
    tasks.setup({ data_path = data_path })
    vim.cmd.edit(vim.fn.fnameescape(join(repo_a, "sub", "file.txt")))
    storage.replace(repo_a, {})
    storage.add(repo_a, "visible")

    assert_eq(true, tasks.open())
    assert_true(require("tasks.ui").is_open(), "expected floating task window")
    assert_eq(false, tasks.toggle())
    assert_eq(false, require("tasks.ui").is_open())
  end,
}

local failures = 0

for _, test in ipairs(tests) do
  local name, fn = test[1], test[2]
  local ok, err = pcall(fn)
  if ok then
    print("ok - " .. name)
  else
    failures = failures + 1
    print("not ok - " .. name)
    print(err)
  end
end

if failures > 0 then
  print(string.format("%d test(s) failed", failures))
  vim.cmd.cquit()
else
  print(string.format("%d test(s) passed", #tests))
  vim.cmd.quitall()
end
