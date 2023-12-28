local float = require 'triptych.float'
local autocmds = require 'triptych.autocmds'
local state = require 'triptych.state'
local mappings = require 'triptych.mappings'
local actions = require 'triptych.actions'
local view = require 'triptych.view'
local git = require 'triptych.git'
local diagnostics = require 'triptych.diagnostics'
local event_handlers = require 'triptych.event_handlers'
local file_reader = require 'triptych.file_reader'
local u = require 'triptych.utils'

---@param msg string
---@return nil
local function warn(msg)
  vim.notify(msg, vim.log.levels.WARN, { title = 'triptych' })
end

---@param dir? string Path of directory to open. If omitted will be the directory containing the current buffer
---@return fun()|nil
local function open_triptych(dir)
  local vim = _G.triptych_mock_vim or vim

  if dir and not vim.fn.isdirectory(dir) then
    return warn(tostring(dir) .. ' is not a directory')
  end

  if vim.g.triptych_is_open then
    return
  end

  local config = vim.g.triptych_config
  local State = state.new(config, vim.api.nvim_get_current_win())
  local Git = config.git_signs.enabled and git.Git.new() or nil
  local Diagnostics = config.diagnostic_signs.enabled and diagnostics.new() or nil
  local FileReader = file_reader.new(config.options.syntax_highlighting.debounce_ms)

  local maybe_buf_name = u.cond(dir, {
    when_true = nil,
    when_false = vim.api.nvim_buf_get_name(0),
  })
  local opening_dir = dir
    or u.cond(u.is_defined(maybe_buf_name), {
      when_true = vim.fs.dirname(maybe_buf_name),
      when_false = vim.fn.getcwd(),
    })
  local windows = float.create_three_floating_windows(
    config.options.line_numbers.enabled,
    config.options.line_numbers.relative,
    config.options.column_widths
  )

  State.windows = {
    parent = {
      path = '',
      win = windows[1],
    },
    current = {
      path = '',
      previous_path = '',
      win = windows[2],
    },
    child = {
      win = windows[3],
      is_dir = false,
    },
  }

  -- Autocmds need to be created after the above state is set
  local AutoCmds = autocmds.new(event_handlers, FileReader, State, Diagnostics, Git)
  local refresh_fn = function()
    view.refresh_view(State, Diagnostics, Git)
  end
  local Actions = actions.new(State, refresh_fn, Diagnostics, Git)
  mappings.new(State, Actions)

  local close = function()
    vim.g.triptych_is_open = false
    -- Need to destroy autocmds before the floating windows
    AutoCmds:destroy_autocommands()
    local wins = State.windows
    float.close_floats {
      wins.parent.win,
      wins.current.win,
      wins.child.win,
    }
    vim.api.nvim_set_current_win(State.opening_win)
    FileReader:destroy()
  end

  view.nav_to(State, opening_dir, Diagnostics, Git, maybe_buf_name)

  vim.g.triptych_is_open = true
  vim.g.triptych_close = close

  return close
end

---@param user_config? table
local function setup(user_config)
  local vim = _G.triptych_mock_vim or vim

  if vim.fn.has 'nvim-0.9.0' ~= 1 then
    return warn 'triptych.nvim requires Neovim >= 0.9.0'
  end

  local plenary_installed, _ = pcall(require, 'plenary')

  if not plenary_installed then
    return warn 'triptych.nvim requires plenary.nvim'
  end

  vim.g.triptych_is_open = false

  vim.api.nvim_create_user_command('Triptych', function()
    open_triptych()
  end, {})

  vim.g.triptych_config = require('triptych.config').create_merged_config(user_config or {})
end

return {
  open_triptych = open_triptych,
  setup = setup,
}
