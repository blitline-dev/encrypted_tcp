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
abstract class EncryptedTcp::ActionHandler
  def initialize
    @debug = false
    @debug = ENV["DEBUG"]?.to_s == "1"
  end

  # For example purposes, just output data
  def process(socket : Socket, encryptor : EncryptedTcp::Encryptor, data : String)
    received_data = encryptor.decrypt(data)
    response = handle(received_data)
    socket.puts(encryptor.encrypt(response))
  end

  # Handle is the single logic point of an action
  # The input is the unencryped data request
  # and the output will be the unencrypted response
  # back to the client
  abstract def handle(input) : String
end
