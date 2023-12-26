#!/usr/bin/env ruby
# encoding: utf-8

require 'optparse'
require 'openssl'

public_key_file = nil
private_key_file = nil

OptionParser.new do |opts|
  opts.banner = "Usage: generator.keys.rb [options]"

  opts.on("--public-key PATH", "Specify public key file (required)") do |v|
    public_key_file = File.expand_path(v)
  end

  opts.on("--private-key PATH", "Specify private key file (required)") do |v|
    private_key_file = File.expand_path(v)
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if public_key_file.nil? || private_key_file.nil?
  puts "[!] missing required options"
  puts "[!] use -h for help"
  exit 1
end

if File.exist?(private_key_file) || File.exist?(public_key_file)
  puts "[!] key pair already exists"
  puts "[!] remove them if you want to regenerate"
  exit 1
end

puts "[*] generating rsa key pair..."
key = OpenSSL::PKey::RSA.new(2048)
File.write(private_key_file, key.to_pem)
File.write(public_key_file, key.public_key.to_pem)

puts "[*] done"
