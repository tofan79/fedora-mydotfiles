-- ================================================================================================
-- TITLE : snacks.nvim
-- ABOUT : QoL plugins for nvim
-- LINKS :
--   > github: https://github.com/folke/snacks.nvim
-- ================================================================================================
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    dashboard = {
      enabled = function()
        -- Disable dashboard when opening a directory
        local argc = vim.fn.argc()
        if argc == 1 then
          local arg = vim.fn.argv(0)
          local stat = vim.loop.fs_stat(arg)
          if stat and stat.type == 'directory' then
            return false
          end
        end
        return true
      end,
      preset = {
        header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
      },
      sections = {
        { section = 'header' },
        { section = 'keys', gap = 1, padding = 1 },
        { section = 'startup', icon = '🚀 ' },
      },
    },
    explorer = {
      enabled = true,
      -- Use saved directory if available, otherwise current working directory
      cwd = vim.g.snacks_explorer_cwd or vim.fn.getcwd(),
    },
    indent = { enabled = true },
    image = { enabled = true },
    input = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    picker = {
      enabled = true,
      -- Default to opening files in tabs
      confirm = 'tab',
      sources = {
        explorer = {
          auto_close = false, -- Don't close explorer when opening files
          jump = { close = false }, -- Keep explorer open on file jump
          hidden = true, -- Show dotfiles by default
          -- Track directory changes to persist between sessions
          on_change = function(picker)
            vim.g.snacks_explorer_cwd = picker:cwd()
          end,
          -- Fix: Override delete keybinding in the list window (not input)
          -- Use default sidebar layout (no custom layout config needed)
          -- Override the list window keymaps
          win = {
            list = {
              keys = {
                ["d"] = { "explorer_delete", mode = { "n" } },
                ["<c-d>"] = { "explorer_delete", mode = { "n" } },
                ["f"] = { "explorer_menu", mode = { "n" } },
                ["<RightMouse>"] = { "explorer_menu", mode = { "n" } },
              },
            },
          },
          -- Custom actions
          actions = {
            explorer_delete = function(picker)
              local item = picker:current()
              if not item then
                Snacks.notify.warn("No item selected", { title = "Explorer" })
                return
              end
              
              -- Get the file path from the item
              local path = item.file
              if not path or path == "" then
                Snacks.notify.warn("Cannot delete: no file path", { title = "Explorer" })
                return
              end
              
              -- Show confirmation dialog
              local name = vim.fn.fnamemodify(path, ":t")
              local choice = vim.fn.confirm("Delete " .. name .. "?", "&Yes\n&No", 2)
              
              if choice == 1 then
                -- Delete the file/directory
                local stat = vim.loop.fs_stat(path)
                local ok, err
                
                if stat and stat.type == "directory" then
                  ok, err = pcall(vim.fn.delete, path, "rf")
                else
                  ok, err = pcall(vim.fn.delete, path)
                end
                
                if ok then
                  Snacks.notify.info("Deleted: " .. name, { title = "Explorer" })
                  -- Refresh without jumping (this avoids the error)
                  picker:find({
                    on_done = function()
                      -- Don't jump to the deleted item
                    end,
                  })
                else
                  Snacks.notify.error("Failed to delete: " .. tostring(err), { title = "Explorer" })
                end
              end
            end,
            explorer_menu = function(picker)
              -- Show a menu using vim.ui.select
              local item = picker:current()
              if not item then
                Snacks.notify.warn("No item selected", { title = "Explorer" })
                return
              end

              local path = item.file or item.dir
              local is_dir = item.dir ~= nil

              local items = {
                { label = "📁 Add new file/dir", action = "explorer_add" },
                { label = "✏️  Rename", action = "explorer_rename" },
                { label = "🗑️  Delete", action = "explorer_delete" },
                { label = "📎 Yank path", action = "explorer_yank" },
                { label = "🔓 Open with system", action = "explorer_open" },
                { label = "🔄 Refresh", action = "explorer_update" },
              }

              vim.ui.select(items, {
                prompt = "File Menu",
                format_item = function(item)
                  return item.label
                end,
              }, function(choice)
                if not choice then
                  return
                end

                local action_name = choice.action

                -- Handle built-in actions
                if action_name == "explorer_add" then
                  -- Prompt for new file/directory name
                  vim.ui.input({ prompt = "New file/directory name (end with / for dir): " }, function(input)
                    if not input or input == "" then
                      return
                    end
                    local new_path = path .. "/" .. input
                    if input:sub(-1) == "/" then
                      -- Create directory
                      vim.fn.mkdir(new_path, "p")
                      Snacks.notify.info("Created directory: " .. input, { title = "Explorer" })
                    else
                      -- Create file
                      local dir = vim.fn.fnamemodify(new_path, ":h")
                      vim.fn.mkdir(dir, "p")
                      local file = io.open(new_path, "w")
                      if file then
                        file:close()
                        Snacks.notify.info("Created file: " .. input, { title = "Explorer" })
                      end
                    end
                    picker:find()
                  end)

                elseif action_name == "explorer_rename" then
                  local old_name = vim.fn.fnamemodify(path, ":t")
                  vim.ui.input({ prompt = "Rename to: ", default = old_name }, function(input)
                    if not input or input == "" or input == old_name then
                      return
                    end
                    local new_path = vim.fn.fnamemodify(path, ":h") .. "/" .. input
                    local ok, err = pcall(vim.fn.rename, path, new_path)
                    if ok then
                      Snacks.notify.info("Renamed to: " .. input, { title = "Explorer" })
                      picker:find()
                    else
                      Snacks.notify.error("Failed to rename: " .. tostring(err), { title = "Explorer" })
                    end
                  end)

                elseif action_name == "explorer_yank" then
                  vim.fn.setreg("+", path)
                  vim.fn.setreg("\"", path)
                  Snacks.notify.info("Yanked: " .. path, { title = "Explorer" })

                elseif action_name == "explorer_open" then
                  vim.ui.open(path)

                elseif action_name == "explorer_update" then
                  picker:find()
                  Snacks.notify.info("Refreshed", { title = "Explorer" })

                else
                  -- For other actions, try to call them if they exist
                  local ok, err = pcall(function()
                    picker:action(action_name)
                  end)
                  if not ok then
                    Snacks.notify.error("Action '" .. action_name .. "' not available: " .. tostring(err), { title = "Explorer" })
                  end
                end
              end)
            end,
          },
        },
      },
    },
    quickfile = { enabled = true },
    scope = { enabled = true },
    scroll = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    styles = {
      notification = {
        wo = { wrap = true }, -- Wrap notifications
      },
    },
  },
  -- stylua: ignore start
  keys = {
    -- Top Pickers & Explorer
    { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>n", function() Snacks.picker.notifications() end, desc = "Notification History" },
    { "<leader>e", function() Snacks.explorer({ cwd = vim.g.snacks_explorer_cwd }) end, desc = "File Explorer" },
    -- find
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
    { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
    { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
    -- git
    { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git Branches" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git Log" },
    { "<leader>gL", function() Snacks.picker.git_log_line() end, desc = "Git Log Line" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
    { "<leader>gS", function() Snacks.picker.git_stash() end, desc = "Git Stash" },
    { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Git Diff (Hunks)" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "Git Log File" },
    -- gh
    { "<leader>gi", function() Snacks.picker.gh_issue() end, desc = "GitHub Issues (open)" },
    { "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end, desc = "GitHub Issues (all)" },
    { "<leader>gp", function() Snacks.picker.gh_pr() end, desc = "GitHub Pull Requests (open)" },
    { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end, desc = "GitHub Pull Requests (all)" },
    -- Grep
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
    { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Visual selection or word", mode = { "n", "x" } },
    -- search
    { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
    { '<leader>s/', function() Snacks.picker.search_history() end, desc = "Search History" },
    { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
    { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>sC", function() Snacks.picker.commands() end, desc = "Commands" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
    { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
    { "<leader>sH", function() Snacks.picker.highlights() end, desc = "Highlights" },
    { "<leader>si", function() Snacks.picker.icons() end, desc = "Icons" },
    { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
    { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location List" },
    { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
    { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
    { "<leader>sp", function() Snacks.picker.lazy() end, desc = "Search for Plugin Spec" },
    { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
    { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume" },
    { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo History" },
    { "<leader>SC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
    -- LSP
    { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
    { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
    { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
    { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
    { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto T[y]pe Definition" },
    { "gai", function() Snacks.picker.lsp_incoming_calls() end, desc = "C[a]lls Incoming" },
    { "gao", function() Snacks.picker.lsp_outgoing_calls() end, desc = "C[a]lls Outgoing" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP Symbols" },
    { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
    -- Other
    { "<leader>ps", function() Snacks.profiler.scratch() end, desc = "Profiler Scratch Bufer" },
    { "<leader>z",  function() Snacks.zen() end, desc = "Toggle Zen Mode" },
    { "<leader>Z",  function() Snacks.zen.zoom() end, desc = "Toggle Zoom" },
    { "<leader>.",  function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
    { "<leader>S",  function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },
    { "<leader>n",  function() Snacks.notifier.show_history() end, desc = "Notification History" },
    { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
    { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename File" },
    { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Git Browse", mode = { "n", "v" } },
    { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
    { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
    { "<c-/>",      function() Snacks.terminal() end, desc = "Toggle Terminal" },
    { "<c-_>",      function() Snacks.terminal() end, desc = "which_key_ignore" },
    { "]]",         function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference", mode = { "n", "t" } },
    { "[[",         function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference", mode = { "n", "t" } },
    {
      "<leader>N",
      desc = "Neovim News",
      function()
        Snacks.win({
          file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
          width = 0.6,
          height = 0.6,
          wo = {
            spell = false,
            wrap = false,
            signcolumn = "yes",
            statuscolumn = " ",
            conceallevel = 3,
          },
        })
      end,
    }
  },
  -- stylua: ignore end
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end

        -- Override print to use snacks for `:=` command
        if vim.fn.has 'nvim-0.11' == 1 then
          vim._print = function(_, ...)
            dd(...)
          end
        else
          vim.print = _G.dd
        end

        -- Create some toggle mappings
        Snacks.toggle.profiler():map '<leader>pp'
        Snacks.toggle.profiler_highlights():map '<leader>ph'
        Snacks.toggle.option('spell', { name = 'Spelling' }):map '<leader>Ss'
        Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>Sw'
        Snacks.toggle.option('relativenumber', { name = 'Relative Number' }):map '<leader>SL'
        Snacks.toggle.diagnostics():map '<leader>Sd'
        Snacks.toggle.line_number():map '<leader>Sl'
        Snacks.toggle.option('conceallevel', { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map '<leader>Sc'
        Snacks.toggle.treesitter():map '<leader>ST'
        Snacks.toggle.option('background', { off = 'light', on = 'dark', name = 'Dark Background' }):map '<leader>Sb'
        Snacks.toggle.inlay_hints():map '<leader>Sh'
        Snacks.toggle.indent():map '<leader>Sg'
        Snacks.toggle.dim():map '<leader>SD'
      end,
    })

  end,
}
