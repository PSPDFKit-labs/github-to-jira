# frozen_string_literal: true

require "singleton"
require "octokit"

# :nodoc:
class Sin::Github
  include Singleton

  def issue(number)
    self.client.issue(self.repository, number)
  end

  def issues(state: :open)
    self.client.list_issues(self.repository, state: state.to_s)
  end

  def comments(number)
    self.client.issue_comments(self.repository, number)
  end

  def repository
    ENV.fetch("GITHUB_REPO")
  end

  def organization
    self.repository.split("/").first
  end

  def organization_members
    self.client.organization_members(self.organization)
  end

  def rate_limit
    self.client.rate_limit
  end

  def client
    @client ||= begin
      c = Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
      c.auto_paginate = true
      c
    end
  end
end
