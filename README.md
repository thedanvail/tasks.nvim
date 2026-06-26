# tasks.nvim

A small, dependency-free Neovim task popup with one task list per git repository.

`tasks.nvim` stores tasks outside your repositories by default, under
`stdpath("data")/tasks.nvim/tasks.json`, keyed by the absolute git root. Opening
the popup in one repository will not show tasks from another repository.

## Installation

Use any Neovim plugin manager. With `lazy.nvim`, this spec lazy-loads on the
commands or keymap:

```lua
return {
  "your-name/tasks.nvim",
  main = "tasks",
  cmd = { "TasksOpen", "TasksToggle", "TasksAdd" },
  keys = {
    {
      "<leader>tt",
      function()
        require("tasks").toggle()
      end,
      desc = "Toggle repo tasks",
    },
  },
  opts = {},
}
```

For local development:

```lua
{
  dir = "<path to tasks.nvim>",
  name = "tasks.nvim",
  main = "tasks",
  cmd = { "TasksOpen", "TasksToggle", "TasksAdd" },
  keys = {
    {
      "<leader>tt",
      function()
        require("tasks").toggle()
      end,
      desc = "Toggle repo tasks",
    },
  },
  opts = {},
}
```

The plugin's own `keymap` option is still available, but with lazy.nvim the
`keys` field is preferred because it can lazy-load the plugin.

## Usage

Commands:

- `:TasksOpen`
- `:TasksToggle`
- `:TasksAdd [task text]`

Popup keys:

- `a` add a task
- `e` edit the task under the cursor
- `x` or `<Space>` cross off or reopen a task
- `d` delete the task under the cursor
- `q` or `<Esc>` close the popup

## Configuration

```lua
require("tasks").setup({
  keymap = nil,
  data_path = vim.fs.joinpath(vim.fn.stdpath("data"), "tasks.nvim", "tasks.json"),
  popup = {
    width = 52,
    height = 12,
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
})
```

The plugin requires Neovim 0.10 or newer.
