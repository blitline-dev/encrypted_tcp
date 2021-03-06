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
  end

  # For example purposes, just output data
  def process(socket : Socket, encryptor : EncryptedTcp::Encryptor, data : String)
    received_data = encryptor.decrypt(data)
    return if check_ping(received_data, socket, encryptor)
    response = handle(received_data)
    return locked_puts(socket, encryptor.encrypt(response))
  end

  def check_ping(data, socket, encryptor)
    if data.to_s[0..4] == "PING"
      pong_response(socket, encryptor)
      return true
    end
    false
  end

  def pong_response(socket : TCPSocket, encryptor)
    return locked_puts(socket, encryptor.encrypt("PONG"))
  end

  def locked_puts(socket, data)
    output = ""
    output = socket.puts(data.to_s)
    output
  end

  # Handle is the single logic point of an action
  # The input is the unencryped data request
  # and the output will be the unencrypted response
  # back to the client
  abstract def handle(input) : String
end
