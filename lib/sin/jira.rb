# frozen_string_literal: true

require "singleton"
require "jira-ruby"

# :nodoc:
class Sin::Jira
  include Singleton

  def create_issue(attrs)
    i = self.client.Issue.build
    i.save!(attrs)
    i.fetch
    i
  end

  def project_id
    self.project.id
  end

  def project
    @project ||= self.client.Project.find(self.project_key)
  end

  def issue(key)
    self.client.Issue.find(key)
  end

  def update_issue(key, attrs)
    issue = self.client.Issue.find(key)
    issue.save!(attrs)
    issue
  end

  def project_key
    ENV.fetch("JIRA_PROJECT", "ARCHIVE")
  end

  def client
    @client ||= begin
                  opts = {
                    site: "http://#{ENV.fetch("JIRA_HOST")}:443",
                    username: ENV.fetch("JIRA_USERNAME"),
                    password: ENV.fetch("JIRA_TOKEN"),
                    auth_type: :basic,
                    context_path: "",
                    rest_base_path: "/rest/api/3"
                  }

                  if ENV["PROXY_ADDRESS"].present?
                    yao = {
                      proxy_address: ENV["PROXY_ADDRESS"],
                      proxy_port: ENV["PROXY_PORT"],
                      ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
                    }
                    opts.merge!(yao)
                  end

                  JIRA::Client.new(opts)
                end
  end
end
