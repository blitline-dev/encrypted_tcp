require "cox"
require "base64"
require "./encryptor"

class EncryptedTcp::ConnectionException < Exception
end

class EncryptedTcp::EncryptionException < Exception
end

class EncryptedTcp::Connection
  def initialize(@host : String, @port : String, client_secret_key : String, client_public_key : String, server_public_key : String)
    @client = TCPSocket.new(@host, @port.to_i)
    puts "Create Client on #{@host}:#{port}"
    @encryptor = EncryptedTcp::Encryptor.new(client_secret_key, client_public_key, server_public_key)
  end

  def build_tcp_connection
    @client.close
    @client = TCPSocket.new(@host, @port.to_i)
  end

  def retry(encrypted_data)
    1.upto(5) do
      sleep(1)
      if alive?
        response = raw_send(encrypted_data)
        response_data = @encryptor.decrypt(response)
        return response_data
      else
        @client.close
        build_tcp_connection
      end
    end
    raise EncryptedTcp::ConnectionException.new("Couldn't send data to server. No Connection")
  end

  def alive?
    begin
      return false if @client.closed?
      @client << "PING\n"
      resp = @client.gets
      return true if resp == "PONG"
    rescue ex
      puts "Alive? Failed"
      puts ex.inspect_with_backtrace
    end
    return false
  end

  def send(data)
    send_data = ""
    begin
      send_data = @encryptor.encrypt(data)
      response = raw_send(send_data)
      response_data = @encryptor.decrypt(response)
      return response_data
    rescue ce : EncryptedTcp::ConnectionException
      retry(send_data)
    rescue ex : Exception
      EncryptedTcp::EncryptionException.new(ex.message)
    end
  end

  def raw_send(send_data)
    sent = false
    begin
      @client << "#{send_data}\n"
      sent = true
      response = @client.gets
    rescue ex
      puts sent ? "Getting Response Failed" : "Sending Failed"
      puts ex.inspect_with_backtrace
      raise EncryptedTcp::ConnectionException.new(sent ? "Getting TCP Response Failed" : "Sending TCP Failed")
    end
  end
end
