#!/usr/bin/env ruby
# encoding: utf-8

require 'json'
require 'optparse'

OptionParser.new do |opts|
    opts.banner = "Usage: scan.features.rb [options]"

    opts.on("-s", "--src-dir PATH", "Specify gitlab source dir (required if --features-file is ommited)") do |v|
        GITLAB_FEATURES_FILE="#{File.expand_path(v)}/ee/app/models/gitlab_subscriptions/features.rb"
    end

    opts.on("-f", "--features-file PATH", "Specify gitlab features path (required if --src-dir is ommited)") do |v|
        GITLAB_FEATURES_FILE = File.expand_path(v)
    end

    opts.on("-o", "--output PATH", "Output to json file (required)") do |v|
        EXPORT_JSON_FILE = File.expand_path(v)
    end

    opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
    end
end
.parse!
if GITLAB_FEATURES_FILE.nil? || EXPORT_JSON_FILE.nil?
    puts "[!] missing required options"
    puts "[!] use -h for help"
    exit 1
end
puts "Reading features from #{GITLAB_FEATURES_FILE}"

def ignore_exception
    begin
      yield
    rescue Exception
    end
end

puts "[*] loading features.rb..."
ignore_exception do
    require_relative "#{GITLAB_FEATURES_FILE}"
end

ALL_FEATURES = []
GitlabSubscriptions::Features.constants.each do |const_name|
    puts "[*] gathering features from #{const_name}"
    if const_name.to_s.include? 'FEATURE'
        ALL_FEATURES.concat(GitlabSubscriptions::Features.const_get(const_name))
    else
        puts "[?] unrecognized constant #{const_name}"
    end
end

ALL_FEATURES.uniq!
ALL_FEATURES.sort_by! { |feature| feature }

puts "[*] total features: #{ALL_FEATURES.size}"

puts "[*] writing to #{EXPORT_JSON_FILE}"
File.write(EXPORT_JSON_FILE, JSON.pretty_generate(ALL_FEATURES))

puts "[*] done"