#!/usr/bin/env ruby
# encoding: utf-8

require 'openssl'
require_relative 'lib/license.rb'
puts "[i] lib gitlab-license: #{Gitlab::License::VERSION}"

OUTPUT_DIR = ARGV[0]
puts "[*] output dir: #{OUTPUT_DIR}"

LICENSE_TARGET_PRIVATE_KEY = "license_key"
LICENSE_TARGET_PUBLIC_KEY = "license_key.pub"
TARGET_LICENSE_FILE = 'result.gitlab-license'
TARGET_PLAIN_LICENSE_FILE = 'result.gitlab-license.json'

FEATURE_LIST = []
if ARGV[1].nil?
  puts "[i] you can provide a list of feature to be enabled inside license"
else
  FEATURE_LIST_FILE = ARGV[1]
  File.open(FEATURE_LIST_FILE).each do |line|
    FEATURE_LIST.push(line.chomp)
  end
  FEATURE_LIST.uniq!
end
puts "[*] loaded #{FEATURE_LIST.length} features"

Dir.chdir(OUTPUT_DIR)
puts "[*] switching working dir: #{Dir.pwd}"

puts "[*] generating license..."
if !File.exist?(LICENSE_TARGET_PRIVATE_KEY) || !File.exist?(LICENSE_TARGET_PUBLIC_KEY)
  puts "[*] generating rsa key pair..."
  key = OpenSSL::PKey::RSA.new(2048)
  File.write(LICENSE_TARGET_PRIVATE_KEY, key.to_pem)
  File.write(LICENSE_TARGET_PUBLIC_KEY, key.public_key.to_pem)
end

puts "[*] loading key pair..."

public_key = OpenSSL::PKey::RSA.new File.read(LICENSE_TARGET_PUBLIC_KEY)
private_key = OpenSSL::PKey::RSA.new File.read(LICENSE_TARGET_PRIVATE_KEY)

puts "[*] building license..."

Gitlab::License.encryption_key = private_key

license = Gitlab::License.new

# don't use gitlab inc, search `gl_team_license` in lib for details
license.licensee = {
  "Name"    => "Tim Cook",
  "Company" => "Apple Computer, Inc.",
  "Email"   => "tcook@apple.com"
}

# required of course
license.starts_at         = Date.new(1976, 4, 1)

# required since gem gitlab-license v2.2.1
license.expires_at        = Date.new(2500, 4, 1)

# prevent gitlab crash at
# notification_start_date = trial? ? expires_at - NOTIFICATION_DAYS_BEFORE_TRIAL_EXPIRY : block_changes_at
license.block_changes_at  = Date.new(2500, 4, 1)

# required
license.restrictions      = {
  plan: 'ultimate',
  # STARTER_PLAN = 'starter'
  # PREMIUM_PLAN = 'premium'
  # ULTIMATE_PLAN = 'ultimate'

  active_user_count: 2147483647,
  # required, just dont overflow
}

if !license.valid?
  puts "[E] license validation failed!"
  puts "[E] #{license.errors}"
  exit 1
end

puts "[*] exporting license file..."

File.open(TARGET_PLAIN_LICENSE_FILE, "w") { |f| f.write(JSON.pretty_generate(JSON.parse(license.to_json))) }

data = license.export
File.open(TARGET_LICENSE_FILE, "w") { |f| f.write(data) }

puts "[*] done"
