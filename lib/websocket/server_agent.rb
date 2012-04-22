# coding: UTF-8

require 'websocket'
require 'websocket/frame'

module WebSocket
class ServerAgent

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
    @buf_for_mask               = ''
    @buf_for_payload            = ''
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
end
