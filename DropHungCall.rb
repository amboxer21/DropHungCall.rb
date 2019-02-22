#!/usr/local/ruby-2.2.7/bin/ruby

require 'net/ssh'

class CheckMGsForHungCalls

  ASTERISK_RX = '/usr/sbin/asterisk -rx '

  def initialize(username="username",password="password")

    @username = username
    @password = password

    @mgs = [
      "mg0","mg1","mg2","mg3","mg4","mg5","mg6","pl-mg0"
    ]

    usage if ARGV[0].nil?
    @number = ARGV[0]

    case @number
      when "help", "--help", "-h"
        usage
    end
  end

  def usage
    puts "\n\n    Usage: drop_hung_call.rb <10 digit telephone number or extension>\n\n"
    puts "    Only current supported option is help.\n"
    puts "        Options:\n        help, --help, -h,    Display this help messgage.\n\n"
    puts "    This script checks the following servers: #{@mgs.join(' ')}.\n\n" 
    exit
  end

  def display_warning
    puts "\nWARNING! This script \"ONLY\" checks the following MG's: #{@mgs.join(' ')}.\n\n"
  end

  def orphaned_calls(channel)
    puts channel if channel =~ (/[1-9]\d+:\d+:\d+/)
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

  @@channel = {'exit': true}
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

  def asterisk_rx(command)
    display_warning
    for server in @mgs do
      tunnel(server, command)
    end
  end

  def parse_output
    @@channel.each do |server,channel|
      #orphaned_calls(channel)
      if channel =~ /^(PJSIP|SIP).*#{@number}.*\b/
        @@channel[:exit] = false
        (print "\n(Server)[#{server}]\n"; puts channel.scan(/SIP.*#{@number}.*/))
      end
    end
    (puts "Telephone number #{@number} was NOT found!"; return) if @@channel[:exit]
    wait_for_user_input("Enter a SIP channel to hangup: ")
    @@channel.each do |key,val|
      hangup_channel(key, @ans) if val =~ /#{@ans}/
    end
  end

end

mgCheck = CheckMGsForHungCalls.new
mgCheck.asterisk_rx('core show channels verbose')
mgCheck.parse_output
