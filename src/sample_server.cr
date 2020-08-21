require "./tcp_engine/*"

class SampleAction < EncryptedTcp::ActionHandler
  def handle(input) : String
    puts "Handled"
    "OK"
  end
end

class SampleServer
  VERSION = "0.1.0"

  def self.start
    port = ENV["TCP_PORT"]? || "6768"
    stats_port = ENV["STATS_TCP_PORT"]? || "6770"
    listen = ENV["LISTEN"]? || "0.0.0.0"
    debug = ENV["DEBUG"]?.to_s == "true"

    puts "Starting TCP Engine"
    puts "TCP listening on #{listen}:#{port}"
    if debug
      puts "Debug Mode"
    end

    config = {
      "server_secret_key" => "xbonlVDoHqaHLGtNsxGltuyj76NC1nojm/UdcqknEro=",
      "server_public_key" => "5gVuFT+OYR3Q1sZrWbtkxaoHJw/A8VTeIwk3zPTqOX4=",
      "client_public_key" => "38xzpjc8rE5eRtqgHLf3p0gADo796lLVWPhFek8Hb10=",
    }

    action = SampleAction.new
    server = EncryptedTcp::TcpListener.new(listen, port.to_i, action, config, debug)
    server.listen
  end
end

SampleServer.start
