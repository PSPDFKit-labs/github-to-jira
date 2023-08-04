# frozen_string_literal: true

require "active_support/core_ext/object/blank"

# This is being used by the `exe/2-json-for-import` generator to
# generate the JSON issue for the importer (it's a different JSON than
# the one we need for REST API).
class Sin::Generator
  attr_reader :project_key
  attr_reader :issue
  attr_reader :comments

  def initialize(project_key, issue, comments)
    @project_key = project_key
    @issue = issue
    @comments = comments
  end

  def automation_for_jira_user_id
    ENV.fetch("AUTOMATION_FOR_JIRA_USER_ID")
  end

  def assignee
    Sin::User.atlassian_id(self.issue.dig("assignee", "login"))
  end

  def reporter
    Sin::User.atlassian_id(self.issue.dig("user", "login")) || self.automation_for_jira_user_id
  end

  def status
    (self.issue["state"] == "open") ? "Open" : "Closed"
  end

  def resolution
    unless self.issue["state"] == "open"
      "Resolved"
    end
  end

  def labels
    (self.issue["labels"] || [])
      .map { |x| x["name"].downcase.gsub(" ", "-") }
      .compact
      .presence
  end

  def to_jira
    comments_value = self.comments.map do |comment|
      id = comment["id"]
      {
        author: Sin::User.atlassian_id(comment.dig("user", "login")) || self.automation_for_jira_user_id,
        created: Time.parse(comment["created_at"]).utc.iso8601,
        externalId: id,
        body: "GHCID:#{id}"
      }
    end

    {
      externalId: self.issue["number"],
      key: "#{self.project_key}-#{self.issue['number']}",
      created: Time.parse(self.issue["created_at"]).utc.iso8601,
      updated: Time.parse(self.issue["updated_at"]).utc.iso8601,
      summary: self.issue["title"],
      reporter: self.reporter,
      assignee: self.assignee,
      issueType: "GitHub Issue",
      status: self.status,
      resolution: self.resolution,
      labels: self.labels,
      customFieldValues: [
        {
          fieldName: "GitHub URL",
          fieldType: "com.atlassian.jira.plugin.system.customfieldtypes:url",
          value: self.issue["html_url"]
        }
      ],
      comments: comments_value
    }.compact
  end
end
