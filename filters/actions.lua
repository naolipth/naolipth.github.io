-- Button row under each citation and the roll-down panels it controls.
-- Order: Abstract, Summary, Deep dive, Paper, Code, BibTeX. Each appears only
-- when its content exists. publications.js opens and closes the panels.
local utils = dofile('filters/utils.lua')
local text, escape = utils.text, utils.escape

local M = {}

-- id is the publication's HTML id (pub-<BibTeX ID>); extra is its entry in
-- publication-links; source is its raw BibTeX from bib-source.lua.
function M.build(id, ref, extra, source)
  local buttons, panels = {}, pandoc.Blocks({})

  -- A button that opens another page. Skipped when there is no target.
  local function link(label, target)
    if target == '' then return end
    buttons[#buttons + 1] = ('<a class="publication__button" href="%s">%s</a>'):format(escape(target), label)
  end

  -- A button that rolls down a hidden panel below the row.
  local function panel(label, name, content)
    local panel_id = id .. '-' .. name
    buttons[#buttons + 1] = ('<button type="button" class="publication__button publication__toggle"'
      .. ' aria-expanded="false" aria-controls="%s">%s</button>'):format(panel_id, label)
    panels:insert(pandoc.Div(content, pandoc.Attr(panel_id, {'publication__panel'}, {hidden = ''})))
  end

  -- Optional research folder: _abstract.md and _summary.md become panels,
  -- article-page.qmd a deep-dive page. The underscores stop Quarto from
  -- rendering the two snippets as pages of their own.
  local folder = text(extra.folder)
  if folder ~= '' then
    local abstract = utils.read_file(folder .. '/_abstract.md')
    local non_technical_summary = utils.read_file(folder .. '/_non-technical.md')
    local deep_dive = utils.read_file(folder .. '/article-page.qmd')
    assert(abstract or non_technical_summary or deep_dive, 'No research files found in ' .. folder)
    if abstract then panel('Abstract', 'abstract', pandoc.read(abstract, 'markdown').blocks) end
    if non_technical_summary then panel('Non-technical', 'non_technical_summary', pandoc.read(non_technical_summary, 'markdown').blocks) end
    if deep_dive then link('Deep dive →', folder .. '/article-page.html') end
  end

  -- The title already links to the DOI, so Paper only appears when there is a URL as well.
  if text(ref.doi) ~= '' then link('Paper', text(ref.url)) end
  link('Code', text(extra.code))

  -- Original BibTeX as raw HTML, so Quarto does not turn it into a highlighted code block.
  panel('BibTeX', 'bibtex', {pandoc.RawBlock('html',
    '<button type="button" class="publication__copy">Copy</button>'
    .. '<pre class="publication__bibtex"><code>' .. escape(source.raw) .. '</code></pre>')})

  local blocks = pandoc.Blocks({pandoc.RawBlock('html',
    '<div class="publication__actions">' .. table.concat(buttons) .. '</div>')})
  blocks:extend(panels)
  return blocks
end

return M
