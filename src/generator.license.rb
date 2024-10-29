#!/usr/bin/env ruby
# encoding: utf-8

license_file_path = nil
license_json_path = nil
public_key_path = nil
private_key_path = nil
features_json_path = nil
license_name="Tim Cook"
license_company="Apple Computer, Inc."
license_email="tcook@apple.com"
license_plan='ultimate'
license_user_count=2147483647
license_expire_year=2500

require 'optparse'
OptionParser.new do |opts|
  opts.banner = "Usage: generator.license.rb [options]"

  opts.on("-o", "--output PATH", "Output to dir (required)") do |v|
    license_file_path = File.expand_path(v)
  end

  opts.on("--public-key PATH", "Specify public key file (required)") do |v|
    public_key_path = File.expand_path(v)
  end

  opts.on("--private-key PATH", "Specify private key file (required)") do |v|
    private_key_path = File.expand_path(v)
  end

  opts.on("-f", "--features PATH", "Specify features json file (optional)") do |v|
    features_json_path = File.expand_path(v)
  end

  opts.on("--plain-license PATH", "Export license in json if set, useful for debug. (optional)") do |v|
    license_json_path = File.expand_path(v)
  end

  opts.on("--license-name <Name>", "Specify license name (optional) [#{license_name}]") do |v|
    license_name = v
  end

  opts.on("--license-company <Company Name>", "Specify license company (optional) [#{license_company}]") do |v|
    license_company = v
  end

  opts.on("--license-email <Email Address>", "Specify license email address (optional) [#{license_email}]") do |v|
    license_email = v
  end
  
  opts.on("--license-plan <Plan>", "Specify license plan (optional) [#{license_plan}(default),premium,starter]") do |v|
    license_plan = v
  end
  
  opts.on("--license-user-count <Email Address>", "Specify license user count (optional) [#{license_user_count}(default)]") do |v|
    license_user_count = v.to_i
  end
  
  opts.on("--license-expire-year <Year>", "Specify license expire year (optional) [#{license_expire_year}(default)]") do |v|
    license_expire_year = v.to_i
  end
  
  opts.on("-h", "--help", "Prints this help") do
      puts opts
      exit
  end
end
.parse!

if license_file_path.nil? || public_key_path.nil? || private_key_path.nil?
  puts "[!] missing required options"
  puts "[!] use -h for help"
  exit 1
end

if license_plan != 'ultimate' &&  license_plan != 'premium' &&  license_plan != 'starter'
  puts "[!] license plan is set to #{license_plan} which is not one of [ultimate, premium, starter]"
  puts "[!] use -h for help"
  exit 1
end
# ==========

puts "[*] loading keys..."
require 'openssl'
PUBLIC_KEY = OpenSSL::PKey::RSA.new File.read(public_key_path)
PRIVATE_KEY = OpenSSL::PKey::RSA.new File.read(private_key_path)

puts "[*] loading licenses..."
require_relative '../lib/license.rb'
puts "[i] lib gitlab-license: #{Gitlab::License::VERSION}"

if !features_json_path.nil?
  puts "[*] loading features from #{features_json_path}"
  require 'json'
  FEATURE_LIST = JSON.parse(File.read(features_json_path))
else 
  FEATURE_LIST = []
end
puts "[*] total features to inject: #{FEATURE_LIST.size}"

# ==========

puts "[*] building a license..."

Gitlab::License.encryption_key = PRIVATE_KEY

license = Gitlab::License.new

# don't use gitlab inc, search `gl_team_license` in lib for details
license.licensee = {
  "Name"    => license_name,
  "Company" => license_company,
  "Email"   => license_email
}

# required of course
license.starts_at         = Date.new(1976, 4, 1)

# required since gem gitlab-license v2.2.1
license.expires_at        = Date.new(license_expire_year, 4, 1)

# prevent gitlab crash at
# notification_start_date = trial? ? expires_at - NOTIFICATION_DAYS_BEFORE_TRIAL_EXPIRY : block_changes_at
license.block_changes_at  = Date.new(license_expire_year, 4, 1)

# required
license.restrictions      = {
  plan: license_plan,
  # STARTER_PLAN = 'starter'
  # PREMIUM_PLAN = 'premium'
  # ULTIMATE_PLAN = 'ultimate'

  active_user_count: license_user_count,
  # required, just dont overflow
}

# restricted_attr will access restrictions
# add_ons will access restricted_attr(:add_ons, {})
# so here by we inject all features into restrictions
# see scan.rb for a list of features that we are going to inject
for feature in FEATURE_LIST
  license.restrictions[feature] = license_user_count
end

puts "[*] validating license..."
if !license.valid?
  puts "[E] license validation failed!"
  puts "[E] #{license.errors}"
  exit 1
end
puts "[*] license validated"

puts "[*] exporting license file..."

if !license_json_path.nil?
  puts "[*] writing to #{license_json_path}"
  File.write(license_json_path, JSON.pretty_generate(JSON.parse(license.to_json)))
end

puts "[*] writing to #{license_file_path}"
File.write(license_file_path, license.export)

puts "[*] done"
