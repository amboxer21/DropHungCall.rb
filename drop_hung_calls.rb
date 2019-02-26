#!/usr/local/ruby-2.2.7/bin/ruby

require 'net/ssh'
require 'ostruct'
require 'optparse'

class CheckMGsForHungCalls

  @@result  = {}
  @@channel = {'orphans': 'true', 'output': 'true'}  

  ASTERISK_RX = '/usr/sbin/asterisk -rx '
  CHANNEL = '\nSIP\/[\w\d-]+|\nDAHDI\/[\w\d-]+'

  def initialize(username="aguevara",password="LIMA peru 2")

    @orphans  = []
    @username = username
    @password = password
    @options  = OpenStruct.new

    @mgs = [
      "mg0","mg1","mg2","mg3","mg4","mg5","mg6","pl-mg0"
    ]

    OptionParser.new do |opt|

      @msg1 = 'Hung phone number to search for in the MGs.'
      @msg2 = 'This options displays long standing calls.'
      @msg3 = 'Return orphans that have been up longer than this specified hour.'

      opt.on('-nNUMBER', '--number NUMBER', Integer, @msg1) do |number|
        number.nil? ? usage('Please specify a phone number.') : (@options.number = number)
      end
      opt.on('-O','--orphans', TrueClass, @msg2) do |orphan|
        @options.orphans = orphan.nil? ? false : orphan
      end
      opt.on('-tHOUR', '--orphan-threshold HOUR', Integer, @msg3) do |hour|
        @options.hour = hour.nil? ? 5 : hour
      end
      opt.on("-h","--help", "Diaplay usage info.") do |help|
        usage  
      end
    end.parse!

  end

  def usage(message=nil)

    puts "\n    ** #{message} ** \n" unless message.nil? or message.empty?

    puts "\n\n    Usage: drop_hung_call.rb --number=NUMBER or -nNUMBER\n\n"
    puts "    Option:\n        help, --help, -h,    Display this help messgage.\n\n"
    puts "    Option:\n        orphans, --orphans, -O, This options displays long standing calls.\n\n"
    puts "    Option:\n        number, --number, -n,    Hung phone number to search for in the MGs.\n"
    puts "        This option does not have to be a 10 digit number and can even be an extension.\n\n"
    puts "    This script checks the following servers: #{@mgs.join(' ')}.\n\n"
    exit
  end

  def display_warning
    puts "\nWARNING! This script \"ONLY\" checks the following MG's: #{@mgs.join(' ')}.\n\n"
  end

  def threshold(hour)
    "[0-9][#{hour}-9]|[1-9][0-9]"
  end

  def orphaned_calls
    @@channel.each do |server,channel|
      chan = channel.scan(/(#{CHANNEL})(.*)(\s)(#{threshold(@options.hour)})(:\d+)(:\d+)(\s)(.*)\n/).join(' ')
      if @options.orphans and !chan.empty? 
        @@channel[:orphans] = 'false'
        (print "\n\n(Orphaned Calls)[Server] -> (#{server})"; puts chan)
      end
    end
    (puts "No orphaned calls were found."; return) if @@channel[:orphans].eql? 'true'
    puts "\n\n---------------------------------->\n\n"
  end

  def wait_for_user_input(prompt)
    print "#{prompt} "
    @ans = STDIN.gets.chomp
  end

  def hangup_channel(server, channel)
    if channel.to_s.match("SIP\/[A-Za-z0-9]+-[A-Za-z0-9]+")
      wait_for_user_input("Hangup channel -> [#{channel}](\"YES\")? ")
      if @ans.to_s.match("YES")
        tunnel(server, "soft hangup #{channel}")
      else
        puts "SIP channel [#{channel}] was not hung up. GOOD BYE!"
        exit
      end
    else
      puts "Channel(#{channel}) does not use proper format. GOOD BYE!"
      exit
    end
  end

  def tunnel(server, ast_command)
    begin
      Net::SSH.start(server, @username, :password => @password) do |ssh|
        if ast_command.match(/soft hangup/)
          @@result[server] = ssh.exec!("#{ASTERISK_RX}'#{ast_command}'")
        else
          @@channel[server] = ssh.exec!("#{ASTERISK_RX}'#{ast_command}'")
        end
      end
    rescue Exception => exception
      puts "Exception e => #{exception}"
    ensure
      @@result.each do |server,result|
        @@result.delete(server) if result.match(/is not a known channel/)
      end
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
      chan = channel.scan(/(#{CHANNEL})(.*)(\s|SIP\/)(#{@options.number})(\d+\s|\s|@)(.*)\n/).join(' ')
      unless chan.empty?
        @@channel[:output] = 'false'
        print "\n(#{@options.number})[Server] -> (#{server})\n"
        puts chan
      end
    end
    if @@channel[:output].eql? 'true' and @@channel[:orphans].eql? 'true'
      (puts "\n\nTelephone number #{@options.number} was NOT found!\n\n"; return)
    elsif @@channel[:output].eql? 'true' and @@channel[:orphans].eql? 'false'
      puts "\n\nTelephone number #{@options.number} was NOT found!\n\n"
    end
    wait_for_user_input("\nEnter a SIP channel to hangup: ")
    @@channel.each do |key,val|
      hangup_channel(key, @ans) if val =~ /#{@ans}/
    end
    unless @@result.empty?
      puts "(#{@@result.keys[0]}) -> #{@@result.values[0]}"
    else
      puts "Channel was not hung up because it is a known channel!"
    end
  end

end

mgCheck = CheckMGsForHungCalls.new
mgCheck.asterisk_rx('core show channels verbose')
mgCheck.orphaned_calls
mgCheck.parse_output
