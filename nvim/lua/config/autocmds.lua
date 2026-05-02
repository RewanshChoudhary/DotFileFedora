-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- Keep root detection aligned with project boundaries first, then fallback to cwd.
vim.g.root_spec = { "lsp", ".git", "cwd" }

-- Force regular file buffers to be writable/editable on open.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  pattern = "*",
  callback = function(event)
    local bo = vim.bo[event.buf]
    if bo.buftype == "" or bo.buftype == "acwrite" then
      bo.modifiable = true
      bo.readonly = false
    end
  end,
})

-- Avoid interactive "Press E for edit anyway" prompts for existing swap files.
vim.api.nvim_create_autocmd("SwapExists", {
  pattern = "*",
  callback = function()
    vim.v.swapchoice = "e"
  end,
})

-- Work around stuck floating windows for LSP code actions with a
-- dedicated selector that supports arrow-key navigation.
local codeaction_ns = vim.api.nvim_create_namespace("codeaction_select")

local function codeaction_select(items, opts, on_choice)
  vim.validate("items", items, "table")
  vim.validate("on_choice", on_choice, "function")
  opts = opts or {}
  if #items == 0 then
    on_choice(nil, nil)
    return
  end

  local format_item = opts.format_item or tostring
  local display = {}
  local max_width = 0

  for i, item in ipairs(items) do
    local ok, text = pcall(format_item, item)
    text = ok and tostring(text) or tostring(item)
    text = text:gsub("\r?\n", " ")
    text = vim.trim(text)
    if text == "" then
      text = ("Code action %d"):format(i)
    end
    display[i] = text
    max_width = math.max(max_width, vim.fn.strdisplaywidth(text))
  end

  local width = math.min(math.max(max_width + 6, 36), math.max(36, math.floor(vim.o.columns * 0.75)))
  local height = math.min(#display, math.max(4, math.floor(vim.o.lines * 0.5)))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local title = vim.trim(opts.prompt or "Code Actions")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "codeaction_select"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    style = "minimal",
    title = (" %s "):format(title),
    title_pos = "left",
  })
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false

  local index = 1
  local completed = false

  local function close_picker(choice)
    if completed then
      return
    end
    completed = true
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    vim.schedule(function()
      if choice then
        on_choice(items[choice], choice)
      else
        on_choice(nil, nil)
      end
    end)
  end

  local function render()
    if completed or not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    local lines = {}
    for i, text in ipairs(display) do
      lines[i] = (i == index and "> " or "  ") .. text
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    vim.api.nvim_buf_clear_namespace(buf, codeaction_ns, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, codeaction_ns, "Visual", index - 1, 0, -1)
    pcall(vim.api.nvim_win_set_cursor, win, { index, 0 })
  end

  local function move(delta)
    index = index + delta
    if index < 1 then
      index = #display
    elseif index > #display then
      index = 1
    end
    render()
  end

  local map_opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set({ "n", "i" }, "<Down>", function()
    move(1)
  end, map_opts)
  vim.keymap.set({ "n", "i" }, "<Up>", function()
    move(-1)
  end, map_opts)
  vim.keymap.set({ "n", "i" }, "<Tab>", function()
    move(1)
  end, map_opts)
  vim.keymap.set({ "n", "i" }, "<S-Tab>", function()
    move(-1)
  end, map_opts)
  vim.keymap.set({ "n", "i" }, "<C-j>", function()
    move(1)
  end, map_opts)
  vim.keymap.set({ "n", "i" }, "<C-k>", function()
    move(-1)
  end, map_opts)
  vim.keymap.set("n", "j", function()
    move(1)
  end, map_opts)
  vim.keymap.set("n", "k", function()
    move(-1)
  end, map_opts)
  vim.keymap.set({ "n", "i" }, "<CR>", function()
    close_picker(index)
  end, map_opts)
  vim.keymap.set({ "n", "i" }, "<Esc>", function()
    close_picker(nil)
  end, map_opts)
  vim.keymap.set({ "n", "i" }, "<C-c>", function()
    close_picker(nil)
  end, map_opts)
  vim.keymap.set("n", "q", function()
    close_picker(nil)
  end, map_opts)

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buf,
    once = true,
    callback = function()
      close_picker(nil)
    end,
  })

  render()
end

local wrapped_select
local function patch_codeaction_select()
  if vim.ui.select == wrapped_select then
    return
  end

  local select_fn = vim.ui.select
  if type(select_fn) ~= "function" then
    return
  end

  wrapped_select = function(items, opts, on_choice)
    opts = opts or {}
    local kind = type(opts.kind) == "string" and opts.kind:lower() or ""

    if kind:find("codeaction", 1, true) == 1 then
      return codeaction_select(items, opts, on_choice)
    end

    return select_fn(items, opts, on_choice)
  end

  vim.ui.select = wrapped_select
end

patch_codeaction_select()
vim.schedule(patch_codeaction_select)

-- Spring Boot helpers (safe, command-based; no plugin hard dependency).
do
  local uv = vim.uv or vim.loop
  local spring_job_id

  local spring_markers = {
    "mvnw",
    "pom.xml",
    "gradlew",
    "build.gradle",
    "build.gradle.kts",
  }

  local function has_file(path)
    return uv.fs_stat(path) ~= nil
  end

  local function spring_root()
    local name = vim.api.nvim_buf_get_name(0)
    local start = name ~= "" and name or uv.cwd()
    return vim.fs.root(start, spring_markers) or uv.cwd()
  end

  local function detect_build_tool(root)
    if has_file(root .. "/mvnw") then
      return "maven_wrapper"
    end
    if has_file(root .. "/pom.xml") then
      return "maven"
    end
    if has_file(root .. "/gradlew") then
      return "gradle_wrapper"
    end
    if has_file(root .. "/build.gradle") or has_file(root .. "/build.gradle.kts") then
      return "gradle"
    end
    return nil
  end

  local function command_for(kind, root, extra)
    local tool = detect_build_tool(root)
    if not tool then
      return nil, "No Maven/Gradle project detected for Spring Boot."
    end

    local cmd
    if kind == "run" then
      if tool == "maven_wrapper" then
        cmd = "./mvnw spring-boot:run"
      elseif tool == "maven" then
        cmd = "mvn spring-boot:run"
      elseif tool == "gradle_wrapper" then
        cmd = "./gradlew bootRun"
      else
        cmd = "gradle bootRun"
      end
    elseif kind == "test" then
      if tool == "maven_wrapper" then
        cmd = "./mvnw test"
      elseif tool == "maven" then
        cmd = "mvn test"
      elseif tool == "gradle_wrapper" then
        cmd = "./gradlew test"
      else
        cmd = "gradle test"
      end
    elseif kind == "build" then
      if tool == "maven_wrapper" then
        cmd = "./mvnw clean package"
      elseif tool == "maven" then
        cmd = "mvn clean package"
      elseif tool == "gradle_wrapper" then
        cmd = "./gradlew clean build"
      else
        cmd = "gradle clean build"
      end
    else
      return nil, "Unsupported Spring Boot action: " .. tostring(kind)
    end

    if extra and extra ~= "" then
      cmd = cmd .. " " .. extra
    end
    return cmd
  end

  local function is_job_running(job_id)
    if not job_id then
      return false
    end
    local status = vim.fn.jobwait({ job_id }, 0)[1]
    return status == -1
  end

  local function open_terminal(cmd, root)
    vim.cmd("botright 14split")
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buflisted = false
    vim.bo[buf].filetype = "springboot-terminal"

    spring_job_id = vim.fn.termopen(cmd, { cwd = root })
    if spring_job_id <= 0 then
      spring_job_id = nil
      vim.notify("Failed to start Spring Boot command", vim.log.levels.ERROR)
      return
    end
    vim.cmd("startinsert")
  end

  local function run_spring(kind, opts)
    local root = spring_root()
    local extra = table.concat(opts.fargs or {}, " ")
    local cmd, err = command_for(kind, root, extra)
    if not cmd then
      vim.notify(err, vim.log.levels.WARN)
      return
    end
    open_terminal(cmd, root)
    vim.notify(("Spring Boot %s: %s"):format(kind, cmd), vim.log.levels.INFO)
  end

  local function stop_spring()
    if is_job_running(spring_job_id) then
      vim.fn.jobstop(spring_job_id)
      vim.notify("Stopped Spring Boot job", vim.log.levels.INFO)
      return
    end
    vim.notify("No running Spring Boot job", vim.log.levels.WARN)
  end

  local function create_command_if_missing(name, fn, opts)
    if vim.fn.exists(":" .. name) == 2 then
      return
    end
    vim.api.nvim_create_user_command(name, fn, opts)
  end

  create_command_if_missing("SpringBootRun", function(opts)
    run_spring("run", opts)
  end, {
    nargs = "*",
    desc = "Run Spring Boot app (Maven/Gradle auto-detect)",
  })

  create_command_if_missing("SpringBootTest", function(opts)
    run_spring("test", opts)
  end, {
    nargs = "*",
    desc = "Run Spring Boot tests (Maven/Gradle auto-detect)",
  })

  create_command_if_missing("SpringBootBuild", function(opts)
    run_spring("build", opts)
  end, {
    nargs = "*",
    desc = "Build Spring Boot app (Maven/Gradle auto-detect)",
  })

  create_command_if_missing("SpringBootStop", function()
    stop_spring()
  end, {
    nargs = 0,
    desc = "Stop running Spring Boot job",
  })

  vim.keymap.set("n", "<leader>jr", "<cmd>SpringBootRun<cr>", { desc = "Spring Boot Run", silent = true })
  vim.keymap.set("n", "<leader>jt", "<cmd>SpringBootTest<cr>", { desc = "Spring Boot Test", silent = true })
  vim.keymap.set("n", "<leader>jb", "<cmd>SpringBootBuild<cr>", { desc = "Spring Boot Build", silent = true })
  vim.keymap.set("n", "<leader>jS", "<cmd>SpringBootStop<cr>", { desc = "Spring Boot Stop", silent = true })

  vim.schedule(function()
    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.add({
        { "<leader>j", group = "java/spring" },
      })
    end
  end)
end
