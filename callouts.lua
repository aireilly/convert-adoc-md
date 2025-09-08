-- callouts.lua
-- DocBook <programlisting> with inline <co .../> markers + following <calloutlist>
-- → insert callout text as *preceding* comment lines inside the code block.
-- Multiline callouts (paras, bullet lists) are preserved.
-- No numbering; supports literal and HTML-escaped <co/>.

local stringify = pandoc.utils.stringify

-- Comment prefix by language (all comments are inserted on their own lines)
local comment_prefix = {
  yaml   = "# ",  yml   = "# ",  toml  = "# ",  ini   = "; ", conf  = "# ",
  sh     = "# ",  bash  = "# ",  zsh   = "# ",  fish  = "# ",  make  = "# ",
  py     = "# ",  rb    = "# ",  r     = "# ",  ps1   = "# ",  docker= "# ",
  js     = "// ", ts    = "// ", c     = "// ",  cpp   = "// ", go    = "// ",
  rust   = "// ", php   = "// ", lua   = "-- ", sql   = "-- ",
  erl    = "% ",  elixir= "# ",  clj   = ";; ", lisp  = ";; ", scheme= ";; ",
  tex    = "%% ",
  html   = "<!-- ", xml  = "<!-- ",
}

local function prefix_for(lang) return comment_prefix[(lang or ""):lower()] or "# " end
local function is_block_comment(lang)
  lang = (lang or ""):lower()
  return (lang == "html" or lang == "xml")
end

-- ---------- helpers

local function split_lines(s)
  local out = {}
  s = (s or ""):gsub("\r\n", "\n")
  for line in (s.."\n"):gmatch("([^\n]*)\n") do out[#out+1] = line end
  return out
end

local function blocks_to_lines(blocks)
  local lines = {}
  local function add_text(txt)
    for _, l in ipairs(split_lines(txt)) do lines[#lines+1] = l end
  end

  for _, bl in ipairs(blocks) do
    if bl.t == "BulletList" then
      for _, itemBlocks in ipairs(bl.content) do
        -- render each list item as "- ..." with wrapped lines indented
        local txt = stringify(pandoc.Div(itemBlocks))
        local ls = split_lines(txt)
        for i, l in ipairs(ls) do
          if l ~= "" then
            lines[#lines+1] = (i == 1) and ("- " .. l) or ("  " .. l)
          end
        end
      end
    elseif bl.t == "OrderedList" then
      local _, items = table.unpack(bl.content)
      local n = 1
      for _, itemBlocks in ipairs(items) do
        local txt = stringify(pandoc.Div(itemBlocks))
        local ls = split_lines(txt)
        for i, l in ipairs(ls) do
          if l ~= "" then
            lines[#lines+1] = (i == 1) and (tostring(n) .. ". " .. l) or ("   " .. l)
          end
        end
        n = n + 1
      end
    elseif bl.t == "CodeBlock" then
      add_text(bl.text)
    else
      add_text(stringify(bl))
    end
  end
  return lines
end

local function collect_callouts(listBlock)
  local texts = {}
  if listBlock.t == "BulletList" then
    for _, itemBlocks in ipairs(listBlock.content) do
      texts[#texts+1] = blocks_to_lines(itemBlocks)
    end
  elseif listBlock.t == "OrderedList" then
    local _, items = table.unpack(listBlock.content)
    for _, itemBlocks in ipairs(items) do
      texts[#texts+1] = blocks_to_lines(itemBlocks)
    end
  end
  return texts
end

-- Strip one <co .../> or &lt;co .../&gt; from a line
local function strip_one_marker(line)
  local s,e = line:find("<%s*co%s+[^/>]-%s*/%s*>")
  if s then return line:sub(1,s-1)..line:sub(e+1), true end
  s,e = line:find("&lt;%s*co[^&]-/%s*&gt;")
  if s then return line:sub(1,s-1)..line:sub(e+1), true end
  return line, false
end

-- ---------- core

local function apply_markers(code, callouts, lang)
  local lines = split_lines(code)
  local pfx = prefix_for(lang)
  local blockc = is_block_comment(lang)
  local idx, total_hits = 1, 0

  for i = 1, #lines do
    local original = lines[i]
    local line, hits = original, 0
    while true do
      local new, found = strip_one_marker(line)
      if not found then break end
      line, hits = new, hits + 1
    end
    if hits > 0 then
      total_hits = total_hits + hits
      -- determine indentation from the target line
      local indent = original:match("^%s*") or ""
      -- insert one callout (possibly multiline) per hit, above target
      for _ = 1, hits do
        local clines = callouts[idx] or {""}
        if blockc then
          -- HTML/XML block comment wrapper
          table.insert(lines, i, indent .. "<!-- " .. (table.concat(clines, "\n" .. indent)) .. " -->")
        else
          for k = #clines, 1, -1 do
            table.insert(lines, i, indent .. pfx .. clines[k])
          end
        end
        idx = idx + 1
      end
      lines[i + hits] = line -- shift the cleaned target line below the inserted comments
      i = i + hits
    else
      lines[i] = original
    end
  end

  -- Fallback: no markers, exactly one callout → put it above the last non-empty line
  if total_hits == 0 and #callouts == 1 then
    local last = #lines
    while last > 0 and lines[last]:match("^%s*$") do last = last - 1 end
    local indent = (last > 0 and (lines[last]:match("^%s*") or "")) or ""
    local clines = callouts[1]
    if blockc then
      table.insert(lines, math.max(last,1), indent .. "<!-- " .. (table.concat(clines, "\n" .. indent)) .. " -->")
    else
      for k = #clines, 1, -1 do
        table.insert(lines, math.max(last,1), indent .. pfx .. clines[k])
      end
    end
  end

  return table.concat(lines, "\n")
end

return {
  Pandoc = function(doc)
    local bs, out, i = doc.blocks, {}, 1
    while i <= #bs do
      local b, nxt = bs[i], bs[i+1]
      if b.t == "CodeBlock" and nxt and (nxt.t == "BulletList" or nxt.t == "OrderedList") then
        local callouts = collect_callouts(nxt)  -- array of {lines}
        local lang = (b.attr and b.attr.classes and b.attr.classes[1]) or nil
        local updated = apply_markers(b.text or "", callouts, lang)
        out[#out+1] = pandoc.CodeBlock(updated, b.attr)
        i = i + 2 -- drop the callout list
      else
        out[#out+1] = b
        i = i + 1
      end
    end
    return pandoc.Pandoc(out, doc.meta)
  end
}
