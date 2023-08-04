# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "kramdown"
require "kramdown-parser-gfm"
require "json-schema"

# This crazy thing:
#
# - Parses GitHub issue body to AST
# - Traverses the AST
# - Generates Atlassian Document Format
#
# It is far from perfect. There're issues on both sides.
# Not perfect AST, no everything is supported in ADF.
class Sin::Body
  TYPOGRAPHIC_SYMBOLS = {
    hellip: "…",
    mdash: "—",
    ndash: "–",
    laquo: "«",
    raquo: "»",
    laquo_space: "« ",
    raquo_space: " »"
  }.freeze

  SMART_QUOTES = {
    lsquo: "'",
    rsquo: "'",
    ldquo: "\"",
    rdquo: "\""
  }.freeze

  attr_reader :body

  def initialize(body)
    @body = body
  end

  # Generates new ADF marks (= styling).
  def update_adf_marks(ast_node, *marks)
    mark = case ast_node.type
    when :strong
      { type: :strong }
    when :em
      { type: :em }
    when :codespan
      { type: :code }
    when :html_element
      if %w[sub sup].include?(ast_node.value)
        { type: :subsup, attrs: { type: ast_node.value } }
      end
    when :a
      { type: :link, attrs: { href: ast_node.attr["href"] } }
    end

    if mark
      if mark[:type] == :code
        # Can be combined with link only
        m = marks.select { |x| x[:type] == :link }
        m + [mark]
      else
        marks + [mark]
      end
    else
      marks
    end
  end

  def visit_ast_node_children(adf_node, ast_node, *marks)
    ast_node.children.inject(adf_node) do |acc, child|
      self.ast_to_adf(acc, child, *marks)
    end
  end

  # Main crazy thing, AST traverser.:w
  def ast_to_adf(adf_node, ast_node, *marks)
    updated_marks = self.update_adf_marks(ast_node, *marks)

    case ast_node.type
    when :root
      self.visit_ast_node_children(adf_node, ast_node, *updated_marks)
    when :strong, :em
      self.visit_ast_node_children(adf_node, ast_node, *updated_marks)
    when :header
      if adf_node.type == "listItem"
        self.visit_ast_node_children(adf_node.paragraph, ast_node, *updated_marks).parent
      else
        self.visit_ast_node_children(adf_node.heading(ast_node.options[:level]), ast_node, *updated_marks)
          .parent
      end
    when :p
      if %w[codeBlock paragraph bulletList].include?(adf_node.type)
        adf_node = adf_node.parent
        self.visit_ast_node_children(adf_node.paragraph, ast_node, *updated_marks)
      else
        self.visit_ast_node_children(adf_node.paragraph, ast_node, *updated_marks)
          .parent
      end
    when :br
      adf_node.hard_break
    when :ul
      if %w[blockquote].include?(adf_node.type)
        adf_node = adf_node.paragraph.text("Bullet list below was quoted:").parent.parent
        ul = self.visit_ast_node_children(adf_node.bullet_list, ast_node, *updated_marks)
        if ul.blank?
          ul.parent.pop
        end
        ul
      elsif %w[paragraph].include?(adf_node.type)
        if adf_node.blank?
          adf_node.parent.pop
        end
        adf_node = adf_node.parent
        ul = self.visit_ast_node_children(adf_node.bullet_list, ast_node, *updated_marks)
        if ul.blank?
          ul.parent.pop
        end
        ul
      else
        if %w[listItem].include?(adf_node.type) && adf_node.blank?
          adf_node.paragraph.text("Dummy text to make Jira happy").parent
        end

        ul = self.visit_ast_node_children(adf_node.bullet_list, ast_node, *updated_marks)
        if ul.blank?
          ul.parent.pop
        end
        ul.parent
      end
    when :ol
      # start = if (s = ast_node.options[:first_list_marker])
      #   Integer(s.delete("^0-9"), exception: false)
      # end
      #
      # Ignore, this might be causing the issues?
      start = nil
      if adf_node.type == "blockquote"
        adf_node = adf_node.parent
        self.visit_ast_node_children(adf_node.ordered_list(start), ast_node, *updated_marks)
      else
        self.visit_ast_node_children(adf_node.ordered_list(start), ast_node, *updated_marks)
          .parent
      end
    when :li
      li = self.visit_ast_node_children(adf_node.list_item, ast_node, *updated_marks)
      if li.blank?
        li.parent.pop
      end
      li.parent
    when :codeblock
      if ast_node.value.strip.present?
        if adf_node.type == "blockquote"
          adf_node = adf_node.paragraph.text("Code block below was quoted:").parent.parent
          adf_node.code_block(ast_node.options[:lang])
            .text(ast_node.value.strip)
        elsif adf_node.type == "paragraph"
          adf_node = adf_node.parent
          adf_node.code_block(ast_node.options[:lang])
            .text(ast_node.value.strip)
        else
          adf_node.code_block(ast_node.options[:lang])
            .text(ast_node.value.strip)
            .parent
        end
      else
        adf_node
      end
    when :blockquote
      if %w[listItem blockquote].include?(adf_node.type)
        self.visit_ast_node_children(adf_node, ast_node, *updated_marks)
      else
        bq = self.visit_ast_node_children(adf_node.blockquote, ast_node, *updated_marks)
        if bq.blank?
          bq.parent.pop
        end
        bq.parent
      end
    when :typographic_sym
      adf_node.text(TYPOGRAPHIC_SYMBOLS[ast_node.value] || raise, *updated_marks)
    when :html_element
      # Not everything is represented as AST nodes

      if %w[sub sup].include?(ast_node.value)
        # Marks already created, just traverse children and generate ADF blocks
        self.visit_ast_node_children(adf_node, ast_node, *updated_marks)
      elsif ast_node.value == "img"
        link_marks = updated_marks + [
          {
            type: :link,
            attrs: {
              href: ast_node.attr["src"]
            }
          }
        ]
        adf_node
          .text(ast_node.attr["alt"] || ast_node.attr["src"], *link_marks)
      elsif ast_node.value == "input"
        # Task in GitHub markup? Should we do something with it?
        adf_node
      elsif ast_node.value == "details"
        # This one is tricky. AST is ...
        # :html_element (details)
        #   - :html_element (summary)
        #     - :text (title)
        #   - :text (where value is RAW markdown)
        children = ast_node.children

        # Try to find <summary>
        summary_idx = children.index do |el|
          el.value == "summary"
        end

        if summary_idx
          # Found, generate title by iterating over all :text
          # children, get the values and join them.
          #
          # JIRA supports just text in the title.
          summary_el = children[summary_idx]
          title = summary_el
            .children
            .select { |el| el.type == :text }
            .map(&:value)
            .join

          # Find the first :text after :summary
          value = children[summary_idx + 1..].find do |el|
            el.type == :text && el.value.present?
          end&.value

          value ||= begin
            html_el = children[summary_idx + 1..].find do |el|
              el.type == :html_element
            end
            html_el
              .children
              .select { |el| el.type == :text && el.value.present? }
              .map(&:value)
              .join
          end

          value = value.gsub(/^(\#{1,6} .*)$/, "\r\n\\1\r\n")
                    .gsub(/^---$/, "\r\n---\r\n")
                    .gsub(/^(\*\*.*\*\*)$/, "\r\n\\1\r\n")

          # Parse the value like a completely new Markdown document
          text_el_root = Kramdown::Document.new(value, input: "GFM", smart_quotes: %w[apos apos quot quot]).root
          doc = self.ast_to_adf(Sin::Adf::Node.doc, text_el_root)

          # Create expand node and replace the content with the previously
          # parsed Markdown document content
          node = adf_node.expand(title)
          node.content = doc.content

          if node.content.blank?
            node.parent.pop
          end
          node.parent
        else
          # No summary, ignore
          adf_node
        end
      else
        # Ignore other HTML elements
        adf_node
      end
    when :a
      self.visit_ast_node_children(adf_node, ast_node, *updated_marks)
    when :codespan
      node = adf_node.text(ast_node.value, *updated_marks)
      color = if /^#[a-zA-Z0-9]{6}$/ =~ ast_node.value
        ast_node.value
      elsif /^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$/ =~ ast_node.value
        r = format("%.2x", (::Regexp.last_match(1).to_i % 255))
        g = format("%.2x", (::Regexp.last_match(2).to_i % 255))
        b = format("%.2x", (::Regexp.last_match(3).to_i % 255))
        "##{r}#{g}#{b}"
      elsif /^hsl\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)$/ =~ ast_node.value
        h = ::Regexp.last_match(1).to_i
        s = ::Regexp.last_match(2).to_i / 100.0
        l = ::Regexp.last_match(3).to_i / 100.0
        c = (1 - (2 * l - 1).abs) * s
        h2 = h / 60.0
        x = c * (1 - (h2 % 2 - 1).abs)
        r1, g1, b1 = if h2 <= 1.0
          [c, x, 0]
        elsif h2 <= 2.0
          [x, c, 0]
        elsif h2 <= 3.0
          [0, c, x]
        elsif h2 <= 4.0
          [0, x, c]
        elsif h2 <= 5.0
          [x, 0, c]
        else
          [c, 0, x]
        end
        m = l - c / 2.0
        color = "#" + [r1, g1, b1].map do |component|
          format("%.2x", ((component + m) * 255).to_i % 255)
        end.join("")
      end
      if /^\#[0-9a-fA-F]{6}$/ =~ color
        # textColor is not supported with link and/or code, remove them
        # and simulate what GitHub does
        color_marks = updated_marks
          .reject { |mark| %i[link code].include?(mark[:type]) }
        node.text(" ●", *color_marks, { type: :textColor, attrs: { color: color } })
      else
        node
      end
    when :smart_quote
      adf_node.text(SMART_QUOTES[ast_node.value], *updated_marks)
    when :text
      if ast_node.value == "\n" || ast_node.value.blank?
        adf_node
      elsif %w[*** ---].include?(ast_node.value)
        adf_node.rule
      else
        adf_node.text(ast_node.value, *updated_marks)
      end
    when :blank
      adf_node
    when :footnote
      # Custom hack, JIRA does not support

      name = ast_node.options[:name]

      footnote_marks = [
        {
          type: :textColor,
          attrs: {
            color: "#777777"
          }
        }
      ]

      # Create fake document and inject customer footnote there
      root = Sin::Adf::Node.doc
        .paragraph
        .text("Foonote #{name}:")
        .parent

      root = self.visit_ast_node_children(root, ast_node.value, *footnote_marks)

      # Inject the footnote into the ADF root node
      adf_node.root.footnotes << root

      # Create in-document footnote (this <sup>name</sup> thing)
      indoc_footnote_marks = updated_marks + [
        {
          type: :subsup,
          attrs: {
            type: :sup
          }
        }
      ]
      adf_node.text("#{name})", *indoc_footnote_marks)
    when :img
      link_marks = updated_marks + [
        {
          type: :link,
          attrs: {
            href: ast_node.attr["src"]
          }
        }
      ]
      text = "Image link: " + (ast_node.attr["alt"] || ast_node.attr["src"])
      adf_node
        .text(text, *link_marks)
    else
      # Ignore unsupported AST node, raise if you'd like to catch them
      adf_node
    end
  end

  def to_jira(ghcid: nil)
    return if self.body.blank?

    # Limit is 32_767 characters https://jira.atlassian.com/browse/JRACLOUD-64351
    #
    # Who wrote a comment like this does not deserve better handling ;)
    doc = if self.body.length >= 30_000
            marks = [
              {
                type: :textColor,
                attrs: {
                  color: "#FF0000"
                }
              }
            ]

            Sin::Adf::Node.doc
              .paragraph
              .text("Open the original GitHub issue. Body is too big.", *marks)
              .parent
          else
            # I've initially started adding "hacks" to the
            # `#ast_to_adf` method.  It became unreadable, decided to
            # keep them, and just pre-process the Markdown (= add more
            # hacks) here to make it compatible with Jira ADF. Jira
            # simply does not like block-quoted things, etc.
            b = self.body
                  .gsub(/^(\#{1,6} .*)$/, "\r\n\\1\r\n")
                  .gsub(/^---$/, "\r\n---\r\n")
                  .gsub(/^(\*\*.*\*\*)$/, "\r\n\\1\r\n")
                  .gsub(/^([>-])\s*(\d+)\.\s+(.*)$/, "\\1 \\2 \\3")
                  .gsub(/^>\s*\#+\s+(.*)$/, "> \\1")
                  .gsub(/^>\s+(.*)$/, "> \\1")
                  .gsub(/^([-*]) [-*] (.*)$/, "    \\1 \\2")

            root = Kramdown::Document.new(b, input: "GFM", smart_quotes: %w[apos apos quot quot]).root
            self.ast_to_adf(Sin::Adf::Node.doc, root)
          end

    if ghcid
      marks = [
        {
          type: :textColor,
          attrs: {
            color: "#AAAAAA"
          }
        }
      ]

      doc = doc.paragraph.text("(ignore GHCID:#{ghcid})", *marks).parent
    end

    # Comment out this return if you'd like to validate locally
    # against the schema. Be warned, schema says it's ok, but you can
    # still get 400.
    return doc.to_adf

    adf = doc.to_adf
    begin
      JSON::Validator.validate!(Sin::Adf.schema, adf)
    rescue JSON::Schema::ValidationError
      adf[:content].each_with_index do |node, idx|
        puts "--------------------------------"
        puts "#/content/#{idx}"
        puts JSON.pretty_generate(node)
        puts "--------------------------------"
      end
      raise
    end
    adf
  end
end
