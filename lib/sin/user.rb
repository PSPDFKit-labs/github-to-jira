# frozen_string_literal: true

require "uri"
require "smarter_csv"
require "active_support/core_ext/object/blank"
require "singleton"

# :nodoc:
class Sin::User
  include Singleton

  def self.atlassian_id(github_login)
    self.instance.users[github_login]
  end

  # GitHub login -> Atlassian ID map.
  def users
    @users ||= begin
      csv_users = File.open("data/github-to-atlassian.csv", "r:bom|utf-8") do |f|
        SmarterCSV.process(f, { col_sep: "," })
      end

      csv_users
        .select { |x| x[:github_login].present? }
        .map { |x| [x[:github_login], x[:atlassian_id]] }
        .to_h
    end
  end
end
