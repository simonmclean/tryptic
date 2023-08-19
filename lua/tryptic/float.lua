local u = require 'tryptic.utils'
local fs = require 'tryptic.fs'
local log = require 'tryptic.logger'

local function modify_locked_buffer(buf, fn)
  vim.api.nvim_buf_set_option(buf, 'readonly', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  fn()
  vim.api.nvim_buf_set_option(buf, 'readonly', true)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function buf_set_lines(buf, lines)
  modify_locked_buffer(buf, function()
    vim.api.nvim_buf_set_option(buf, 'filetype', 'tryptic')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end)
end

local function buf_apply_highlights(buf, highlights)
  for i, highlight in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, 0, highlight, i - 1, 0, 3)
  end
end

local function win_set_lines(win, lines, attempt_scroll_top)
  local buf = vim.api.nvim_win_get_buf(win)
  buf_set_lines(buf, lines)
  if attempt_scroll_top then
    vim.api.nvim_buf_call(buf, function()
      vim.api.nvim_exec2('normal! zb', {})
    end)
  end
end

local function win_set_title(win, title, icon, highlight, postfix)
  vim.api.nvim_win_call(win, function()
    local maybe_icon = ''
    if icon then
      if highlight then
        maybe_icon = u.with_highlight_group(highlight, icon) .. ' '
      else
        maybe_icon = icon .. ' '
      end
    end
    local safe_title = string.gsub(title, '%%', '')
    if postfix then
      safe_title = safe_title .. ' ' .. u.with_highlight_group('Comment', postfix)
    end
    local title_with_hi = u.with_highlight_group('WinBar', safe_title)
    vim.wo.winbar = '%=' .. maybe_icon .. title_with_hi .. '%='
  end)
end

local function buf_set_lines_from_path(buf, path)
  modify_locked_buffer(buf, function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    local ft = fs.get_filetype_from_path(path)
    if ft == '' or ft == nil then
      ft = 'tryptic'
    end
    vim.api.nvim_buf_set_option(buf, 'filetype', ft)
    vim.api.nvim_buf_call(buf, function()
      local file_size = fs.get_file_size_in_kb(path)
      if file_size < 300 then
        local success = pcall(function()
          vim.cmd.read(path)
        end)
        if success then
          --TODO: This is kind of hacky
          vim.api.nvim_exec2('normal! 1G0dd', {})
        else
          local msg = '[Unable to preview file contents]'
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', msg })
        end
      else
        local msg = '[File size too large to preview]'
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', msg })
      end
    end)
  end)
end

local function create_new_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  modify_locked_buffer(buf, function()
    buf_set_lines(buf, lines)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'tryptic')
  end)
  return buf
end

local function create_floating_window(config)
  local buf = create_new_buffer {}
  local win = vim.api.nvim_open_win(buf, true, {
    width = config.width,
    height = config.height,
    relative = 'editor',
    col = config.x_pos,
    row = config.y_pos,
    border = 'single',
    style = 'minimal',
    noautocmd = true,
    focusable = config.is_focusable,
  })
  vim.api.nvim_win_set_option(win, 'cursorline', config.enable_cursorline)
  vim.api.nvim_win_set_option(win, 'number', config.show_numbers)
  return win
end

local function create_three_floating_windows()
  local max_width = 220
  local max_height = 45
  local screen_height = vim.o.lines
  local screen_width = vim.o.columns
  local padding = 4
  local max_float_width = math.floor(max_width / 3)
  local float_width = math.min(math.floor((screen_width / 3)) - padding, max_float_width)
  local float_height = math.min(screen_height - (padding * 3), max_height)

  local wins = {}

  local x_pos = u.cond(screen_width > (max_width + (padding * 2)), {
    when_true = math.floor((screen_width - max_width) / 2),
    when_false = padding,
  })
  local y_pos = u.cond(screen_height > (max_height + (padding * 2)), {
    when_true = math.floor((screen_height - max_height) / 2),
    when_false = padding,
  })
  for i = 1, 3, 1 do
    local is_parent = i == 1
    local is_primary = i == 2
    local is_child = i == 3
    if is_primary then
      x_pos = x_pos + float_width + 2
    elseif is_child then
      x_pos = x_pos + float_width + 2
    end
    local win = create_floating_window {
      width = float_width,
      height = float_height,
      y_pos = y_pos,
      x_pos = x_pos,
      omit_left_border = is_primary or is_child,
      omit_right_border = is_parent or is_primary,
      enable_cursorline = is_parent or is_primary,
      is_focusable = is_primary,
      show_numbers = is_primary,
    }

    table.insert(wins, win)
  end

  -- Focus the middle window
  vim.api.nvim_set_current_win(wins[2])

  return wins
end

local function close_floats(wins)
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

return {
  create_floating_window = create_floating_window,
  create_three_floating_windows = create_three_floating_windows,
  close_floats = close_floats,
  buf_set_lines = buf_set_lines,
  buf_set_lines_from_path = buf_set_lines_from_path,
  win_set_lines = win_set_lines,
  win_set_title = win_set_title,
  buf_apply_highlights = buf_apply_highlights,
}
