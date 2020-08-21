require "./tcp_engine/*"

class SampleClient
  VERSION = "0.1.0"

  def start
    client_private_key = "zFR/oO7bs2iMjdSWVDmn0pdWD4loy2ABD2X9PLquGJQ="
    client_public_key = "38xzpjc8rE5eRtqgHLf3p0gADo796lLVWPhFek8Hb10="
    server_public_key = "5gVuFT+OYR3Q1sZrWbtkxaoHJw/A8VTeIwk3zPTqOX4="
    server_port = ENV["TCP_PORT"]? || "6768"
    connection = EncryptedTcp::Connection.new("127.0.0.1", server_port, client_private_key, client_public_key, server_public_key)
    1.upto(100) do
      if connection
        response = connection.send(("Jason" * 1024))
        puts response
      end
    end
  end
end

SampleClient.new.start
