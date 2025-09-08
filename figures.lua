-- figures.lua
-- Convert Pandoc Figure blocks (from DocBook <figure>) to plain Markdown images:
--   ![alt](src "caption")

local stringify = pandoc.utils.stringify

local function first_image_in(blocks)
  local found
  pandoc.walk_block(pandoc.Div(blocks), {
    Image = function(img) if not found then found = img end; return img end
  })
  return found
end

return {
  Figure = function(fig)
    local img = first_image_in(fig.content or {})
    if not img then return nil end

    -- Caption text (Pandoc 3.x: fig.caption may be a Caption with .long)
    local cap = ""
    if fig.caption then
      if type(fig.caption) == "table" and fig.caption.long then
        cap = stringify(fig.caption.long)
      else
        cap = stringify(fig.caption)
      end
    end

    local new_img = pandoc.Image(img.caption, img.src, cap, img.attr)
    return pandoc.Para{ new_img }
  end
}
