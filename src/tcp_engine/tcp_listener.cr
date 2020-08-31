require "socket"
require "./action_handler"
require "../shared/*"

# --------------------------------------
#
# TCP_LISTENER is a production ready example
# of a crystal TCPSocket listener with a pool
# of 200 fibers ready to process incoming data
#
# There are numerous caveats and tweaks you
# can do to optmize for your situation, where
# this example tries to meet a 'happy medium'
# between short lived TCP connections and large
# data bursts over a TCP socket.
#
# --------------------------------------
class EncryptedTcp::TcpListener
  TOTAL_FIBERS = 2500

  def initialize(@host : String, @port : Int32, @action : ActionHandler, @config : Hash(String, String))
    @connections = 0
    @version = ENV["VERSION"]? || "0.0"
    @total_invokations = 0

    server_secret_key = config["server_secret_key"]
    server_public_key = config["server_public_key"]
    client_public_key = config["client_public_key"]
    @encryptor = EncryptedTcp::Encryptor.new(server_secret_key, server_public_key, client_public_key)
    @debug = false
    @debug = ENV["DEBUG"]?.to_s == "true" if ENV["DEBUG"]?
    set_trap
  end

  def build_channel
    Channel(TCPSocket).new
  end

  def listen
    ch = build_channel
    server = TCPServer.new(@host, @port)

    spawn_listener(ch)
    begin
      loop do
        socket = server.accept
        ch.send socket
      end
    rescue ex
      if @debug
        puts "Error in tcp:loop!"
        puts ex.message
      end
    end
  end

  def spawn_listener(socket_channel : Channel)
    TOTAL_FIBERS.times do
      spawn do
        loop do
          begin
            socket = socket_channel.receive
            socket.flush_on_newline = true
            socket.sync = true
            socket.read_timeout = 20
            @connections += 1
            reader(socket)
            @total_invokations += 1
            @connections -= 1
          rescue ex
            if socket
              socket.close
            end
            @connections -= 1
            if @debug
              puts "Error in spawn_listener"
              puts ex.message
            end
          end
        end
      end
    end
  end

  def get_socket_data(socket : TCPSocket)
    begin
      socket.each_line do |line|
        puts line.to_s if @debug
        yield(line)
      end
    rescue ex
      if @debug
        puts "From Socket Address:" + socket.remote_address.to_s if socket.remote_address
        puts ex.inspect_with_backtrace
      end
    end
  end

  def reader(socket : TCPSocket)
    get_socket_data(socket) do |lines|
      if lines
        lines.each_line do |data|
          @total_invokations += 1
          if data.to_s[0..4] == "stats"
            stats_response(socket)
            return
          end
          if data.to_s[0..4] == "PING"
            pong_response(socket)
            return
          end

          puts "Recieved: #{data}" if @debug

          if data && data.size > 5
            begin
              # --------------------------------
              # Ignore random data. You WILL get this if publicly
              # accessible.
              # --------------------------------
              return unless data.valid_encoding?
              @action.process(socket, @encryptor, data)
            rescue ex
              puts ex.inspect_with_backtrace
              puts "Data:#{data}"
              puts "Remote address #{socket.remote_address.to_s}" if socket.remote_address
            end
          end
        end
      end
    end
  end

  def stats_response(socket : TCPSocket)
    data = {
      "version"           => @version,
      "debug"             => @debug,
      "connections"       => @connections,
      "port"              => @port,
      "available"         => TOTAL_FIBERS,
      "total_invokations" => @total_invokations,
    }
    socket.puts(data.to_json)
  end

  def pong_response(socket : TCPSocket)
    socket.puts("PONG")
  end

  # ------------------------------------
  # Convernience method to turn on DEBUG
  # with a USR1 signal
  # ------------------------------------
  def set_trap
    Signal::USR1.trap do
      @debug = !@debug
      puts "Debug now: #{@debug}"
    end
  end
end
