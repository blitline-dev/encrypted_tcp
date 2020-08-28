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
    @debug = false
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
      if once_alive?
        response = raw_send(encrypted_data)
        response_data = @encryptor.decrypt(response)
        if response_data && !response_data.empty?
          return response_data
        else
          build_tcp_connection
        end
      else
        build_tcp_connection
      end
      puts "Retrying"
    end
    puts "Retries Failed"
    raise EncryptedTcp::ConnectionException.new("Couldn't send data to server. No Connection")
  end

  def alive?
    begin
      if @client.closed?
        build_tcp_connection
      end
      return ping?
    rescue ex
      sleep(1)
      return true if once_alive?
      puts ex.inspect_with_backtrace if @debug
    end
    return false
  end

  def ping?
    is_ok = false
    begin
      send_data = @encryptor.encrypt("PING")
      response = raw_send(send_data)
      response_data = @encryptor.decrypt(response)
      is_ok = (response == "PONG")
    rescue ex
      puts "Failed PING"
    end
    return is_ok
  end

  def once_alive?
    begin
      return ping?
    rescue ex
      build_tcp_connection
      puts "Failed once_alive?" if @debug
    end
    return false
  end

  def send(data)
    send_data = ""
    response_data = ""
    begin
      send_data = @encryptor.encrypt(data)
      response = raw_send(send_data)
      response_data = @encryptor.decrypt(response)
      if response_data.nil? || response_data.empty?
        puts "Empty response?! Weird:"
        response_data = retry(send_data)
      end
      return response_data
    rescue ce : EncryptedTcp::ConnectionException
      puts "Excryption Exception with data #{data}"
      response_data = retry(send_data)
    rescue ex : Exception
      puts "Regular Exception with data #{data}" if @debug
      response_data = retry(send_data)
    end

    response_data
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
