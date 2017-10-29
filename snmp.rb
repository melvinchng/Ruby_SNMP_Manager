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
  puts "============================================================"
end

#######################################################################################################
# Info                    # Description                                                               #
#######################################################################################################
# host                    # host                                                                      #
# community               # community string                                                          #
# interval                # how frequent data is captured                                             #
# output                  # print walk data (true/false)                                              #
# ifTable_columns         # array of columns that want to walk                                        #
# position_of_octets      # position of octet in ifTable_columns array (count from 0 from left)       #
# position_of_ifDescr     # position of descption in ifTable_columns array (count from 0 from left)   #
#######################################################################################################

def snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr)
  temp = []                                                               # temp array; to store values of octets
  interface = []                                                          # interface array; store the name of the interface

  SNMP::Manager.open(:host => host, :community => community) do |manager| # open the connection
    manager.walk(ifTable_columns) do |row|                                # walk each interface and get ifTable_columns data
      row.each_with_index { |vb, index|                                   # begin for loop
        if output                                                         # if output == true
          print "\t#{vb.value}"                                           # print each ifTable_columns
        end                                                               # end for loop

        if index == position_of_ifDescr                                   # if current index == position_of_ifDescr
          interface << vb.value                                           # load the current interface to interface array
        end                                                               # end if 

        if index == position_of_octets                                    # if current index == position_of_octets
          temp << vb.value                                                # load the current octets value to interface array
        end                                                               # end if
      }
      puts                                                                # print new line
    end                                                                   # end row
  end                                                                     # end walk

  return {:value => temp, :interface => interface}                        # put the temp and interface in hash and return
end

def get_speed(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr)
  speed = []                                                              # array of speed to store the calculation of speed
  
  one = snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr)  # get hash and assign to one
  sleep interval                                                                                      # sleep for interval (second)
  two = snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr)  # get hash and assign to two

  one[:value].zip(two[:value]) { |a, b|                                   # load two hash, get values
    speed << (((b.to_f - a.to_f)*8)/(interval*1024*1024))                 # convert from interger to float, find the difference
                                                                          # between two same interface, multiply by 8 to get a byte
                                                                          # divide the values by interval (second) and convert to MB/s
  }

  return {:one => one, :two => two, :speed => speed}                      # return one, two, and speed hash
end

def plot_graph(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr)
  interface_with_speed = get_speed(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr)

  graph = []                                                              # array of graph, to get [[x_1, y_1], ... , [x_n, y_n]]

  interface_with_speed[:one][:interface].zip(interface_with_speed[:speed]) { |a, b| #get interface name, and speed
     graph << [a, b]                                                      # put it in the form of [x_n, y_n], assign it to graph
  }

  puts AsciiCharts::Cartesian.new(graph, :bar => true, :hide_zero => false).draw  # draw graph
end

host = "melvinchng.asuscomm.com"
community = "public"
ifTable_columns = ["ifIndex", "ifDescr", "ifAdminStatus", "ifHCInOctets", "ifHCOutOctets"]

plot_graph(host, community, 5, false, ifTable_columns, 3, 1)

# ifInOctets (1.3.6.1.2.1.2.2.1.10)/ifOutOctets (1.3.6.1.2.1.2.2.1.16) 
# (ifInOctets(time1) - ifInOctets(time2)) / (time2 - time1)
# (ifOutOctets(time1) - ifOutOctets(time2)) / (time2 - time1)

#snmp_get_next(host, community, ipNetToMediaNetAddress)

# https://serverfault.com/questions/401162/how-to-get-interface-traffic-snmp-information-for-routers-cisco-zte-huawei
# https://fineconnection.com/how-to-monitor-interface-traffic-utilization-or-bandwidth-usage-in-real-time-2/