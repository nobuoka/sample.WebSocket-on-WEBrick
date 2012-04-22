# coding: UTF-8

require 'base64'
require 'websocket/server_agent'

module WEBrick
class HTTPResponse

  # evt_listener は onstart, onmessage, onerror, onclose メソッドが
  # 定義されたオブジェクト
  def upgrade_websocket( req, evt_listener )
    # TODO check
    p req['Connection']
    p req['Upgrade']

    #my %http_conn = map{ ( lc( $_ ), 1 ) } split ( / *, */, $env->{'HTTP_CONNECTION'} );
    #my %http_upgr = map{ ( lc( $_ ), 1 ) } split ( / *, */, $env->{'HTTP_UPGRADE'} );
    #unless ( $http_conn{'upgrade'} && $http_upgr{'websocket'} ) {
    #  $self->error_code(401);
    #  return;
    #}

    @websocket_event_listener = evt_listener
    res = self

    key = req['Sec-WebSocket-Key']
    raise 'no key' unless key # TODO check
    kk  = key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
    digest = Base64.strict_encode64( Digest::SHA1.digest( kk ) )

    res.status = WEBrick::HTTPStatus::RC_SWITCHING_PROTOCOLS # '101'
    res['Upgrade']    = 'websocket'
    res['Connection'] = 'Upgrade'
    res['Sec-WebSocket-Accept'] = digest

    def self.send_response(socket)
      begin
        setup_header()
        @header['connection'] = 'Upgrade'
        send_header(socket)
        #send_body(socket)
        # ここで WebSocket プロトコルを使う
        ws = WebSocket::ServerAgent.new( socket, @websocket_event_listener )
        ws.start() # on_start(), socket 読み取り開始
        # start が終わるのは通信が終わるとき
      rescue Errno::EPIPE, Errno::ECONNRESET, Errno::ENOTCONN => ex
        @logger.debug(ex)
        @keep_alive = false
      rescue Exception => ex
        @logger.error(ex)
        @keep_alive = false
      end
    end
  end

end
end
