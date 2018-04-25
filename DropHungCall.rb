#!/usr/local/ruby-2.2.7/bin/ruby

require 'net/ssh'

class CheckMGsForHungCalls

  ASTERISK_RX = '/usr/sbin/asterisk -rx '
  
  def initialize(username="your username goes here",password="your password goes here",count=0)

    @count    = count
    @username = username
    @password = password

    usage if ARGV[0].nil?
    $arg0 = ARGV[0]

    case $arg0
      when "help", "--help", "-h"
        usage
    end
  end

  def usage
    puts "\n\n    Usage: drop_hung_call.rb <10 digit telephone number or extension>\n\n"
    puts "    Only current supported option is help.\n"
    puts "        Options:\n        help, --help, -h,    Display this help messgage.\n\n"
    exit
  end

  def wait_for_user_input(prompt)
    print "#{prompt} "
    @ans = STDIN.gets.chomp
  end

  def hangup_channel(server, channel)
    if channel.to_s.match("SIP\/[0-9a-z]+-[0-9a-z]+")
      wait_for_user_input("Hangup channel -> [#{channel}](\"YES\")? ")
      if @ans.to_s.match("YES")
        tunnel(server, "soft hangup #{channel}")
      else
        puts "SIP channel [#{channel}] was not hung up. GOOD BYE!"
      end
    else
      puts "#{channel} is not a known SIP channel. GOOD BYE!"
      exit
    end
  end

  @@channel = {}
  def tunnel(server, ast_command)
    begin
      Net::SSH.start(server, @username, :password => @password) do |ssh|
        @@channel[server] = ssh.exec!("#{ASTERISK_RX}'#{ast_command}'")
      end
    rescue Exception => e
      puts "Exception e => #{e}"
      puts "Unable to connect to #{server} using #{@username}/#{@password}"
    end
  end

  def asterisk_rx(number)
    #for s in ["mg0","mg1","mg2","mg3","mg4","mg5","mg6","pl-mg0", "pl-mg1"] do
    for s in ["mg0","mg1","mg2","mg3","mg4","mg5","mg6","pl-mg0"] do
      tunnel(s, 'core show channels verbose')
    end
    @@channel.each do |server,channel|
      if channel =~ /SIP.*#{number}.*/
        @count = 0 # Re-initialize @count
        (print "(Server)[#{server}] "; puts channel.scan(/SIP.*#{number}.*/))
      else
        @count += 1
      end
      (puts "Telephone number #{number} not found!"; return) if @count == 8
    end
    wait_for_user_input("Enter a SIP channel to hangup: ")
    @@channel.each do |key,val|
      hangup_channel(key, @ans) if val =~ /#{@ans}/
    end
  end

end

mgCheck = CheckMGsForHungCalls.new
mgCheck.asterisk_rx(ARGV[0])
