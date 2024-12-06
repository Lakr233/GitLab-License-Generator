#!/usr/bin/env ruby
# encoding: utf-8

require 'json'
require 'optparse'

#
# this file was removed due to DMCA report
# following action was taken
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
# 

OptionParser.new do |opts|
    opts.banner = "Usage: scan.features.rb [options]"

    opts.on("-s", "--src-dir PATH", "") do |v|
        # empty block
    end

    opts.on("-f", "--features-file PATH", "") do |v|
        # empty block
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

File.open(EXPORT_JSON_FILE, 'w') { |file| file.write("{}") }
