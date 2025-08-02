# frozen_string_literal: true

require 'asciidoctor'
require 'asciidoctor/extensions'

# Tree processor for collapsible blocks.
Asciidoctor::Extensions.register do
  tree_processor do
    process do |doc|
      doc.find_by(context: :example) do |blk|
        next unless blk.option? :collapsible
        new_block = Asciidoctor::Block.new blk.parent, :open, content_model: :compound
        new_block.title = blk.title if blk.title?
        new_block.set_attr 'role', 'collapsible'
        blk.blocks.each { |child| new_block << child }
        idx = blk.parent.blocks.index(blk)
        blk.parent.blocks[idx] = new_block
      end
      doc
    end
  end
end
