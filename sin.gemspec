# frozen_string_literal: true

require_relative "lib/sin/version"

Gem::Specification.new do |spec|
  spec.name = "sin"
  spec.version = Sin::VERSION
  spec.authors = ["Robert Vojta"]
  spec.email = ["robert@pspdfkit.com"]

  spec.summary = "Write a short summary, because RubyGems requires one."
  spec.description = "Write a longer description or delete this line."
  spec.homepage = "https://pspdfkit.com/"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/PSPDFKit-labs/github-to-jira"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", "~> 7.0"
  spec.add_dependency "faraday-retry"
  spec.add_dependency "jira-ruby"
  spec.add_dependency "kramdown"
  spec.add_dependency "kramdown-parser-gfm"
  spec.add_dependency "nokogiri", "~> 1.15"
  spec.add_dependency "octokit", "~> 6.1"
  spec.add_dependency "smarter_csv", "~> 1.8"
  spec.add_dependency "json-schema"
  
  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
