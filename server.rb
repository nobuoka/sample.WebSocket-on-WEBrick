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

class Frame
  TYPE_TEXT  = :text
  TYPE_CLOSE = 0x08 #:close
  def self.create_text_frame( data )
  end
  def type
    # TODO must be overloaded
  end
end
class CloseFrame < Frame
  def type
    Frame::TYPE_CLOSE
  end
end
class WebSocket
  ST_BEFORE_START = :before_start
  ST_STARTING     = :starting
  ST_RUNNING      = :running
  ST_STOPPING     = :stopping
  ST_STOPPED      = :stopped
  def initialize( sock, event_listener )
    @sock = sock
    @listener = event_listener
    @state = ST_BEFORE_START
    @buf_for_normal_header      = ''
    @buf_for_ext_payload_length = ''
    @buf_for_mask = ''
    @buf_for_payload = ''
  end
  def start
    @state = ST_STARTING
    # TODO 2 回呼ばれた場合の処理
    begin
      @listener.onstart( self )
      while true
        frame = _read_frame
        p frame
        if frame.type == Frame::TYPE_CLOSE
          # まだ close フレームを送っていないなら送る
          _send_close_frame() if @state == ST_RUNNING
          break
        end
      end
    ensure
      # TODO どこで close フレーム送信をすべきか
      @listener.onclose( self )
    end
  end
  def send_text( str )
    # TODO implement
  end

  def _send_close_frame()
    @state = ST_STOPPING
    # とりあえず
    @sock << [ 0x88, 0x00 ].map{ |b| b.chr( Encoding::ASCII_8BIT ) }.join()
  end

  def _send_frame( frame )
    # TODO 複数スレッドからのアクセス時の挙動
  end

  EXT_PAYLOAD_SIZE_TABLE = { 126 => 2, 127 => 4 }
  def _read_frame
    @sock.read( 2, @buf_for_normal_header ) or raise 'io end'
    b1,b2 = @buf_for_normal_header.unpack( 'C2' )
    fin, rsv1, rsv2, rsv3 = [ 0x80, 0x40, 0x20, 0x10 ].map{ |i| ( b1 & i ) != 0 }
    opcode = b1 & 0x0F
    mask   = ( ( b2 & 0x80 ) != 0 )
    paylen = b2 & 0x7F
    if ext_payload_size = EXT_PAYLOAD_SIZE_TABLE[paylen]
      paylen = _read_ext_payload_length( ext_payload_size )
    end

    # mask
    @sock.read( 4, @buf_for_mask ) or raise 'io end'
    key_bytes = @buf_for_mask.unpack( 'C4' )
    @sock.read( paylen, @buf_for_payload ) or raise 'io end'
    #@buf_for_payload.unpack( 'C*' )
    key_byte_index = 0
    unmasked_bytes = ''
    unmasked_bytes.encode( Encoding::ASCII_8BIT )
    tmp_arr = []
    @buf_for_payload.each_byte do |b|
      unmasked_bytes << ( b ^ key_bytes[key_byte_index] ).chr( Encoding::ASCII_8BIT )
      ( key_byte_index += 1 ) < key_bytes.length or key_byte_index = 0
    end
    unmasked_bytes.force_encoding( Encoding::UTF_8 )
    $stderr << "[DEBUG] #{unmasked_bytes}\n"
    if opcode == Frame::TYPE_CLOSE
      CloseFrame.new
    else
      Frame.new
    end
  end

  EXT_PAYLOAD_TEMPLATE_TABLE = { 2 => 'n', 4 => 'N' }
  def _read_ext_payload_length( nbytes )
    t = EXT_PAYLOAD_TEMPLATE_TABLE[nbytes]
    @sock.read( nbytes, @buf_for_ext_payload_length ) or raise 'io end'
    @buf_for_ext_payload_length.unpack( t )
  end
end

#srv.mount('/hoge.pl', WEBrick::HTTPServlet::CGIHandler, 'really_executed_script.rb')
# シグナルをトラップして終了処理を行うように設定
shutdown_proc = ->( sig ){ server.shutdown() }
[ :INT, :TERM ].each{ |e| Signal.trap( e, &shutdown_proc ) }
server.start
