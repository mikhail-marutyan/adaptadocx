-- resolve logo path relative to this filter file
local script_dir = pandoc.path.directory(debug.getinfo(1).source:sub(2))
local logo_file = pandoc.path.join{script_dir, "..", "assets", "logo.png"}
-- titles will be read from metadata files

local function pagebreak()
  return pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
end

function Pandoc(doc)
  if FORMAT ~= 'docx' then return doc end
  -- remove automatic date inserted by Asciidoctor
  doc.meta.date = nil
  local blocks = {}
  local fh = io.open(logo_file, 'rb')
  if fh then
    pandoc.mediabag.insert(logo_file, 'image/png', fh:read('*all'))
    fh:close()
    local img = pandoc.Image({pandoc.Str('')}, logo_file)
    img.attr = pandoc.Attr('', {}, {['custom-style']='CoverImage'})
    table.insert(blocks, pandoc.Para{img})
  end
  local lang  = doc.meta.lang and pandoc.utils.stringify(doc.meta.lang) or 'en'
  
  local doc_title = doc.meta.title and pandoc.utils.stringify(doc.meta.title) or nil
  
  -- Use the title from metadata, fallback to document title, then default
  local title = doc_title or 'Documentation'
  
  -- Ensure we have the full localized title
  if lang == 'ru' and title == 'Adaptadocx' then
    title = 'Документация Adaptadocx'
  elseif lang == 'en' and title == 'Adaptadocx' then
    title = 'Adaptadocx Documentation'
  end
  local version = doc.meta.version or doc.meta.revnumber or ''
  table.insert(blocks, pandoc.Div({pandoc.Para{pandoc.Str(title)}}, pandoc.Attr('', {}, {['custom-style']='CoverTitle'})))
  if version ~= '' then
    table.insert(blocks, pandoc.Div({pandoc.Para{pandoc.Str(pandoc.utils.stringify(version))}}, pandoc.Attr('', {}, {['custom-style']='CoverSub'})))
  end
  table.insert(blocks, pagebreak())
  -- Table of contents heading and field
  local toc_title = doc.meta["toc-title"] and pandoc.utils.stringify(doc.meta["toc-title"]) or "Table of Contents"
  table.insert(blocks, pandoc.RawBlock('openxml',
    '<w:p><w:pPr><w:pStyle w:val="TOCHeading"/></w:pPr><w:r><w:t xml:space="preserve">'..toc_title..'</w:t></w:r></w:p>'))
  table.insert(blocks, pandoc.RawBlock('openxml',
    '<w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/><w:instrText xml:space="preserve">TOC \\o \\"1-3\\" \\h \\z \\u</w:instrText><w:fldChar w:fldCharType="separate"/><w:fldChar w:fldCharType="end"/></w:r></w:p>'))
  table.insert(blocks, pagebreak())
  local title_content = pandoc.utils.stringify(doc.meta.title or '')
  local subtitle_content = pandoc.utils.stringify(doc.meta.subtitle or '')
  local body = pandoc.List()
  for _, blk in ipairs(doc.blocks) do
    if blk.t == 'Para' then
      local text = pandoc.utils.stringify(blk)
      if text ~= title_content and text ~= subtitle_content and text ~= pandoc.utils.stringify(version) then
        body:insert(#body+1, blk)
      end
    else
      body:insert(#body+1, blk)
    end
  end
  local newblocks = pandoc.List()
  for i=1,#blocks do newblocks:insert(i, blocks[i]) end
  for i=1,#body do newblocks:insert(#newblocks+1, body[i]) end
  doc.meta.title, doc.meta.subtitle = nil, nil
  return pandoc.Pandoc(newblocks, doc.meta)
end
