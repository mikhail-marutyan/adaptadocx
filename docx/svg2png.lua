-- svg2png.lua : replace *.svg with *.png for DOCX
function Image (img)
  if FORMAT == "docx" and img.src:match("%.svg$") then
    local png = img.src:gsub("%.svg$", ".png")
    os.execute(string.format("rsvg-convert %s -o %s", img.src, png))
    img.src = png
  end
  return img
end
