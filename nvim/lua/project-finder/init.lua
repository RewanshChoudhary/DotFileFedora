local uv = vim.uv or vim.loop
local M = {}

--------------------------------------------------
-- Root Markers
--------------------------------------------------

M.root_markers = {
  "go.mod",
  "go.work",
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "package.json",
  "tsconfig.json",
  "pyproject.toml",
  "requirements.txt",
  "Cargo.toml",
  "CMakeLists.txt",
  "Makefile",
}

--------------------------------------------------
-- Config
--------------------------------------------------

M.config = {
  scan_paths = { "~" },
  max_depth = 4,
  auto_rescan_on_pick = true,

  exclude_dirs = {
    "node_modules",
    "target",
    "dist",
    "build",
    ".next",
    ".nuxt",
    ".cache",
    ".local",
  },

  cache_file = vim.fn.stdpath("cache") .. "/project-finder.json",

  open_neotree = true,

  ui = {
    width = 0.85,
    height = 0.85,
    border = "rounded",
    preview_width = 0.4,
  },
}

--------------------------------------------------
-- State
--------------------------------------------------

local cache = {}

local function make_lookup(values)
  local lookup = {}
  for _, value in ipairs(values or {}) do
    lookup[value] = true
  end
  return lookup
end

local exclude_lookup = make_lookup(M.config.exclude_dirs)
local marker_lookup = make_lookup(M.root_markers)

--------------------------------------------------
-- Utils
--------------------------------------------------

local function is_excluded(name)
  if name:sub(1, 1) == "." and name ~= ".git" then
    return true
  end

  return exclude_lookup[name] == true
end

local function ensure_cache_dir()
  vim.fn.mkdir(vim.fn.stdpath("cache"), "p")
end

local function get_mtime(path)
  local stat = uv.fs_stat(path)
  return stat and stat.mtime and stat.mtime.sec or 0
end

local function safe_cd(path)
  local ok, err = pcall(vim.fn.chdir, path)
  if not ok then
    vim.notify("Project switch failed: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function open_neotree(path)
  if not M.config.open_neotree then
    return
  end

  local ok, neotree = pcall(require, "neo-tree.command")
  if ok then
    pcall(neotree.execute, { action = "show", source = "filesystem", position = "left", dir = path })
    return
  end

  pcall(function()
    vim.cmd("Neotree close")
    if path and path ~= "" then
      vim.cmd("Neotree filesystem left dir=" .. vim.fn.fnameescape(path))
    else
      vim.cmd("Neotree filesystem left")
    end
  end)
end

local function format_time(ts)
  if ts == 0 then
    return "unknown"
  end

  local diff = os.time() - ts

  if diff < 60 then
    return "just now"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m ago"
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. "h ago"
  else
    return os.date("%Y-%m-%d", ts)
  end
end

--------------------------------------------------
-- Scanner
--------------------------------------------------

local function scan_directory(path, depth)
  if depth > M.config.max_depth then
    return
  end

  -- Git repo detection
  if uv.fs_stat(path .. "/.git") then
    cache[path] = {
      name = vim.fn.fnamemodify(path, ":t"),
      path = path,
      modified = get_mtime(path .. "/.git"),
      markers = { ".git" },
    }
    return
  end

  local handle = uv.fs_scandir(path)
  if not handle then
    return
  end

  local dirs = {}
  local has_marker = false
  local newest = 0
  local markers = {}

  while true do
    local name, t = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if not is_excluded(name) then
      local full = path .. "/" .. name

      if t == "directory" then
        table.insert(dirs, name)
      elseif t == "file" and marker_lookup[name] then
        has_marker = true
        newest = math.max(newest, get_mtime(full))
        table.insert(markers, name)
      end
    end
  end

  if has_marker then
    cache[path] = {
      name = vim.fn.fnamemodify(path, ":t"),
      path = path,
      modified = newest,
      markers = markers,
    }
    return
  end

  for _, d in ipairs(dirs) do
    scan_directory(path .. "/" .. d, depth + 1)
  end
end

--------------------------------------------------
-- Cache
--------------------------------------------------

local function load_cache()
  local f = io.open(M.config.cache_file, "r")
  if not f then
    return
  end

  local c = f:read("*all")
  f:close()

  local ok, d = pcall(vim.json.decode, c)
  if ok and type(d) == "table" then
    cache = d
  end
end

local function save_cache()
  ensure_cache_dir()

  local f = io.open(M.config.cache_file, "w")
  if not f then
    return
  end

  f:write(vim.json.encode(cache))
  f:close()
end

--------------------------------------------------
-- API
--------------------------------------------------

function M.scan_projects(opts)
  opts = opts or {}
  local silent = opts.silent == true

  cache = {}

  if not silent then
    vim.notify("Scanning projects...", vim.log.levels.INFO)
  end

  local seen = {}
  for _, p in ipairs(M.config.scan_paths) do
    local expanded = vim.fn.expand(p)
    if expanded ~= "" and not seen[expanded] then
      seen[expanded] = true
      local stat = uv.fs_stat(expanded)
      if stat and stat.type == "directory" then
        scan_directory(expanded, 0)
      end
    end
  end

  save_cache()

  if not silent then
    vim.notify("Projects indexed", vim.log.levels.INFO)
  end
end

function M.get_projects()
  if vim.tbl_isempty(cache) then
    load_cache()
  end

  local list = {}

  for _, p in pairs(cache) do
    table.insert(list, p)
  end

  table.sort(list, function(a, b)
    return a.modified > b.modified
  end)

  return list
end

-- Picker (Yazi-like UI)
--------------------------------------------------

local picker_ns = vim.api.nvim_create_namespace("project-finder-picker")

local function normalize_query(q)
  return vim.trim(q or "")
end

local function filter_projects(projects, query)
  local terms = {}
  local trimmed = normalize_query(query)

  if trimmed ~= "" then
    for w in trimmed:gmatch("%S+") do
      table.insert(terms, w:lower())
    end
  end

  if #terms == 0 then
    return vim.deepcopy(projects)
  end

  local filtered = {}

  for _, p in ipairs(projects) do
    local hay = (p.name .. " " .. p.path .. " " .. table.concat(p.markers or {}, " ")):lower()
    local ok = true

    for _, t in ipairs(terms) do
      if not hay:find(t, 1, true) then
        ok = false
        break
      end
    end

    if ok then
      table.insert(filtered, p)
    end
  end

  return filtered
end

local function safe_close(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

function M.pick_project(opts)
  opts = opts or {}
  if type(opts) == "string" then
    opts = { query = opts }
  end

  if opts.refresh ~= false and M.config.auto_rescan_on_pick then
    M.scan_projects({ silent = true })
  end

  local initial_query = normalize_query(opts.query)
  local projects = M.get_projects()

  if #projects == 0 then
    vim.notify("No projects found", vim.log.levels.WARN)
    return
  end

  --------------------------------------------------
  -- Windows
  --------------------------------------------------

  local available_width = math.max(32, vim.o.columns - 4)
  local available_height = math.max(12, vim.o.lines - 4)
  local width = math.min(math.max(72, math.floor(vim.o.columns * M.config.ui.width)), available_width)
  local height = math.min(math.max(16, math.floor(vim.o.lines * M.config.ui.height)), available_height)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local list_width = math.floor(width * (1 - M.config.ui.preview_width))
  list_width = math.max(20, math.min(list_width, width - 22))
  local preview_width = width - list_width - 1
  if preview_width < 20 then
    preview_width = 20
    list_width = math.max(20, width - preview_width - 1)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "project-finder"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = list_width,
    height = height,
    row = row,
    col = col,
    border = M.config.ui.border,
    style = "minimal",
    title = " projects ",
    title_pos = "left",
  })

  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[preview_buf].bufhidden = "wipe"
  vim.bo[preview_buf].filetype = "project-finder-preview"

  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = "editor",
    width = preview_width,
    height = height,
    row = row,
    col = col + list_width + 1,
    border = M.config.ui.border,
    style = "minimal",
    title = " preview ",
    title_pos = "left",
  })

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true
  vim.wo[preview_win].number = false
  vim.wo[preview_win].relativenumber = false

  --------------------------------------------------
  -- State
  --------------------------------------------------

  local prompt = " search> "
  vim.fn.prompt_setprompt(buf, prompt)

  local filtered = filter_projects(projects, initial_query)
  local index = 1
  local last_query = initial_query
  local closing = false

  --------------------------------------------------
  -- Helpers
  --------------------------------------------------

  local function clamp_index()
    if #filtered == 0 then
      index = 1
      return
    end

    if index < 1 then
      index = 1
    elseif index > #filtered then
      index = #filtered
    end
  end

  local function get_query()
    return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  end

  local function close_picker()
    if closing then
      return
    end
    closing = true
    safe_close(preview_win)
    safe_close(win)
  end

  local function open_selected()
    local p = filtered[index]
    if not p then
      return
    end

    close_picker()
    if safe_cd(p.path) then
      open_neotree(p.path)
    end
  end

  --------------------------------------------------
  -- Preview
  --------------------------------------------------

  local function render_preview()
    local p = filtered[index]
    local lines
    if not p then
      lines = {
        " no matches for this search",
        "",
        " try a broader query",
      }
    else
      local markers = (#(p.markers or {}) > 0) and table.concat(p.markers, ", ") or "-"
      lines = {
        " project",
        "  " .. p.name,
        "",
        " path",
        "  " .. p.path,
        "",
        " markers",
        "  " .. markers,
        "",
        " modified",
        "  " .. format_time(p.modified),
        "",
        " actions",
        "  <CR> open",
        "  <Esc> close",
      }
    end

    vim.api.nvim_buf_clear_namespace(preview_buf, picker_ns, 0, -1)

    vim.bo[preview_buf].modifiable = true
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
    vim.bo[preview_buf].modifiable = false

    for i = 0, #lines - 1 do
      if i % 3 == 0 then
        vim.api.nvim_buf_add_highlight(preview_buf, picker_ns, "ProjectFinderMuted", i, 0, -1)
      end
    end
  end

  --------------------------------------------------
  -- Render
  --------------------------------------------------

  local function render()
    local query = get_query()

    if query ~= last_query then
      filtered = filter_projects(projects, query)
      last_query = query
      clamp_index()
    end

    local lines = {
      query,
      "",
      string.format(" results: %d/%d", #filtered, #projects),
      " arrows or <C-j>/<C-k> to move",
      string.rep("-", math.max(12, list_width - 4)),
    }

    local view_height = height - 6
    local start = math.max(1, index - math.floor(view_height / 2))
    local finish = math.min(#filtered, start + view_height - 1)
    local selected_line = nil

    if #filtered == 0 then
      table.insert(lines, " no matching projects")
    else
      for i = start, finish do
        local p = filtered[i]
        local marker = (p.markers and p.markers[1]) and (" [" .. p.markers[1] .. "]") or ""
        local text = (i == index and "> " or "  ") .. p.name .. marker
        if #text > list_width - 2 then
          text = text:sub(1, list_width - 5) .. "..."
        end
        table.insert(lines, text)
        if i == index then
          selected_line = #lines - 1
        end
      end
    end

    vim.api.nvim_buf_clear_namespace(buf, picker_ns, 0, -1)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    vim.api.nvim_buf_add_highlight(buf, picker_ns, "ProjectFinderMuted", 2, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, picker_ns, "ProjectFinderMuted", 3, 0, -1)
    if selected_line then
      vim.api.nvim_buf_add_highlight(buf, picker_ns, "ProjectFinderSelection", selected_line, 0, -1)
    end

    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      pcall(vim.api.nvim_win_set_cursor, win, { 1, #query })
    end

    render_preview()
  end

  --------------------------------------------------
  -- Events
  --------------------------------------------------

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    buffer = buf,
    callback = function()
      if not closing then
        render()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      if not closing then
        close_picker()
      end
    end,
  })

  --------------------------------------------------
  -- Navigation
  --------------------------------------------------

  local function move(delta)
    if #filtered == 0 then
      return
    end
    index = index + delta
    clamp_index()
    render()
  end

  vim.keymap.set("i", "<Down>", function()
    move(1)
  end, { buffer = buf })
  vim.keymap.set("i", "<Up>", function()
    move(-1)
  end, { buffer = buf })
  vim.keymap.set("i", "<C-j>", function()
    move(1)
  end, { buffer = buf })
  vim.keymap.set("i", "<C-k>", function()
    move(-1)
  end, { buffer = buf })

  --------------------------------------------------
  -- Select
  --------------------------------------------------

  vim.keymap.set("i", "<CR>", function()
    open_selected()
  end, { buffer = buf })

  --------------------------------------------------
  -- Quit
  --------------------------------------------------

  vim.keymap.set("i", "<Esc>", function()
    close_picker()
  end, { buffer = buf })
  vim.keymap.set("i", "<C-c>", function()
    close_picker()
  end, { buffer = buf })

  --------------------------------------------------
  -- Start
  --------------------------------------------------

  if initial_query ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { initial_query })
  end

  vim.api.nvim_set_current_win(win)
  vim.cmd("startinsert")
  render()
end

function M.prompt_project_search()
  M.pick_project({ query = "" })
end

--------------------------------------------------
-- Setup
--------------------------------------------------

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  exclude_lookup = make_lookup(M.config.exclude_dirs)
  marker_lookup = make_lookup(M.root_markers)

  pcall(vim.api.nvim_set_hl, 0, "ProjectFinderSelection", { link = "Visual", default = true })
  pcall(vim.api.nvim_set_hl, 0, "ProjectFinderMuted", { link = "Comment", default = true })

  vim.api.nvim_create_user_command("ProjectPick", M.pick_project, {})
  vim.api.nvim_create_user_command("ProjectPickPrompt", M.prompt_project_search, {})
  vim.api.nvim_create_user_command("ProjectScan", M.scan_projects, {})

  load_cache()
end

return M
