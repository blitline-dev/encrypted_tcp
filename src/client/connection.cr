require "base64"
require "../shared/*"

class EncryptedTcp::ConnectionException < Exception
end

class EncryptedTcp::EncryptionException < Exception
end

class EncryptedTcp::Connection
  ETCP_HEARTBEAT            = (ENV["ETCP_HEARTBEAT"]? || "15").to_i
  LOCAL_TCP_KEEPALIVE       = (ENV["TCP_KEEPALIVE"]? || "100").to_i
  LOCAL_TCP_NODELAY         = ENV["TCP_NODELAY"]? || "true"
  LOCAL_TCP_IDLE            = (ENV["TCP_KEEPALIVE_IDLE"]? || "10").to_i
  LOCAL_TCP_KEEPALIVE_COUNT = (ENV["TCP_KEEPALIVE_COUNT"]? || "10").to_i
  DEBUG_WATCHFILE           = ENV["DEBUG_WATCHFILE"]? || "/tmp/debug"

  def initialize(@host : String, @port : String, client_secret_key : String, client_public_key : String, server_public_key : String)
    @debug = false
    @client = TCPSocket.new(@host, @port.to_i, 20, 20)
    @client.tcp_keepalive_interval = LOCAL_TCP_KEEPALIVE
    @client.tcp_nodelay = (LOCAL_TCP_NODELAY == "true")
    @client.tcp_keepalive_idle = LOCAL_TCP_IDLE
    @client.tcp_keepalive_count = LOCAL_TCP_KEEPALIVE_COUNT
    @client.flush_on_newline = true
    @client.sync = true
    @client.tcp_nodelay = true
    @client.read_timeout = 30
    @encryptor = EncryptedTcp::Encryptor.new(client_secret_key, client_public_key, server_public_key)
    start_heartbeat
    @debug = ENV["DEBUG"]?.to_s == "true"
    @debug_watchfile = false
    spawn_debug_watcher
  end

  def spawn_debug_watcher
    spawn do
      loop do
        if File.exists?(DEBUG_WATCHFILE)
          puts "DEBUG FILE FOUND #{DEBUG_WATCHFILE}"
          @debug = true
          @debug_watchfile = true
        else
          if @debug_watchfile
            @debug_watchfile = false
            @debug = false
          end
        end
        sleep 30
      end
    end
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
    begin
      @client.close
    rescue closex
      puts "Exception closing TCPSocket. Handled"
      puts closex.inspect_with_backtrace
    end
    sleep(5)

    begin
      @client = TCPSocket.new(@host, @port.to_i, 20, 20)
      @client.tcp_keepalive_interval = LOCAL_TCP_KEEPALIVE
      @client.tcp_nodelay = (LOCAL_TCP_NODELAY == "true")
      @client.tcp_keepalive_idle = LOCAL_TCP_IDLE
      @client.tcp_keepalive_count = LOCAL_TCP_KEEPALIVE_COUNT
      @client.flush_on_newline = true
      @client.sync = true
      @client.tcp_nodelay = true
      @client.read_timeout = 30
      sleep 1
    rescue createx
      if @client
        @client.close
      end
      puts "Exception creating TCPSocket. Handled"
      puts createx.inspect_with_backtrace
    end
  end

  def close
    @client.close
  end

  def retry(encrypted_data)
    1.upto(5) do |x|
      sleep(x * 5)
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

  def mutex : Mutex
    @mutex = Mutex.new unless @mutex
    return @mutex.not_nil!
  end

  def alive?
    begin
      if @client.closed?
        build_tcp_connection
      end
      return ping?
    rescue ex
      sleep(5)
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
      puts "Regular Exception with data #{data}"
      response_data = retry(send_data)
    end

    response_data
  end

  def raw_send(send_data)
    sent = false
    begin
      response = ""
      mutex.synchronize do
        @client.puts send_data
        sent = true
        response = @client.gets
      end
      response
    rescue ex
      puts sent ? "Getting Response Failed" : "Sending Failed"
      puts ex.inspect_with_backtrace
      build_tcp_connection
      raise EncryptedTcp::ConnectionException.new(sent ? "Getting TCP Response Failed" : "Sending TCP Failed")
    end
  end
end
