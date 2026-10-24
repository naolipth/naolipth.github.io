-- Builds the home page's Selected papers row from the bibliography and puts it
-- in the empty ::: {#selected-publications} div of index.qmd. Each paper is one
-- card (year and venue, title, authors, summary, links); selected-research.js
-- adds the step buttons.
--
-- Front matter used:
--   bibliography           .bib file(s) to read (set in _quarto.yml)
--   publication-links      extras per BibTeX ID: folder (required here, must hold
--                          _selected-summary.md), code
--   selected-publications  BibTeX IDs to show, in display order

-- Paths are relative to the project root, where Quarto runs the filter.
local function load_module(name) return dofile('filters/' .. name .. '.lua') end
local utils = load_module('utils')
local bib_source = load_module('bib-source')
local text, escape = utils.text, utils.escape

-- Pandoc inlines or blocks as an HTML string.
local function html(content)
  if pandoc.utils.type(content) == 'Inlines' then content = {pandoc.Plain(content)} end
  return (pandoc.write(pandoc.Pandoc(content), 'html'):gsub('%s+$', ''))
end

-- APA initials of a given name: "Marcell P." -> "M. P.", "Jean-Paul" -> "J.-P."
-- pandoc.text.sub counts characters, so accented initials stay whole.
local function initials(given)
  local words = {}
  for word in given:gmatch('%S+') do
    local parts = {}
    for part in word:gmatch('[^-]+') do parts[#parts + 1] = pandoc.text.sub(part, 1, 1) .. '.' end
    words[#words + 1] = table.concat(parts, '-')
  end
  return table.concat(words, ' ')
end

-- APA author list: "Family, G." joined with ", " and ", & " before the last.
-- Organisations (literal names) are used as written.
local function authors(ref)
  local names = {}
  for _, author in ipairs(ref.author or {}) do
    local name = text(author.literal)
    if name == '' then
      local particle = text(author['non-dropping-particle'])
      name = (particle ~= '' and particle .. ' ' or '') .. text(author.family)
      local given = text(author.given)
      if given ~= '' then name = name .. ', ' .. initials(given) end
    end
    names[#names + 1] = name
  end
  if #names < 2 then return names[1] or '' end
  return table.concat(names, ', ', 1, #names - 1) .. ', & ' .. names[#names]
end

-- One card. The summary is the paper's research folder's _selected-summary.md.
-- Links: Paper (DOI, else URL), Code, and Abstract / Deep dive when the folder
-- has them; Abstract opens the paper's entry on the Research page.
local function card(ref, extra, position, total)
  local id = text(ref.id)
  local folder = text(extra.folder)
  assert(folder ~= '', 'Missing folder in publication-links: ' .. id)
  local summary = assert(utils.read_file(folder .. '/_selected-summary.md'),
    'Missing ' .. folder .. '/_selected-summary.md')

  local doi = text(ref.doi)
  local target = doi ~= '' and ('https://doi.org/' .. doi) or text(ref.url)
  local title = ref.title or pandoc.Inlines({})
  if target ~= '' then title = pandoc.Inlines({pandoc.Link(title, target)}) end

  local links = {}
  local function link(label, href)
    if href ~= '' then links[#links + 1] = ('<a href="%s">%s</a>'):format(escape(href), label) end
  end
  link('Paper', target)
  link('Code', text(extra.code))
  if utils.read_file(folder .. '/_abstract.md') then link('Abstract →', 'research.html?open=abstract#pub-' .. id) end
  if utils.read_file(folder .. '/article-page.qmd') then link('Deep dive →', folder .. '/article-page.html') end

  return table.concat({
    ('<div class="selected-paper" role="group" aria-roledescription="slide" aria-label="%d of %d">'):format(position, total),
    ('<p class="selected-paper__meta">%s · %s</p>'):format(utils.year(ref), escape(text(ref['container-title']))),
    '<h3 class="selected-paper__title">' .. html(title) .. '</h3>',
    '<p class="selected-paper__authors">' .. escape(authors(ref)) .. '</p>',
    '<div class="selected-paper__summary">' .. html(pandoc.read(summary, 'markdown').blocks) .. '</div>',
    '<p class="selected-paper__links">' .. table.concat(links, '<span aria-hidden="true"> · </span>') .. '</p>',
    '</div>',
  }, '\n')
end

-- The section around the cards. The step controls start hidden and are shown
-- by selected-research.js, so without JavaScript the row is a plain scroller.
local function section(cards)
  return table.concat({
    '<section class="selected-research" aria-roledescription="carousel" aria-labelledby="selected-research-title">',
    '<div class="selected-research__header">',
    '<h2 id="selected-research-title" class="selected-research__title">Selected papers</h2>',
    '<div class="selected-research__controls" hidden>',
    '<button type="button" class="selected-research__step" aria-label="Previous paper" disabled>‹</button>',
    ('<span class="selected-research__count" aria-live="polite">1 / %d</span>'):format(#cards),
    '<button type="button" class="selected-research__step" aria-label="Next paper">›</button>',
    '</div>',
    '</div>',
    '<div class="selected-research__track" tabindex="0" aria-label="Papers">',
    table.concat(cards, '\n'),
    '</div>',
    '</section>',
  }, '\n')
end

function Pandoc(doc)
  if not FORMAT:match('html') then return doc end

  local refs = bib_source.read_all(doc.meta.bibliography)
  local by_id = {}
  for _, ref in ipairs(refs) do by_id[text(ref.id)] = ref end

  local extras = doc.meta['publication-links'] or {}
  local selected = doc.meta['selected-publications'] or {}
  assert(#selected > 0, 'No selected-publications listed')

  local cards = {}
  for i, value in ipairs(selected) do
    local id = text(value)
    assert(by_id[id], 'Unknown selected-publications ID: ' .. id)
    cards[i] = card(by_id[id], extras[id] or {}, i, #selected)
  end

  -- The script follows the section, so its elements exist when it runs.
  local script = assert(utils.read_file('filters/selected-research.js'), 'Missing filters/selected-research.js')
  local blocks = pandoc.Blocks({
    pandoc.RawBlock('html', section(cards)),
    pandoc.RawBlock('html', '<script>\n' .. script .. '</script>'),
  })

  -- Put the section into the empty ::: {#selected-publications} div.
  local found = false
  doc = doc:walk({Div = function(div)
    if div.identifier == 'selected-publications' then
      found, div.content = true, blocks
      return div
    end
  end})
  assert(found, 'Missing #selected-publications placeholder')
  return doc
end
