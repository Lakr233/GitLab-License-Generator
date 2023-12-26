require 'openssl'
require 'date'
require 'json'
require 'base64'

require_relative 'license/version'
require_relative 'license/encryptor'
require_relative 'license/boundary'

module Gitlab
  class License
    class Error < StandardError; end
    class ImportError < Error; end
    class ValidationError < Error; end

    class << self
      attr_reader :encryption_key
      attr_reader :fallback_decryption_keys
      @encryption_key = nil

      def encryption_key=(key)
        raise ArgumentError, 'No RSA encryption key provided.' if key && !key.is_a?(OpenSSL::PKey::RSA)

        @encryption_key = key
        @encryptor = nil
      end

      def fallback_decryption_keys=(keys)
        unless keys
          @fallback_decryption_keys = nil
          return
        end

        unless keys.is_a?(Enumerable) && keys.all? { |key| key.is_a?(OpenSSL::PKey::RSA) }
          raise ArgumentError, 'Invalid fallback RSA encryption keys provided.'
        end

        @fallback_decryption_keys = Array(keys)
      end

      def encryptor
        @encryptor ||= Encryptor.new(encryption_key)
      end

      def import(data)
        raise ImportError, 'No license data.' if data.nil?

        data = Boundary.remove_boundary(data)

        license_json = decrypt_with_fallback_keys(data)

        begin
          attributes = JSON.parse(license_json)
        rescue JSON::ParseError
          raise ImportError, 'License data is invalid JSON.'
        end

        new(attributes)
      end

      def decrypt_with_fallback_keys(data)
        keys_to_try = Array(encryption_key)
        keys_to_try += fallback_decryption_keys if fallback_decryption_keys

        keys_to_try.each do |decryption_key|
          decryptor = Encryptor.new(decryption_key)
          return decryptor.decrypt(data)
        rescue Encryptor::Error
          next
        end

        raise ImportError, 'License data could not be decrypted.'
      end
    end

    attr_reader :version
    attr_accessor :licensee, :starts_at, :expires_at, :notify_admins_at,
                  :notify_users_at, :block_changes_at, :last_synced_at, :next_sync_at,
                  :activated_at, :restrictions, :cloud_licensing_enabled,
                  :offline_cloud_licensing_enabled, :auto_renew_enabled, :seat_reconciliation_enabled,
                  :operational_metrics_enabled, :generated_from_customers_dot,
                  :generated_from_cancellation

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
      elsif !expires_at && !gl_team_license? && !jh_team_license?
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

    def generated_from_cancellation?
      generated_from_cancellation == true
    end

    def gl_team_license?
      licensee['Company'].to_s.match?(/GitLab/i) && licensee['Email'].to_s.end_with?('@gitlab.com')
    end

    def jh_team_license?
      licensee['Company'].to_s.match?(/GitLab/i) && licensee['Email'].to_s.end_with?('@jihulab.com')
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

      # `issued_at` is the legacy name for starts_at.
      # TODO: Move to starts_at in a next version.
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
      hash['generated_from_cancellation'] = generated_from_cancellation?

      hash['restrictions'] = restrictions if restricted?

      hash
    end

    def to_json(*_args)
      JSON.dump(attributes)
    end

    def export(boundary: nil)
      validate!

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

      # `issued_at` is the legacy name for starts_at.
      # TODO: Move to starts_at in a next version.
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
        generated_from_cancellation
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
