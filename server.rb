#! ruby -EUTF-8:UTF-8
# coding: UTF-8

$LOAD_PATH.unshift File.join( File.dirname(__FILE__), 'lib' )

require 'set'
require 'webrick'
require 'webrick/httpresponse-extension'

server = WEBrick::HTTPServer.new(
             DocumentRoot: File.join( File.dirname(__FILE__), 'www' ),
             BindAddress:  '127.0.0.1',
             Port:         10080,
             Logger:       WEBrick::Log.new( $stderr, WEBrick::Log::DEBUG ),
)

agent_set = Set.new()
class Listener
  def initialize( agent_set )
    @agent_set = agent_set
  end
  def onopen( server_agent )
    $stderr << "[DEBUG] onstart\n"
    @agent_set.add server_agent
  end
  def onclose( server_agent )
    $stderr << "[DEBUG] onclose\n"
    @agent_set.delete server_agent
  end
  def onmessage( server_agent, data, type )
    @agent_set.each do |agent|
      agent.send_text( data )
    end
  end
end

listener = Listener.new( agent_set )
server.mount_proc( '/websocket' ) do |req, res|
  res.upgrade_websocket( req, listener )
end

# TODO
# サーバーを閉じようとしたときに継続している接続をどうするか?

#srv.mount('/hoge.pl', WEBrick::HTTPServlet::CGIHandler, 'really_executed_script.rb')
# シグナルをトラップして終了処理を行うように設定
shutdown_proc = ->( sig ){ server.shutdown() }
[ :INT, :TERM ].each{ |e| Signal.trap( e, &shutdown_proc ) }
server.start
