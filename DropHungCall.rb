#!/usr/local/bin/ruby

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
    puts "\n\n    Usage: ./get_mgs.rb <10 digit telephone number or extension> [options]\n\n"
    puts "    Only current supported option is to run this command with verbosity.\n"
    puts "    Verbosity displays all on going calls in all MGs we are currently traversing.\n\n"
    puts "        Options:\n        help, --help, -h,    Display this help messgage."
    puts "        verbose, --verbose, -h,    Display all ongoing calls in the Mgs we are currently traversing.\n\n"
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
        puts "Hanging up SIP channel on #{server}"
        tunnel(server, "soft hangup #{channel}")
      else
        puts "SIP channel [#{channel}] was not hung up. GOOD BYE!"
      end
    else
      puts "#{channel} is not a known SIP channel. GOOD BYE!"
    end
  end

  def tunnel(server, ast_command)
    begin
      Net::SSH.start(server, @username, :password => @password) do |ssh|
        @showCalls = ssh.exec!("#{ASTERISK_RX}'#{ast_command}'")
      end
    rescue
      puts "Unable to connect to #{server} using #{@username}/#{@password}"
    end
  end

  def asterisk_rx(number)
    #for @i in ["vhpbx0","vhpbx1","vhpbx2","vhpbx3","mg0","mg1","mg2","mg3","mg4","mg5","mg6"] do
    for server in ["mg0","mg1","mg2","mg3","mg4","mg5","mg6","pl-mg0", "pl-mg1"] do
      tunnel(server, 'core show channels verbose')
      if @showCalls.to_s.match(/SIP.*#{number}.*/)
        puts "#{@showCalls.to_s.match(/SIP.*#{number}.*/)}"
        wait_for_user_input("Enter a SIP channel to hangup: ")
        hangup_channel(server, @ans)
        @count = 0 # Re-initialize @count
      else
        @count = @count + 1
      end
      puts "Number not found!" if @count == 7
    end
  end

end

mgCheck = CheckMGsForHungCalls.new
mgCheck.asterisk_rx(ARGV[0])
