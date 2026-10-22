-- APA-style citation for one publication, built as Pandoc inlines:
--   Authors (Year). Title Journal, volume(issue), pages. (Note).
--   Authors (Year). *Chapter title*. In: Book title.
local utils = dofile('filters/utils.lua')
local text = utils.text

local M = {}

-- Add a plain string or a list of inlines to the end of out.
local function append(out, value)
  if type(value) == 'string' then out:insert(pandoc.Str(value))
  else out:extend(value) end
end

-- "Family, Given" for each author, joined with ", " and ", & " before the last.
-- Organisations (literal names) are used as written. The site owner is bold.
local function authors(ref, owner)
  local out = pandoc.Inlines({})
  local people = ref.author or {}
  for i, author in ipairs(people) do
    if i > 1 then append(out, i == #people and ', & ' or ', ') end
    local family, given = text(author.family), text(author.given)
    local particle = text(author['non-dropping-particle'])
    local label = text(author.literal)
    if label == '' then
      label = (particle ~= '' and particle .. ' ' or '') .. family
      if given ~= '' then label = label .. ', ' .. given end
    end
    if family == owner.family and given == owner.given then
      out:insert(pandoc.Strong({pandoc.Str(label)}))
    else append(out, label) end
  end
  return out
end

function M.build(ref, source, owner)
  local kind = text(ref.type)
  local out = authors(ref, owner)
  local year = utils.year(ref)
  append(out, ' (' .. (year == 0 and 'n.d.' or year) .. '). ')

  -- The title links to the DOI, or to the URL when there is no DOI. Chapter titles are italic.
  local doi, url = text(ref.doi), text(ref.url)
  local target = doi ~= '' and ('https://doi.org/' .. doi) or url
  local title = ref.title or pandoc.Inlines({})
  if kind == 'chapter' then title = pandoc.Inlines({pandoc.Emph(title)}) end
  if target ~= '' then out:insert(pandoc.Link(title, target))
  else out:extend(title) end

  local container = ref['container-title'] or pandoc.Inlines({})
  if kind == 'chapter' then
    -- "... Title. In: Book title"
    if not text(title):match('[.!?]$') then append(out, '.') end
    append(out, ' In: ')
    out:extend(container)
  else
    -- "... Title *Journal*, 24(3), 52-72"; an eid (article number) replaces the pages.
    if #container > 0 then
      append(out, ' ')
      out:insert(pandoc.Emph(container))
    end
    local volume, issue = text(ref.volume), text(ref.issue)
    local locator = source.eid or text(ref.page)
    if volume ~= '' then append(out, ', ' .. volume) end
    if issue ~= '' then append(out, '(' .. issue .. ')') end
    if locator ~= '' then append(out, ', ' .. locator) end
  end

  if not text(out):match('[.!?]$') then append(out, '.') end
  if ref.note then append(out, ' (' .. text(ref.note) .. ').') end
  return out
end

return M
