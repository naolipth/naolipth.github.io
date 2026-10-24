-- Read a bibliography file. Pandoc parses the fields; the raw entry text and
-- the BibLaTeX eid, which Pandoc drops, are taken from the source.
local utils = dofile('filters/utils.lua')

local M = {}

-- Returns Pandoc's references for the file and adds {raw, eid} per BibTeX ID
-- to sources, which is shared across files so duplicate IDs are caught.
function M.read(path, sources)
  local input = assert(utils.read_file(path), 'Cannot read bibliography: ' .. path)
  for kind, body in input:gmatch('@(%a+)%s*(%b{})') do
    local k = kind:lower()
    if k ~= 'comment' and k ~= 'preamble' and k ~= 'string' then
      local id = body:match('^{%s*([^,%s]+)')
      assert(not sources[id], 'Duplicate BibTeX ID: ' .. id)
      sources[id] = {raw = '@' .. kind .. body, eid = body:match('[,%s]eid%s*=%s*{(.-)}')}
    end
  end
  return pandoc.read(input, 'biblatex').meta.references or {}
end

-- Reads every bibliography file in the front matter (one path or a list).
-- Returns all references and the {raw, eid} sources per BibTeX ID.
function M.read_all(paths)
  if pandoc.utils.type(paths) ~= 'List' then paths = {paths} end
  local refs, sources = pandoc.List({}), {}
  for _, path in ipairs(paths) do refs:extend(M.read(utils.text(path), sources)) end
  return refs, sources
end

return M
