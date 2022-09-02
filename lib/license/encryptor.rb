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
