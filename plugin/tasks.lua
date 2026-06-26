if vim.g.loaded_tasks_nvim == 1 then
  return
end

vim.g.loaded_tasks_nvim = 1

vim.api.nvim_create_user_command("TasksOpen", function()
  require("tasks").open()
end, {
  desc = "Open repository tasks",
})

vim.api.nvim_create_user_command("TasksToggle", function()
  require("tasks").toggle()
end, {
  desc = "Toggle repository tasks",
})

vim.api.nvim_create_user_command("TasksAdd", function(ctx)
  local text = vim.trim(ctx.args or "")
  if text == "" then
    require("tasks").add()
  else
    require("tasks").add(text)
  end
end, {
  nargs = "*",
  desc = "Add a repository task",
})

