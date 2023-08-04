# frozen_string_literal: true

# Atlassian Document Format
#
# https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
#
# Notes:
#
# - Some nodes are top-level only
# - Some nodes are inline only (nested in top-level ones)
# - That's the reason for many .parent (read close) calls in the transformer
# - Not everything is allowed (e.g. textColor mark with code & link marks)
class Sin::Adf::Node
  attr_reader :parent
  attr_reader :type
  # Keep it writable so that we can easily replace content
  # in case of details & summary -> expand hack.
  attr_accessor :content
  attr_reader :opts
  attr_reader :footnotes

  def initialize(parent, type, opts = nil)
    @content = []
    @opts = opts
    @parent = parent
    @type = type
    @footnotes = []
  end

  def self.doc
    self.new(nil, "doc", { version: 1 })
  end

  def paragraph
    self.add_node("paragraph")
  end

  def blockquote
    self.add_node("blockquote")
  end

  def bullet_list
    self.add_node("bulletList")
  end

  def code_block(lang = nil)
    opts = if lang.present?
      {
        attrs: {
          language: lang
        }
      }
    end
    self.add_node("codeBlock", opts)
  end

  def heading(level)
    opts = {
      attrs: {
        level: level
      }
    }
    self.add_node("heading", opts)
  end

  def ordered_list(start = nil)
    opts = if start
      {
        attrs: {
          order: start
        }
      }
    end
    self.add_node("orderedList", opts)
  end

  def root
    root = self
    loop do
      if root.parent.nil?
        break root
      end

      root = root.parent
    end
  end

  def panel(type)
    opts = {
      attrs: {
        panelType: type
      }
    }
    self.add_node("panel", opts)
  end

  def list_item
    self.add_node("listItem")
  end

  def rule
    self.add_node("rule").parent
  end

  def text(text, *marks)
    opts = { text: text }
    if marks.present?
      opts[:marks] = *marks
    end

    self.add_inline_node("text", opts)
  end

  def expand(title)
    opts = {
      attrs: {
        title: title
      }
    }
    self.add_node("expand", opts)
  end

  def hard_break
    self.add_inline_node("hardBreak")
  end

  def to_adf
    self.parent&.to_adf || self.as_json
  end

  def as_json
    base = { type: self.type }.merge(self.opts || {})

    if self.content.present?
      base[:content] = self.content.map(&:as_json)
    end

    if self.footnotes.present?
      base[:content] ||= []
      base[:content] << self.class.new(nil, "rule").as_json

      self.footnotes.map(&:as_json).each do |root|
        base[:content].concat(root[:content])
      end
    end

    base
  end

  def blank?
    self.content.blank?
  end

  def pop
    self.content.pop
  end

  # Adds a new inline node and auto-closes it = returns the
  # current node.
  def add_inline_node(type, opts = nil)
    n = self.class.new(self, type, opts)
    self.content << n
    self
  end

  # Adds a new node and returns it. Do not forget to close
  # it (call parent) otherwise you'll get broken markup (better scenario)
  # or just invalid input from the API.
  def add_node(type, opts = nil)
    n = self.class.new(self, type, opts)
    self.content << n
    n
  end
end
