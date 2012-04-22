# coding: UTF-8

require 'websocket'

module WebSocket
class Frame
  TYPE_TEXT  = :text
  TYPE_CLOSE = 0x08 #:close
  def self.create_text_frame( data )
  end
  def type
    # TODO must be overloaded
  end
end
class WebSocket::CloseFrame < WebSocket::Frame
  def type
    TYPE_CLOSE
  end
end
end
