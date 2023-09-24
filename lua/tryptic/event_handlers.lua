local view = require 'tryptic.view'

---@param State TrypticState
---@param Diagnostics Diagnostics
---@param GitStatus GitStatus
---@param GitIgnore GitIgnore
---@return nil
local function handle_cursor_moved(State, Diagnostics, GitStatus, GitIgnore)
  local vim = _G.tryptic_mock_vim or vim
  local target = view.get_target_under_cursor(State)
  local current_dir = State.windows.current.path
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  if current_dir then
    State.path_to_line_map[current_dir] = line_number
    view.update_child_window(State, target, Diagnostics, GitStatus, GitIgnore)
  end
end

---@return nil
local function handle_buf_leave()
  vim.g.tryptic_close()
end

return {
  handle_cursor_moved = handle_cursor_moved,
  handle_buf_leave = handle_buf_leave,
}