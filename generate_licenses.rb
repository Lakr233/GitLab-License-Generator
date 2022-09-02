require_relative 'lib/license.rb'

# MARK: GENERATOR
#
if !File.file?("license_key") || !File.file?("license_key.pub")
  puts "License key not found"
  puts "Generate a RSA key pair using generate_keys.rb"
  exit
end

public_key = OpenSSL::PKey::RSA.new File.read("license_key.pub")
private_key = OpenSSL::PKey::RSA.new File.read("license_key")

Gitlab::License.encryption_key = private_key

license = Gitlab::License.new

license.licensee = {
  "Name"    => "Tim Cook",
  "Company" => "Apple Computer, Inc.",
  "Email"   => "tcook@apple.com"
}

license.starts_at       = Date.new(1976, 4, 1)
license.expires_at      = Date.new(8848, 4, 1)
license.restrictions    = {
  plan: 'Ultimate',
  active_user_count: 1145141919810,
}

data = license.export
File.open("result.gitlab-license", "w") { |f| f.write(data) }
