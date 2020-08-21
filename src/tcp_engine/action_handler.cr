require "json"

# --------------------------------------
#
#  Generic implementation of an action
#  that can be performed. The TCP_LISTENER
#  sends data that it recieves via the
#  socker directly here. The Action can
#  perform logic on that data.
#
# ---------------------------------------
class EncryptedTcp::ActionHandler
  def initialize
    @debug = false
    server_secret_key = "xbonlVDoHqaHLGtNsxGltuyj76NC1nojm/UdcqknEro="
    server_public_key = "5gVuFT+OYR3Q1sZrWbtkxaoHJw/A8VTeIwk3zPTqOX4="
    client_public_key = "38xzpjc8rE5eRtqgHLf3p0gADo796lLVWPhFek8Hb10="
    @debug = ENV["DEBUG"]?.to_s == "1"
    @encryptor = EncryptedTcp::Encryptor.new(server_secret_key, server_public_key, client_public_key)
  end

  # For example purposes, just output data
  def process(socket : Socket, data : String)
    received_data = @encryptor.decrypt(data)
    response = handle(received_data)
    socket.puts(@encryptor.encrypt(response))
  end

  def handle(input)
    puts "Action is processing #{input}"
    "OK"
  end
end
