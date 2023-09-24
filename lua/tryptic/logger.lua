---@param message string | table
---@return nil
local function log_err(message)
  local vim = _G.tryptic_mock_vim or vim
  -- TODO: Figure out how to properly log errors
  vim.print(message)
end

---@param label string
---@param message string | table
---@param level 'INFO' | 'WARN' | 'ERROR' | 'DEBUG'
local function log(label, message, level)
  local vim = _G.tryptic_mock_vim or vim
  if level ~= 'INFO' and level ~= 'WARN' and level ~= 'ERROR' and level ~= 'DEBUG' then
    log_err 'echoerr Invalid log level'
    return
  end

  local prefix = 'TRYPTIC[' .. level .. '][' .. label .. '] '

  local debug_mode = vim.g.tryptic_config.debug

  -- If message is a table, the table is printed on its own line
  if type(message) == 'table' then
    if level == 'ERROR' then
      log_err(prefix)
      log_err(message)
    elseif level ~= 'DEBUG' or (level == 'DEBUG' and debug_mode) then
      vim.print(prefix)
      vim.print(message)
    end
  else
    local final_message = prefix .. tostring(message)
    if level == 'ERROR' then
      log_err(final_message)
    elseif level ~= 'DEBUG' or (level == 'DEBUG' and debug_mode) then
      vim.print(final_message)
    end
  end
end

return log