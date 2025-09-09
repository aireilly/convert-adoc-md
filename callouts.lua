-- callouts.lua
-- Requires preprocessing with asciidoctor -r ./prepare.rb
-- For any CodeBlock immediately followed by a BulletList:
-- - replaces lines like "  # pre-1" with "  # <bullet text>"
-- - using bullets in order (1-based), preserving original indentation

local stringify = (require "pandoc.utils").stringify

-- Replace "# pre-N" lines with "# <bullet[N]>" (preserves indent).
local function apply_bullets_to_code(code, bullets)
  local out = {}
  for line in (code .. "\n"):gmatch("([^\n]*)\n") do
    local indent, n = line:match("^([ \t]*)#%s*pre%-(%d+)%s*$")
    if indent and n then
      local idx = tonumber(n)
      local txt = bullets[idx]
      if txt and txt ~= "" then
        table.insert(out, indent .. "# " .. txt)
      else
        -- No corresponding bullet; keep original placeholder
        table.insert(out, line)
      end
    else
      table.insert(out, line)
    end
  end
  return table.concat(out, "\n")
end

-- Extract plain text for each bullet list item.
local function bullets_from_list(bl)
  local bullets = {}
  for _, itemBlocks in ipairs(bl.content) do
    -- itemBlocks is a list of Blocks; stringify a Div wrapper to flatten
    local txt = stringify(pandoc.Div(itemBlocks))
    txt = (txt:gsub("%s+$",""))
    table.insert(bullets, txt)
  end
  return bullets
end

-- Process a list of Blocks in-place, handling CodeBlock + following BulletList pairs.
local function process_blocks(blocks)
  local i = 1
  while i <= #blocks do
    local b = blocks[i]

    -- Recurse into containers first (so nested pairs are handled)
    if b.t == "Div" or b.t == "BlockQuote" then
      process_blocks(b.content)
    elseif b.t == "OrderedList" or b.t == "BulletList" then
      for _, item in ipairs(b.content) do
        process_blocks(item)
      end
    elseif b.t == "DefinitionList" then
      for _, def in ipairs(b.content) do
        -- def = { termInlines, listOfBlockLists }
        for _, blklist in ipairs(def[2]) do
          process_blocks(blklist)
        end
      end
    elseif b.t == "Table" then
      -- Traverse table cells
      local tbl = b
      if tbl.bodies then
        for _, body in ipairs(tbl.bodies) do
          for _, row in ipairs(body.body) do
            for _, cell in ipairs(row) do
              process_blocks(cell.contents)
            end
          end
        end
      end
      if tbl.foot then
        for _, row in ipairs(tbl.foot) do
          for _, cell in ipairs(row) do
            process_blocks(cell.contents)
          end
        end
      end
      if tbl.head then
        for _, row in ipairs(tbl.head) do
          for _, cell in ipairs(row) do
            process_blocks(cell.contents)
          end
        end
      end
    end

    -- If a CodeBlock is immediately followed by a BulletList, merge.
    if b.t == "CodeBlock" and blocks[i + 1] and blocks[i + 1].t == "BulletList" then
      local bullets = bullets_from_list(blocks[i + 1])
      b.text = apply_bullets_to_code(b.text, bullets)
      -- Remove the BulletList we just consumed
      table.remove(blocks, i + 1)
      -- Keep i at this CodeBlock to allow back-to-back merges if needed
    else
      i = i + 1
    end
  end
end

function Pandoc(doc)
  process_blocks(doc.blocks)
  return doc
end
