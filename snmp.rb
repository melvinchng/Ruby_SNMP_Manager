require 'ascii_charts'
require 'snmp'
include SNMP

def asus_ac68u_interface_translate
  puts "Information about interface based on discussion in smallnetbuilder forum and observation. SNMP interface translate may not be 100% right."
  puts
  puts "================== Asus RT-AC68U Router ===================="
  puts "| Interface \t | Description                             |"
  puts "============================================================"
  puts "| lo      \t | local loopback (internal to router)     |"
  puts "| eth0    \t | Router chip: WAN, 2.4G, 5G, LAN         |"
  puts "| eth1    \t | 2.4GHz Wireless Interface               |"
  puts "| eth2    \t | 5.0GHz Wireless Interface               |"
  puts "| vlan1-2 \t | two seperate network (normal and guest) |"
  puts "| br0     \t | LAN bridge for vlan1, eth1, eth2        |"
  puts "| tun21   \t | VPN Server / Tunneling                  |"
  puts "============================================================"
end

#####################################################################################################################
# Info                                  # Description                                                               #
#####################################################################################################################
# host                                  # host                                                                      #
# community                             # community string                                                          #
# interval                              # how frequent data is captured                                             #
# output                                # print walk data (true/false)                                              #
# ifTable_columns                       # array of columns that want to walk                                        #
# position_of_octets                    # position of octet in ifTable_columns array (count from 0 from left)       #
#                                       # * to disable the checking, use very large number (99999)                  #
# position_of_ifDescr                   # position of descption in ifTable_columns array (count from 0 from left)   #
#                                       # * to disable the checking, use very large number (99999)                  #
# position_of_ipNetToMediaNetAddress    # position of descption in ifTable_columns array (count from 0 from left)   #
#                                       # * to disable the checking, use very large number (99999)                  #
#####################################################################################################################

def snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr, position_of_ipNetToMediaNetAddress)
  temp = []                                                               # temp array; to store values of octets
  interface = []                                                          # interface array; store the name of the interface
  interface_ip = []

  SNMP::Manager.open(:host => host, :community => community) do |manager| # open the connection
    manager.walk(ifTable_columns) do |row|                                # walk each interface and get ifTable_columns data
      row.each_with_index { |vb, index|                                   # begin for loop
        if output                                                         # if output == true
          print "\t#{vb.value}"                                           # print each ifTable_columns
        end                                                               # end for loop

        if index == position_of_ipNetToMediaNetAddress                    # if current index == position_of_ipNetToMediaNetAddress
          interface_ip << vb.value                                           # load the current interface ip to interface_ip array
        end                                                               # end if 
      
        if index == position_of_ifDescr                                   # if current index == position_of_ifDescr
          interface << vb.value                                           # load the current interface to interface array
        end                                                               # end if 

        if index == position_of_octets                                    # if current index == position_of_octets
          temp << vb.value                                                # load the current octets value to interface array
        end                                                               # end if
      }

      if output                                                           # if output is enabled
        puts                                                              # print new line
      end                                                                 # end if                                                                
    end                                                                   # end row
  end                                                                     # end walk

  return {:value => temp, :interface => interface, :interface_ip => interface_ip} # put the temp and interface in hash and return
end

def get_speed(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr, position_of_ipNetToMediaNetAddress)
  speed = []                                                              # array of speed to store the calculation of speed
  
  one = snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr, position_of_ipNetToMediaNetAddress)  # get hash and assign to one
  sleep interval                                                                                      # sleep for interval (second)
  two = snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr, position_of_ipNetToMediaNetAddress)  # get hash and assign to two

  one[:value].zip(two[:value]) { |a, b|                                   # load two hash, get values
    speed << (((b.to_f - a.to_f)*8)/(interval*1024*1024))                 # convert from interger to float, find the difference
                                                                          # between two same interface, multiply by 8 to get a byte
                                                                          # divide the values by interval (second) and convert to MB/s
  }

  return {:one => one, :two => two, :speed => speed}                      # return one, two, and speed hash
end

def plot_graph(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr, position_of_ipNetToMediaNetAddress)
  interface_with_speed = get_speed(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr, position_of_ipNetToMediaNetAddress)

  graph = []                                                              # array of graph, to get [[x_1, y_1], ... , [x_n, y_n]]

  interface_with_speed[:one][:interface].zip(interface_with_speed[:speed]) { |a, b| #get interface name, and speed
     graph << [a, b]                                                      # put it in the form of [x_n, y_n], assign it to graph
  }

  print AsciiCharts::Cartesian.new(graph, :bar => true, :hide_zero => false).draw  # draw graph
  puts "\t Plotting interface vs speed (MB/s) in #{interval}s interval"
end

def perform_plot_graph_operation                                          # Plot graph
  host = @host
  community = @community
  columns = ["ifDescr", "ifAdminStatus", "ifHCInOctets", "ifHCOutOctets"] #ifIndex not used as I made my own counter

  plot_graph(host, community, 5, false, columns, 2, 0, 99999)             # Set to 99999 as it is used to print IP interface
end

def list_all_interface
  host = @host
  community = @community
  columns = ["ipNetToMediaNetAddress"]

  get_result = snmp_walk(host, community, false, columns, 99999, 99999, 0) # Set to 99999 as it is used for graph operation

  i = 0

  puts "Interfaces"
  puts "########################################"
  puts "# Number \t # IP                  #"
  puts "########################################"
  get_result[:interface_ip].each do |a|                                    # Print row index and interface IP
    puts "# #{i=i+1} \t \t # #{a} " 
  end
  puts "########################################"
end

@host = "192.168.1.252"
@community = "public"

list_all_interface
perform_plot_graph_operation


# ifInOctets (1.3.6.1.2.1.2.2.1.10)/ifOutOctets (1.3.6.1.2.1.2.2.1.16) 
# (ifInOctets(time1) - ifInOctets(time2)) / (time2 - time1)
# (ifOutOctets(time1) - ifOutOctets(time2)) / (time2 - time1)

#snmp_get_next(host, community, ipNetToMediaNetAddress)

# https://serverfault.com/questions/401162/how-to-get-interface-traffic-snmp-information-for-routers-cisco-zte-huawei
# https://fineconnection.com/how-to-monitor-interface-traffic-utilization-or-bandwidth-usage-in-real-time-2/