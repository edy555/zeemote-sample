#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'rubygems'
require 'eventmachine'
require 'em-websocket'

PORT = 7857
HOST = "localhost"

device = "/dev/tty.ZeemoteJS1H-ZeemoteSPP"
fd = File.open(device, "rb")

module Zeemote
  SIGNATURE = 0xa1
  MSGTYPE_BUTTON = 7
  MSGTYPE_STICK = 8
  FILLING = -2

  def onstick(&blk); @onstick = blk; end
  def onbutton(&blk); @onbutton = blk; end

  def receive_data data
    len, sig, type, arg = data.unpack("CCCa*")
    return unless sig == SIGNATURE

    case type
    when MSGTYPE_STICK
      arg = arg.unpack "xcc"
      @onstick.call(arg) if @onstick
    when MSGTYPE_BUTTON
      arg = arg.unpack "c*"
      arg.delete FILLING
      @onbutton.call(arg) if @onbutton
    end
  end
end

EM::run do
  puts "start websocket server - port:#{PORT}"
  @channel = EM::Channel.new

  EM::attach(fd, Zeemote) do |z|
    z.onbutton {|arg|
      data = "button " + arg.join(" ")
      @channel.push(data)
      p data
    }
    z.onstick {|arg|
      data = "stick " + arg.join(" ")
      @channel.push(data)
      p data
    }
  end

  EM::WebSocket.start(:host => HOST, :port => PORT) do |ws|
    ws.onopen {
      sid = @channel.subscribe {|mes|
        ws.send(mes)
      }
      puts "<#{sid}> connected!!"

      ws.onclose {
        puts "<#{sid}> disconnected"
        @channel.unsubscribe(sid)
      }
    }
  end
end
