require "cox"
require "base64"
require "../shared/*"

class EncryptedTcp::ConnectionException < Exception
end

class EncryptedTcp::EncryptionException < Exception
end

class EncryptedTcp::Connection
  ETCP_HEARTBEAT = (ENV["ETCP_HEARTBEAT"]? || "15").to_i

  def initialize(@host : String, @port : String, client_secret_key : String, client_public_key : String, server_public_key : String)
    @client = TCPSocket.new(@host, @port.to_i)
    @encryptor = EncryptedTcp::Encryptor.new(client_secret_key, client_public_key, server_public_key)
    start_heartbeat
    @debug = ENV["DEBUG"]?.to_s == "true"
  end

  def start_heartbeat
    spawn do
      loop do
        begin
          sleep ETCP_HEARTBEAT
          alive?
        rescue ex
          puts "Exception in heartbeat" if @debug
          puts ex.inspect_with_backtrace
        end
      end
    end
  end

  def build_tcp_connection
    @client.close
    @client = TCPSocket.new(@host, @port.to_i)
  end

  def close
    @client.close
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
      if @client.closed?
        build_tcp_connection
      end
      response = send("PING", false)
      return true if response == "PONG"
    rescue ex
      sleep(1)
      return true if once_alive?
      build_tcp_connection
      puts ex.inspect_with_backtrace if @debug
    end
    return false
  end

  def once_alive?
    begin
      response = send("PING", false)
      return true if response == "PONG"
    rescue ex
      build_tcp_connection
      puts ex.inspect_with_backtrace if @debug
    end
    return false
  end

  def send(data, allow_retry = true)
    send_data = ""
    begin
      send_data = @encryptor.encrypt(data)
      response = raw_send(send_data)
      response_data = @encryptor.decrypt(response)
      return response_data
    rescue ce : EncryptedTcp::ConnectionException
      puts ce.inspect_with_backtrace
      retry(send_data) if allow_retry
    rescue ex : Exception
      puts ex.inspect_with_backtrace if @debug
      retry(send_data) if allow_retry
    end
    build_tcp_connection
  end

  def raw_send(send_data)
    sent = false
    begin
      @client << "#{send_data}\n"
      sent = true
      response = @client.gets
    rescue ex
      puts sent ? "Getting Response Failed" : "Sending Failed" if @debug
      puts ex.inspect_with_backtrace if @debug
      raise EncryptedTcp::ConnectionException.new(sent ? "Getting TCP Response Failed" : "Sending TCP Failed")
    end
  end
end
