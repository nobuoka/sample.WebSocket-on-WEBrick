#! ruby -EUTF-8:UTF-8
# coding: UTF-8

$LOAD_PATH.unshift File.join( File.dirname(__FILE__), 'lib' )

require 'webrick'
require 'webrick/httpresponse-extension'

server = WEBrick::HTTPServer.new(
             DocumentRoot: File.join( File.dirname(__FILE__), 'www' ),
             BindAddress:  '127.0.0.1',
             Port:         10080,
             Logger:       WEBrick::Log.new( $stderr, WEBrick::Log::DEBUG ),
)

class Listener
  def onstart( server_agent )
    $stderr << "[DEBUG] onstart\n"
  end
  def onclose( server_agent )
    $stderr << "[DEBUG] onclose\n"
  end
end

server.mount_proc( '/websocket' ) do |req, res|
  res.upgrade_websocket( req, Listener.new )
end

# TODO
# サーバーを閉じようとしたときに継続している接続をどうするか?

#srv.mount('/hoge.pl', WEBrick::HTTPServlet::CGIHandler, 'really_executed_script.rb')
# シグナルをトラップして終了処理を行うように設定
shutdown_proc = ->( sig ){ server.shutdown() }
[ :INT, :TERM ].each{ |e| Signal.trap( e, &shutdown_proc ) }
server.start
