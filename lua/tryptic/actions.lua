local u = require 'tryptic.utils'
local float = require 'tryptic.float'
local view = require 'tryptic.view'
local log = require 'tryptic.logger'
local plenary_path = require 'plenary.path'

local Actions = {}

--- TODO: Return type
---@param state TrypticState
function Actions.new(state)

  ---@return nil
  local function help()
    local win = state.windows.child.win
    float.win_set_title(win, 'Help', '󰋗', 'Directory')
    float.win_set_lines(win, require('tryptic.help').help_lines())
  end

  ---@return nil
  local function delete()
    local target = view.get_target_under_cursor(state)
    local response =
      vim.fn.confirm('Are you sure you want to delete "' .. target.display_name .. '"?', '&y\n&n', 'Question')
    if u.is_defined(response) and response == 1 then
      vim.fn.delete(target.path, 'rf')
      view.refresh_view(state)
    end
  end

  local function bulk_delete(_targets, skip_confirm)
    local targets = _targets or view.get_targets_in_selection(state)

    if skip_confirm then
      for _, target in ipairs(targets) do
        vim.fn.delete(target.path, 'rf')
      end
      view.refresh_view(state)
    else
      local response = vim.fn.confirm(
        'Are you sure you want to delete the ' .. #targets .. ' selected files/folders?',
        '&y\n&n',
        'Question'
      )
      if u.is_defined(response) and response == 1 then
        for _, target in ipairs(targets) do
          local success, result = pcall(function()
            vim.fn.delete(target.path, 'rf')
          end)
          if not success then
            log('DELETE', result or 'Error deleting item', 'ERROR')
          end
        end
        view.refresh_view(state)
      end
    end
  end

  ---@return nil
  local function add_file_or_dir()
    local current_directory = state.windows.current.path
    local response = vim.fn.trim(vim.fn.input 'Enter name for new file or directory (dirs end with a "/"): ')
    if u.is_empty(response) then
      return
    end
    local response_length = string.len(response)
    local includes_file = string.sub(response, response_length, response_length) ~= '/'
    if includes_file then
      local includes_dirs = string.find(response, '/') ~= nil

      if includes_dirs then
        local length_of_filename = string.find(string.reverse(response), '/') - 1
        local filename = string.sub(response, response_length - length_of_filename + 1, response_length)
        local dirs_to_create = string.sub(response, 1, response_length - length_of_filename)
        local absolute_dir_path = u.path_join(current_directory, dirs_to_create)
        vim.fn.mkdir(absolute_dir_path, 'p')
        -- TODO: writefile is destructive. Add checking
        vim.fn.writefile({}, absolute_dir_path .. filename)
      else
        vim.fn.writefile({}, u.path_join(current_directory, response))
      end
    else
      vim.fn.mkdir(u.path_join(current_directory, response), 'p')
    end

    view.refresh_view(state)
  end

  ---@return nil
  local function toggle_cut()
    local target = view.get_target_under_cursor(state)
    state:list_remove('copy', target)
    state:list_toggle('cut', target)
    view.refresh_view(state)
  end

  local function toggle_copy()
    local target = view.get_target_under_cursor(state)
    state:list_remove('cut', target)
    state:list_toggle('copy', target)
    view.refresh_view(state)
  end

  ---@return nil
  local function bulk_toggle_cut()
    local targets = view.get_targets_in_selection(state)
    local contains_cut_items = false
    local contains_uncut_items = false
    for _, target in ipairs(targets) do
      if state:list_contains('cut', target) then
        contains_cut_items = true
      else
        contains_uncut_items = true
      end
    end
    local is_mixed = contains_cut_items and contains_uncut_items
    for _, target in ipairs(targets) do
      if is_mixed or not state:list_contains('cut', target) then
        state:list_add('cut', target)
      else
        state:list_remove('cut', target)
      end
    end
    view.refresh_view(state)
  end

  ---@param target DirContents
  ---@param destination string
  ---@return nil
  local function duplicate_file_or_dir(target, destination)
    local p = plenary_path:new(target.path)
    p:copy {
      destination = destination,
      recursive = true,
      override = false,
      interactive = true,
    }
  end

  local function bulk_toggle_copy()
    local targets = view.get_targets_in_selection(state)
    local contains_copy_items = false
    local contains_noncopy_items = false
    for _, target in ipairs(targets) do
      if state:list_contains('copy', target) then
        contains_copy_items = true
      else
        contains_noncopy_items = true
      end
    end
    local is_mixed = contains_copy_items and contains_noncopy_items
    for _, target in ipairs(targets) do
      if is_mixed or not state:list_contains('copy', target) then
        state:list_add('copy', target)
      else
        state:list_add('copy', target)
      end
    end
    view.refresh_view(state)
  end

  ---@return nil
  local function rename()
    local target = view.get_target_under_cursor(state)
    local display_name = u.cond(target.is_dir, {
      when_true = u.trim_last_char(target.display_name),
      when_false = target.display_name,
    })
    local response = vim.fn.trim(vim.fn.input('Enter new name for "' .. display_name .. '": '))
    if u.is_defined(response) and response ~= target.display_name then
      vim.fn.rename(target.path, u.path_join(target.dirname, response))
      view.refresh_view(state)
    end
  end

  ---@return nil
  local function paste()
    local cursor_target = view.get_target_under_cursor(state)
    local destination_dir = u.cond(cursor_target.is_dir, {
      when_true = cursor_target.path,
      when_false = cursor_target.dirname,
    })
    ---@type DirContents[]
    local delete_list = {}

    local success, result = pcall(function()
      -- Handle cut items
      for _, item in ipairs(state.cut_list) do
        local destination = u.path_join(destination_dir, item.basename)
        if item.path ~= destination then
          -- TODO: Don't add to delete list unless the copy was successful
          duplicate_file_or_dir(item, destination)
          table.insert(delete_list, item)
        end
      end
      -- Handle copy items
      for _, item in ipairs(state.copy_list) do
        local destination = u.path_join(destination_dir, item.basename)
        if item.path ~= destination then
          duplicate_file_or_dir(item, destination)
        end
      end
      bulk_delete(delete_list, true)
      view.jump_cursor_to(state, destination_dir)
    end)
    if not success then
      -- TODO: Log this at warning level
      log('PASTE', 'Failed to paste: ' .. result, 'ERROR')
    end
    state:list_remove_all('cut')
    state:list_remove_all('copy')
    view.refresh_view(state)
  end

  ---@param path string
  ---@return nil
  local function edit_file(path)
    vim.g.tryptic_close()
    vim.cmd.edit(path)
  end

  local function toggle_hidden()
    local current_value = vim.g.tryptic_config.options.show_hidden
    vim.g.tryptic_config['options']['show_hidden'] = u.cond(current_value, {
      when_true = false,
      when_false = true,
    })
    view.refresh_view(state)
  end

  return {
    help = help,
    rename = rename,
    paste = paste,
    delete = delete,
    bulk_delete = bulk_delete,
    toggle_cut = toggle_cut,
    bulk_toggle_cut = bulk_toggle_cut,
    toggle_copy = toggle_copy,
    bulk_toggle_copy = bulk_toggle_copy,
    add_file_or_dir = add_file_or_dir,
    edit_file = edit_file,
    toggle_hidden = toggle_hidden,
  }
end

return {
  new = Actions.new
}
