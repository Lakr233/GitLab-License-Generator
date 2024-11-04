#!/usr/bin/env ruby
# encoding: utf-8

require 'base64'
require 'json'
require 'openssl'
require 'tempfile'
require 'optparse'
require_relative '../lib/license/encryptor'

public_key_path = nil
in_file = nil

OptionParser.new do |opts|
  opts.banner = "Usage: xxx.rb [options]"

  opts.on("-k", "--public-key PATH", "Specify public key file (required)") do |v|
    public_key_path = File.expand_path(v)
  end

  opts.on("-i", "--in PATH", "input license path") do |v|
    in_file = File.expand_path(v)
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end
            .parse!

if in_file.nil? || public_key_path.nil?
  puts "[!] missing required options"
  puts "[!] use -h for help"
  exit 1
end

content = File.read(in_file)
attributes = JSON.parse(Base64.decode64(content))

PUBLIC_KEY = OpenSSL::PKey::RSA.new File.read(public_key_path)
decryptor = Gitlab::License::Encryptor.new(PUBLIC_KEY)
plain_license = decryptor.decrypt(content)
edited_json = nil

Tempfile.create(['json_edit', '.json']) do |file|
  file.write(JSON.pretty_generate(JSON.parse(plain_license)))
  file.flush

  system("vim #{file.path}")
  file.rewind
  edited_json = file.read
end

edited_json = JSON.generate(JSON.parse(edited_json))

cipher = OpenSSL::Cipher::AES128.new(:CBC)
cipher.encrypt
cipher.key = PUBLIC_KEY.public_decrypt(Base64.decode64(attributes['key']))
cipher.iv = Base64.decode64(attributes['iv'])

encrypted_data = cipher.update(edited_json) + cipher.final

encryption_data = {
  'data' => Base64.encode64(encrypted_data),
  'key' => attributes['key'],
  'iv' => attributes['iv']
}

json_data = JSON.dump(encryption_data)
puts Base64.encode64(json_data)
