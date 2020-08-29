require "cox"
require "base64"

class EncryptedTcp::Encryptor
  def initialize(local_secret_key : String, local_public_key : String, remote_public_key : String)
    @local_secret_key = Cox::SecretKey.new(Base64.decode_string(local_secret_key.strip))
    @local_public_key = Cox::PublicKey.new(Base64.decode_string(local_public_key.strip))
    @remote_public_key = Cox::PublicKey.new(Base64.decode_string(remote_public_key.strip))
  end

  def self.generate_keypair
    Cox::KeyPair.new
  end

  def encrypt(data)
    # Encrypt a message for Bob using his public key, signing it with Alice's
    nonce, encrypted = Cox.encrypt(data, @remote_public_key, @local_secret_key)
    return "#{Base64.urlsafe_encode(nonce.bytes, false)}:#{Base64.urlsafe_encode(encrypted, false)}"
  end

  def decrypt(data)
    if data
      puts "Data IN", data
      nonce, raw = data.split(":")
      decrypted = Cox.decrypt(Base64.decode_string(raw), Cox::Nonce.new(Base64.decode_string(nonce)), @remote_public_key, @local_secret_key)
      String.new(decrypted)
    end
  end
end
