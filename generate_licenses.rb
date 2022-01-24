require 'openssl'
require 'date'
require 'json'
require 'base64'

module Gitlab
  class License
    VERSION = '2.1.0'.freeze
  end
end

module Gitlab
  class License
    class Encryptor
      class Error < StandardError; end
      class KeyError < Error; end
      class DecryptionError < Error; end

      attr_accessor :key

      def initialize(key)
        raise KeyError, 'No RSA encryption key provided.' if key && !key.is_a?(OpenSSL::PKey::RSA)

        @key = key
      end

      def encrypt(data)
        raise KeyError, 'Provided key is not a private key.' unless key.private?

        # Encrypt the data using symmetric AES encryption.
        cipher = OpenSSL::Cipher::AES128.new(:CBC)
        cipher.encrypt
        aes_key = cipher.random_key
        aes_iv  = cipher.random_iv

        encrypted_data = cipher.update(data) + cipher.final

        # Encrypt the AES key using asymmetric RSA encryption.
        encrypted_key = key.private_encrypt(aes_key)

        encryption_data = {
          'data' => Base64.encode64(encrypted_data),
          'key' => Base64.encode64(encrypted_key),
          'iv' => Base64.encode64(aes_iv)
        }

        json_data = JSON.dump(encryption_data)
        Base64.encode64(json_data)
      end

      def decrypt(data)
        raise KeyError, 'Provided key is not a public key.' unless key.public?

        json_data = Base64.decode64(data.chomp)

        begin
          encryption_data = JSON.parse(json_data)
        rescue JSON::ParserError
          raise DecryptionError, 'Encryption data is invalid JSON.'
        end

        unless %w[data key iv].all? { |key| encryption_data[key] }
          raise DecryptionError, 'Required field missing from encryption data.'
        end

        encrypted_data  = Base64.decode64(encryption_data['data'])
        encrypted_key   = Base64.decode64(encryption_data['key'])
        aes_iv          = Base64.decode64(encryption_data['iv'])

        begin
          # Decrypt the AES key using asymmetric RSA encryption.
          aes_key = self.key.public_decrypt(encrypted_key)
        rescue OpenSSL::PKey::RSAError
          raise DecryptionError, 'AES encryption key could not be decrypted.'
        end

        # Decrypt the data using symmetric AES encryption.
        cipher = OpenSSL::Cipher::AES128.new(:CBC)
        cipher.decrypt

        begin
          cipher.key = aes_key
        rescue OpenSSL::Cipher::CipherError
          raise DecryptionError, 'AES encryption key is invalid.'
        end

        begin
          cipher.iv = aes_iv
        rescue OpenSSL::Cipher::CipherError
          raise DecryptionError, 'AES IV is invalid.'
        end

        begin
          data = cipher.update(encrypted_data) + cipher.final
        rescue OpenSSL::Cipher::CipherError
          raise DecryptionError, 'Data could not be decrypted.'
        end

        data
      end
    end
  end
end

module Gitlab
  class License
    module Boundary
      BOUNDARY_START  = /(\A|\r?\n)-*BEGIN .+? LICENSE-*\r?\n/.freeze
      BOUNDARY_END    = /\r?\n-*END .+? LICENSE-*(\r?\n|\z)/.freeze

      class << self
        def add_boundary(data, product_name)
          data = remove_boundary(data)

          product_name.upcase!

          pad = lambda do |message, width|
            total_padding = [width - message.length, 0].max

            padding = total_padding / 2.0
            [
              '-' * padding.ceil,
              message,
              '-' * padding.floor
            ].join
          end

          [
            pad.call("BEGIN #{product_name} LICENSE", 60),
            data.strip,
            pad.call("END #{product_name} LICENSE", 60)
          ].join("\n")
        end

        def remove_boundary(data)
          after_boundary  = data.split(BOUNDARY_START).last
          in_boundary     = after_boundary.split(BOUNDARY_END).first

          in_boundary
        end
      end
    end
  end
end

module Gitlab
  class License
    class Error < StandardError; end
    class ImportError < Error; end
    class ValidationError < Error; end

    class << self
      attr_reader :encryption_key
      @encryption_key = nil

      def encryption_key=(key)
        raise ArgumentError, 'No RSA encryption key provided.' if key && !key.is_a?(OpenSSL::PKey::RSA)

        @encryption_key = key
        @encryptor = nil
      end

      def encryptor
        @encryptor ||= Encryptor.new(encryption_key)
      end

      def import(data)
        raise ImportError, 'No license data.' if data.nil?

        data = Boundary.remove_boundary(data)

        begin
          license_json = encryptor.decrypt(data)
        rescue Encryptor::Error
          raise ImportError, 'License data could not be decrypted.'
        end

        begin
          attributes = JSON.parse(license_json)
        rescue JSON::ParseError
          raise ImportError, 'License data is invalid JSON.'
        end

        new(attributes)
      end
    end

    attr_reader :version
    attr_accessor :licensee, :starts_at, :expires_at, :notify_admins_at,
                  :notify_users_at, :block_changes_at, :last_synced_at, :next_sync_at,
                  :activated_at, :restrictions, :cloud_licensing_enabled,
                  :offline_cloud_licensing_enabled, :auto_renew_enabled, :seat_reconciliation_enabled,
                  :operational_metrics_enabled, :generated_from_customers_dot

    alias_method :issued_at, :starts_at
    alias_method :issued_at=, :starts_at=

    def initialize(attributes = {})
      load_attributes(attributes)
    end

    def valid?
      if !licensee || !licensee.is_a?(Hash) || licensee.empty?
        false
      elsif !starts_at || !starts_at.is_a?(Date)
        false
      elsif expires_at && !expires_at.is_a?(Date)
        false
      elsif notify_admins_at && !notify_admins_at.is_a?(Date)
        false
      elsif notify_users_at && !notify_users_at.is_a?(Date)
        false
      elsif block_changes_at && !block_changes_at.is_a?(Date)
        false
      elsif last_synced_at && !last_synced_at.is_a?(DateTime)
        false
      elsif next_sync_at && !next_sync_at.is_a?(DateTime)
        false
      elsif activated_at && !activated_at.is_a?(DateTime)
        false
      elsif restrictions && !restrictions.is_a?(Hash)
        false
      elsif !cloud_licensing? && offline_cloud_licensing?
        false
      else
        true
      end
    end

    def validate!
      raise ValidationError, 'License is invalid' unless valid?
    end

    def will_expire?
      expires_at
    end

    def will_notify_admins?
      notify_admins_at
    end

    def will_notify_users?
      notify_users_at
    end

    def will_block_changes?
      block_changes_at
    end

    def will_sync?
      next_sync_at
    end

    def activated?
      activated_at
    end

    def expired?
      will_expire? && Date.today >= expires_at
    end

    def notify_admins?
      will_notify_admins? && Date.today >= notify_admins_at
    end

    def notify_users?
      will_notify_users? && Date.today >= notify_users_at
    end

    def block_changes?
      will_block_changes? && Date.today >= block_changes_at
    end

    def cloud_licensing?
      cloud_licensing_enabled == true
    end

    def offline_cloud_licensing?
      offline_cloud_licensing_enabled == true
    end

    def auto_renew?
      auto_renew_enabled == true
    end

    def seat_reconciliation?
      seat_reconciliation_enabled == true
    end

    def operational_metrics?
      operational_metrics_enabled == true
    end

    def generated_from_customers_dot?
      generated_from_customers_dot == true
    end

    def restricted?(key = nil)
      if key
        restricted? && restrictions.has_key?(key)
      else
        restrictions && restrictions.length >= 1
      end
    end

    def attributes
      hash = {}

      hash['version'] = version
      hash['licensee'] = licensee

      hash['issued_at'] = starts_at
      hash['expires_at'] = expires_at if will_expire?

      hash['notify_admins_at'] = notify_admins_at if will_notify_admins?
      hash['notify_users_at'] = notify_users_at if will_notify_users?
      hash['block_changes_at'] = block_changes_at if will_block_changes?

      hash['next_sync_at'] = next_sync_at if will_sync?
      hash['last_synced_at'] = last_synced_at if will_sync?
      hash['activated_at'] = activated_at if activated?

      hash['cloud_licensing_enabled'] = cloud_licensing?
      hash['offline_cloud_licensing_enabled'] = offline_cloud_licensing?
      hash['auto_renew_enabled'] = auto_renew?
      hash['seat_reconciliation_enabled'] = seat_reconciliation?
      hash['operational_metrics_enabled'] = operational_metrics?

      hash['generated_from_customers_dot'] = generated_from_customers_dot?

      hash['restrictions'] = restrictions if restricted?

      hash
    end

    def to_json(*_args)
      JSON.dump(attributes)
    end

    def export(boundary: nil)
      validate!

      puts to_json

      data = self.class.encryptor.encrypt(to_json)

      data = Boundary.add_boundary(data, boundary) if boundary

      data
    end

    private

    def load_attributes(attributes)
      attributes = attributes.transform_keys(&:to_s)

      version = attributes['version'] || 1
      raise ArgumentError, 'Version is too new' unless version && version == 1

      @version = version

      @licensee = attributes['licensee']

      %w[issued_at expires_at notify_admins_at notify_users_at block_changes_at].each do |attr_name|
        set_date_attribute(attr_name, attributes[attr_name])
      end

      %w[last_synced_at next_sync_at activated_at].each do |attr_name|
        set_datetime_attribute(attr_name, attributes[attr_name])
      end

      %w[
        cloud_licensing_enabled
        offline_cloud_licensing_enabled
        auto_renew_enabled
        seat_reconciliation_enabled
        operational_metrics_enabled
        generated_from_customers_dot
      ].each do |attr_name|
        public_send("#{attr_name}=", attributes[attr_name] == true)
      end

      restrictions = attributes['restrictions']
      if restrictions&.is_a?(Hash)
        restrictions = restrictions.transform_keys(&:to_sym)
        @restrictions = restrictions
      end
    end

    def set_date_attribute(attr_name, value, date_class = Date)
      value = date_class.parse(value) rescue nil if value.is_a?(String)

      return unless value

      public_send("#{attr_name}=", value)
    end

    def set_datetime_attribute(attr_name, value)
      set_date_attribute(attr_name, value, DateTime)
    end
  end
end

# MARK: GENERATOR

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
  "Name"    => "GitLab Inc.",
  "Company" => "GitLab Inc.",
  "Email"   => "support@gitlab.com"
}

license.starts_at         = Date.new(2000, 1, 1)
license.restrictions  = {
  plan: 'ultimate',
  active_user_count: 100000000,
}

data = license.export
File.open("result.gitlab-license", "w") { |f| f.write(data) }
