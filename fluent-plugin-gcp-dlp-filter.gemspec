# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-gcp-dlp-filter"
  spec.version       = "0.0.6"
  spec.description   = 'Fluentd filter plugin for GCP Data Loss Prevention API'
  spec.authors       = ["salrashid123"]
  spec.email         = ["salrashid123@gmail.com"]
  spec.summary       = %q{Fluentd filter plugin to sanitize/clean logs Google CLoud Data Loss Prevention API}
  spec.homepage      = "https://github.com/salrashid123/fluent-plugin-gcp-dlp-filter"
  spec.license       = "Apache License, Version 2.0"

  spec.files       = ["lib/fluent/plugin/filter_gcp_dlp.rb"]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "test-unit"
  spec.add_runtime_dependency 'google-cloud-dlp', ['>= 0.8.0']
  spec.add_runtime_dependency "fluentd", ['>= 0.14.0']
end