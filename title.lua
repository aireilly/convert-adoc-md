-- title.lua
-- Make <info><title> the single H1; demote all other headings by 1 (max H6).

local stringify = pandoc.utils.stringify
local have_title_h1 = false
local title_txt = nil

return {
  Pandoc = function(doc)
    title_txt = stringify(doc.meta.title or "")
    if title_txt == "" then return doc end

    local blocks = doc.blocks
    local first = blocks[1]
    if not (first and first.t == "Header" and first.level == 1 and stringify(first.content) == title_txt) then
      table.insert(blocks, 1, pandoc.Header(1, title_txt))
    end
    have_title_h1 = true
    return pandoc.Pandoc(blocks, doc.meta)
  end,

  Header = function(h)
    -- Keep the first H1 that matches the title; demote everything else by 1.
    if h.level == 1 and stringify(h.content) == (title_txt or "") and not have_title_h1 then
      have_title_h1 = true
      return h
    end
    if h.level == 1 and stringify(h.content) == (title_txt or "") then
      -- this is the inserted/first title; keep as H1
      return h
    end
    h.level = math.min(6, h.level + 1)
    return h
  end
}
