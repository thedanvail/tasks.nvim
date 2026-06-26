local M = {}

local uv = vim.uv or vim.loop

local function strip_trailing_separator(path)
  if not path or path == "" then
    return path
  end

  local stripped = path:gsub("[/\\]+$", "")
  if stripped == "" then
    return path
  end

  return stripped
end

local function normalize(path)
  if not path or path == "" then
    return nil
  end

  local absolute = vim.fn.fnamemodify(path, ":p")
  return strip_trailing_separator(vim.fs.normalize(absolute))
end

local function start_path(bufnr)
  bufnr = bufnr or 0

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return normalize(uv.cwd())
  end

  local stat = uv.fs_stat(name)
  if stat and stat.type == "directory" then
    return normalize(name)
  end

  return normalize(vim.fs.dirname(name))
end

function M.root(bufnr)
  local path = start_path(bufnr)
  if not path then
    return nil
  end

  local matches = vim.fs.find(".git", {
    path = path,
    upward = true,
    limit = 1,
  })

  if not matches or not matches[1] then
    return nil
  end

  return normalize(vim.fs.dirname(matches[1]))
end

function M.name(root)
  if not root or root == "" then
    return ""
  end

  return vim.fs.basename(root)
end

return M

