# frozen_string_literal: true

# :nodoc:
module Sin::Adf
  def self.schema
    @schema ||= JSON.parse(File.read("adf-schema.json"))
  end
end

require_relative "adf/node"
