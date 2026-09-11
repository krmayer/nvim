assert(vim.fn.has 'nvim-0.12' == 1, 'This configuration requires Neovim 0.12+')

local config_group = vim.api.nvim_create_augroup('user_config', { clear = true })

vim.g.mapleader = ' '

vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = 'yes'
vim.o.scrolloff = 8
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.winborder = 'rounded'
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.breakindent = true

vim.o.mouse = 'a'
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.timeoutlen = 300
vim.o.confirm = true
vim.o.inccommand = 'split'
vim.o.autocomplete = true
vim.o.autocompletedelay = 120
vim.opt.complete = { 'o^20', '.^10', 'w^5', 'b^5' }
vim.opt.completeopt = { 'menuone', 'noselect', 'popup', 'fuzzy' }

vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.softtabstop = -1

vim.diagnostic.config {
  severity_sort = true,
  float = { source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  virtual_text = { source = 'if_many', spacing = 2 },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostics location list' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down and center' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and center' })
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next search match and center' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Previous search match and center' })
vim.keymap.set('n', 'J', function()
  local view = vim.fn.winsaveview()
  local count = vim.v.count == 0 and '' or tostring(vim.v.count)

  vim.cmd('normal! ' .. count .. 'J')
  vim.fn.winrestview(view)
end, { desc = 'Join lines without moving the cursor' })
vim.keymap.set('x', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('x', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })
vim.keymap.set('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = 'Substitute word in buffer' })

local runner_buf

local function shell_join(args) return table.concat(vim.tbl_map(vim.fn.shellescape, args), ' ') end

local function run_in_terminal(command, cwd)
  if runner_buf and vim.api.nvim_buf_is_valid(runner_buf) then
    for _, win in ipairs(vim.fn.win_findbuf(runner_buf)) do
      vim.api.nvim_win_close(win, true)
    end
  end
  runner_buf = nil

  local source_win = vim.api.nvim_get_current_win()
  vim.cmd 'botright 10new'
  runner_buf = vim.api.nvim_get_current_buf()
  local runner_win = vim.api.nvim_get_current_win()
  vim.bo[runner_buf].bufhidden = 'wipe'
  vim.wo.winfixheight = true
  local job = vim.fn.jobstart(command, { cwd = cwd, term = true })

  if vim.api.nvim_win_is_valid(source_win) then vim.api.nvim_set_current_win(source_win) end

  if job <= 0 then
    if vim.api.nvim_win_is_valid(runner_win) then vim.api.nvim_win_close(runner_win, true) end
    runner_buf = nil
    vim.notify('Failed to start runner', vim.log.levels.ERROR)
  end
end

local runner_filetypes = { c = true, cpp = true, go = true, python = true, rust = true }

vim.keymap.set('n', '<leader>r', function()
  local ft = vim.bo.filetype
  if not runner_filetypes[ft] then return vim.notify('No runner for filetype: ' .. ft, vim.log.levels.WARN) end

  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then return vim.notify('Save the file before running it', vim.log.levels.WARN) end

  vim.cmd.write()
  local cwd = vim.fs.dirname(file)

  local function compile_and_run(args)
    local binary = ('%s/run/%s-%s'):format(vim.fn.stdpath 'cache', vim.fn.fnamemodify(file, ':t:r'), vim.fn.sha256(file):sub(1, 8))
    vim.fn.mkdir(vim.fs.dirname(binary), 'p')
    vim.list_extend(args, { '-o', binary })
    return shell_join(args) .. ' && ' .. vim.fn.shellescape(binary)
  end

  local command
  if ft == 'c' then
    command = compile_and_run { 'clang', '-std=c23', '-Wall', '-Wextra', '-Wpedantic', file }
  elseif ft == 'cpp' then
    command = compile_and_run { 'clang++', '-std=c++23', '-Wall', '-Wextra', '-Wpedantic', file }
  elseif ft == 'go' then
    local module = vim.fs.find('go.mod', { path = cwd, upward = true })[1]
    command = { 'go', 'run', module and '.' or file }
  elseif ft == 'python' then
    command = vim.fn.executable 'uv' == 1 and { 'uv', 'run', file } or { 'python3', file }
  elseif ft == 'rust' then
    local manifest = vim.fs.find('Cargo.toml', { path = cwd, upward = true })[1]
    if manifest then
      cwd = vim.fs.dirname(manifest)
      command = { 'cargo', 'run' }
    else
      command = compile_and_run { 'rustc', '--edition=2024', file }
    end
  end

  run_in_terminal(command, cwd)
end, { desc = 'Run current program' })

vim.api.nvim_create_autocmd('TextYankPost', {
  group = config_group,
  callback = function() vim.hl.on_yank() end,
  desc = 'Highlight yanked text',
})

local function gh(repo) return 'https://github.com/' .. repo end

vim.api.nvim_create_autocmd('PackChanged', {
  group = config_group,
  callback = function(event)
    if event.data.spec.name ~= 'nvim-treesitter' or not vim.tbl_contains({ 'install', 'update' }, event.data.kind) then return end
    if not event.data.active then vim.cmd.packadd 'nvim-treesitter' end
    vim.cmd 'TSUpdate'
  end,
  desc = 'Update Tree-sitter parsers after plugin changes',
})

vim.pack.add({
  { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' },
  gh 'nvim-lua/plenary.nvim',
  gh 'nvim-telescope/telescope.nvim',
  gh 'neovim/nvim-lspconfig',
  gh 'mason-org/mason.nvim',
  gh 'mason-org/mason-lspconfig.nvim',
  gh 'nvzone/volt',
  gh 'nvzone/typr',
  gh 'folke/tokyonight.nvim',
}, { confirm = false, load = true })

local treesitter = require 'nvim-treesitter'
local parsers = { 'bash', 'c', 'cpp', 'go', 'gomod', 'lua', 'python', 'query', 'rust', 'vim', 'vimdoc' }
treesitter.install(parsers):wait(300000)

vim.api.nvim_create_autocmd('FileType', {
  group = config_group,
  callback = function(event)
    local language = vim.treesitter.language.get_lang(event.match)
    if not vim.tbl_contains(parsers, language) then return end
    if not vim.treesitter.language.add(language) then return end
    vim.treesitter.start(event.buf, language)
  end,
  desc = 'Enable Tree-sitter highlighting when a configured parser is available',
})

local telescope = require 'telescope.builtin'
vim.keymap.set('n', '<leader>f', telescope.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>g', telescope.live_grep, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>b', telescope.buffers, { desc = 'Buffers' })
vim.keymap.set('n', '<leader>/', telescope.current_buffer_fuzzy_find, { desc = 'Search buffer' })

require('mason').setup {}
local nvim_config_path = vim.uv.fs_realpath(vim.fn.stdpath 'config')

local servers = {
  clangd = {
    filetypes = { 'c' },
    init_options = { fallbackFlags = { '-std=c23' } },
  },
  gopls = {},
  lua_ls = {
    on_init = function(client)
      local workspace = client.workspace_folders and client.workspace_folders[1]
      if not workspace then return end
      if vim.uv.fs_realpath(workspace.name) ~= nvim_config_path then return end

      client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = {
          version = 'LuaJIT',
          path = {
            'lua/?.lua',
            'lua/?/init.lua',
          },
        },
        workspace = {
          checkThirdParty = false,
          library = {
            vim.env.VIMRUNTIME,
            vim.api.nvim_get_runtime_file('lua/lspconfig', false)[1],
          },
        },
      })
    end,
    settings = {
      Lua = {
        completion = {
          callSnippet = 'Replace',
        },
      },
    },
  },
  pyright = {},
  ruff = {},
  rust_analyzer = {},
}

for name, config in pairs(servers) do
  vim.lsp.config(name, config)
end

local clangd_cpp = vim.deepcopy(vim.lsp.config.clangd)
clangd_cpp.filetypes = { 'cpp' }
clangd_cpp.init_options.fallbackFlags = { '-std=c++23' }
vim.lsp.config('clangd_cpp', clangd_cpp)

local server_names = vim.tbl_keys(servers)
require('mason-lspconfig').setup {
  ensure_installed = server_names,
  automatic_enable = server_names,
}
vim.lsp.enable 'clangd_cpp'

vim.api.nvim_create_autocmd('LspAttach', {
  group = config_group,
  callback = function(event)
    local client = assert(vim.lsp.get_client_by_id(event.data.client_id))
    if client.name == 'ruff' then client.server_capabilities.hoverProvider = false end
    if client:supports_method 'textDocument/completion' then vim.lsp.completion.enable(true, client.id, event.buf) end
  end,
  desc = 'Configure attached LSP client',
})

local formatters = {
  c = 'clangd',
  cpp = 'clangd_cpp',
  go = 'gopls',
  python = 'ruff',
  rust = 'rust_analyzer',
}

vim.api.nvim_create_autocmd('BufWritePre', {
  group = config_group,
  callback = function(event)
    local name = formatters[vim.bo[event.buf].filetype]
    if not name then return end

    local clients = vim.lsp.get_clients {
      bufnr = event.buf,
      name = name,
      method = 'textDocument/formatting',
    }

    if #clients == 0 then return end

    vim.lsp.buf.format {
      bufnr = event.buf,
      name = name,
      timeout_ms = 1000,
    }
  end,
  desc = 'Format with the canonical LSP client',
})

require('typr').setup {
  on_attach = function(bufnr) vim.bo[bufnr].autocomplete = false end,
}

vim.cmd.colorscheme 'tokyonight-night'
