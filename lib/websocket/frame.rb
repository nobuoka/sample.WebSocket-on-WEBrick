# coding: UTF-8

require 'websocket'

module WebSocket
class Frame
  TYPE_CONTINUATION = 0x00
  TYPE_TEXT         = 0x01
  TYPE_CLOSE        = 0x08

  ##
  # 
  def self.create_frame( fin, r1, r2, r3, opcode, data )
    case opcode
    when TYPE_TEXT
      TextFrame.new( data, fin, r1, r2, r3 )
    when TYPE_CLOSE
      CloseFrame.new( data, fin, r1, r2, r3 )
    else
      raise 'not implemented yet'
    end
  end
  def initialize( data, fin, r1, r2, r3 )
    @data = data
    @fin  = fin
    @rsv1 = r1
    @rsv2 = r2
    @rsv3 = r3
  end
  def fin?; @fin end
  def data; @data end
  def to_binary_string
    bstr = ''
    b1 = [ @fin, @rsv1, @rsv2, @rsv3 ].
          inject( 0x00 ){|b,i| ( b << 1 ) | ( i ? 0x01 : 0x00 ) } << 4
    b1 |= self.type
    extlen = ''
    if ( len = @data.bytesize ) <= 125
      b2 = len
    elsif len <= 0xFFFF
      b2 = 126
      extlen = [ len ].pack( 'n' )
    elsif len <= 0x7FFFFFFF
      b2 = 127
      extlen = [ len ].pack( 'N' )
    else
      raise 'error'
    end
    bstr << [ b1, b2 ].pack( 'C2' )
    bstr << extlen
    bstr << @data
    return bstr
  end
end
class ControlFrame < Frame
  def is_data_frame?;    false end
  def is_control_frame?; true  end
end
class DataFrame < Frame
  def is_data_frame?;    true  end
  def is_control_frame?; false end
end
class CloseFrame < ControlFrame
  def type; TYPE_CLOSE end
end
class TextFrame < DataFrame
  def type; TYPE_TEXT end
end
end
