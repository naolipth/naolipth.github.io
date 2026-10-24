-- Builds the Research page's publication list from the bibliography and puts it
-- in the empty ::: {#publications} div of research.qmd. Publications are grouped
-- by type, newest first; each is a citation (citation.lua) followed by a row of
-- buttons with roll-down panels (actions.lua).
--
-- Front matter used:
--   bibliography       .bib file(s) to list (set in _quarto.yml)
--   publication-owner  family/given name to bold in author lists
--   publication-links  extras per BibTeX ID: folder (research/<name>), code (URL)

-- Paths are relative to the project root, where Quarto runs the filter.
local function load_module(name) return dofile('filters/' .. name .. '.lua') end
local utils = load_module('utils')
local bib_source = load_module('bib-source')
local citation = load_module('citation')
local actions = load_module('actions')
local text, year = utils.text, utils.year

-- Sections in display order. Every publication type in the .bib must be listed.
local sections = {
  {kind = 'article-journal', title = 'Articles', id = 'articles'},
  {kind = 'chapter', title = 'Book chapters', id = 'book-chapters'},
}

-- Newest first; ties are broken by title, then by BibTeX ID, so the order is stable.
local function newest_first(a, b)
  if year(a) ~= year(b) then return year(a) > year(b) end
  local ta, tb = pandoc.text.lower(text(a.title)), pandoc.text.lower(text(b.title))
  if ta ~= tb then return ta < tb end
  return text(a.id) < text(b.id)
end

-- One list item: the citation, then the button row and its panels.
local function entry(ref, extra, source, owner)
  local id = 'pub-' .. text(ref.id)
  local blocks = pandoc.Blocks({pandoc.Para(citation.build(ref, source, owner))})
  blocks:extend(actions.build(id, ref, extra, source))
  return {pandoc.Div(blocks, pandoc.Attr(id, {'publication'}))}
end

function Pandoc(doc)
  if not FORMAT:match('html') then return doc end

  -- Read every bibliography file; sources gets the raw entry and eid per BibTeX ID.
  local refs, sources = bib_source.read_all(doc.meta.bibliography)
  assert(#refs > 0, 'No publications found')
  table.sort(refs, newest_first)

  local meta = doc.meta['publication-owner']
  local owner = {family = text(meta.family), given = text(meta.given)}
  local extras = doc.meta['publication-links'] or {}
  for id in pairs(extras) do assert(sources[id], 'Unknown publication-links key: ' .. id) end

  -- Build each entry and put it in its section.
  local items = {}
  for _, section in ipairs(sections) do items[section.kind] = {} end
  for _, ref in ipairs(refs) do
    local id, kind = text(ref.id), text(ref.type)
    assert(items[kind], 'Unsupported publication type: ' .. kind)
    assert(sources[id], 'Missing original BibTeX entry: ' .. id)
    table.insert(items[kind], entry(ref, extras[id] or {}, sources[id], owner))
  end

  -- One heading and bullet list per non-empty section.
  local blocks = pandoc.Blocks({})
  for _, section in ipairs(sections) do
    if #items[section.kind] > 0 then
      blocks:insert(pandoc.Header(2, section.title, pandoc.Attr(section.id)))
      blocks:insert(pandoc.Div({pandoc.OrderedList(items[section.kind])}, pandoc.Attr('', {'publication-list'})))
    end
  end

  -- Browser behaviour for the panel buttons and Copy, kept in a real .js file.
  local script = assert(utils.read_file('filters/publications.js'), 'Missing filters/publications.js')
  blocks:insert(pandoc.RawBlock('html', '<script>\n' .. script .. '</script>'))

  -- Put the list into the empty ::: {#publications} div.
  local found = false
  doc = doc:walk({Div = function(div)
    if div.identifier == 'publications' then
      found, div.content = true, blocks
      return div
    end
  end})
  assert(found, 'Missing #publications placeholder')
  return doc
end
