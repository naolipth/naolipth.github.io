-- Small helpers shared by the publication filter modules.
local M = {}

-- Plain text of a Pandoc value, or '' when the value is missing.
function M.text(value)
  return value and pandoc.utils.stringify(value) or ''
end

-- Publication year as a number; 0 when the entry has no date.
function M.year(ref)
  return tonumber(M.text(ref.issued):match('%d%d%d%d')) or 0
end

-- Escape a string for use inside raw HTML.
function M.escape(s)
  return (s:gsub('[&<>"]', {['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;'}))
end

-- Contents of a file, or nil when it does not exist.
function M.read_file(path)
  local file = io.open(path, 'r')
  if not file then return nil end
  local content = file:read('a')
  file:close()
  return content
end

return M
