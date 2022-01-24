require 'openssl'

key_pair = OpenSSL::PKey::RSA.generate(2048)
File.open("license_key", "w") { |f| f.write(key_pair.to_pem) }

public_key = key_pair.public_key
File.open("license_key.pub", "w") { |f| f.write(public_key.to_pem) }

puts "Generated RSA key pairs, use generate_licenses.rb to generate licenses."
puts "Make your own customization to the code if needed."