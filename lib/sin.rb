# frozen_string_literal: true

require_relative "sin/version"

# :nodoc:
module Sin
  def github_issue_files
    Dir.glob("data/github/issue-*.json")
  end

  def github_issue_file(number)
    format("data/github/issue-%d.json", number)
  end

  def github_issue_comments_file(number)
    format("data/github/comments-%d.json", number)
  end

  def github_issue_log_file(number)
    format("data/log/update-log-%d.json", number)
  end

  module_function :github_issue_files
  module_function :github_issue_file
  module_function :github_issue_comments_file
  module_function :github_issue_log_file
end

require_relative "sin/adf"
require_relative "sin/user"
require_relative "sin/github"
require_relative "sin/jira"
require_relative "sin/body"
require_relative "sin/generator"
