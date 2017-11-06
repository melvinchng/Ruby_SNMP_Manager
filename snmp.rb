require 'ascii_charts'
require 'snmp'
include SNMP

def snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr, position_of_ipNetToMediaNetAddress, 
              position_of_ipNetToMediaIfIndex, position_of_ipAdEntAddr)
  temp = []                                                               # temp array; to store values of octets
  interface_name = []                                                     # interface array; store the name of the interface
  neighbor_ip = []                                                        # store all neighbor IP
  interface_ip = []                                                       # store all interface IP
  interface = []                                                          # store interface for neighbor

  SNMP::Manager.open(:host => host, :community => community) do |manager| # open the connection
    manager.walk(ifTable_columns) do |row|                                # walk each interface and get ifTable_columns data
      row.each_with_index { |vb, index|                                   # begin for loop
        if output == true                                                 # if output == true
          print "\t#{vb.value}"                                           # print each ifTable_columns
        end                                                               # end for loop

        if index == position_of_ipNetToMediaNetAddress                    # if current index == position_of_ipNetToMediaNetAddress
          neighbor_ip << vb.value                                         # load the current neighbor ip to neighbor_ip array
        end                                                               # end if 
      
        if index == position_of_ipAdEntAddr                               # if current index == position_of_ipAdEntAddr
          interface_ip << vb.value                                        # load the current interface ip to interface_ip array
        end                                                               # end if
      
        if index == position_of_ifDescr                                   # if current index == position_of_ifDescr
          interface_name << vb.value                                      # load the current interface to interface array
        end                                                               # end if 

        if index == position_of_octets                                    # if current index == position_of_octets
          temp << vb.value                                                # load the current octets value to interface array
        end                                                               # end if

        if index == position_of_ipNetToMediaIfIndex                       # if current index == position_of_octets
          interface << vb.value                                           # load the current octets value to interface array
        end                                                               # end if
      }

      if output == true                                                   # if output is enabled
        puts                                                              # print new line
      end                                                                 # end if                                                                
    end                                                                   # end row
  end                                                                     # end walk

  return {:value => temp, :interface_name => interface_name, :neighbor_ip => neighbor_ip, :interface => interface, :interface_ip => interface_ip} # put the temp and interface in hash and return
end

def get_speed(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr, 
              position_of_ipNetToMediaNetAddress, position_of_ipNetToMediaIfIndex, position_of_ipAdEntAddr)
  speed = []                                                                # array of speed to store the calculation of speed
  
  one = snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr, 
                  position_of_ipNetToMediaNetAddress, position_of_ipNetToMediaIfIndex, position_of_ipAdEntAddr)  # get hash and assign to one
  sleep interval                                                                                                 # sleep for interval (second)
  two = snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr, 
                  position_of_ipNetToMediaNetAddress, position_of_ipNetToMediaIfIndex, position_of_ipAdEntAddr)  # get hash and assign to two

  if one.count == two.count      
    one[:value].zip(two[:value]) { |a, b|                                   # load two hash, get values
      speed << (((b.to_f - a.to_f)*8)/(interval*1024*1024))                 # convert from interger to float, find the difference
                                                                            # between two same interface, multiply by 8 to get a byte
                                                                            # divide the values by interval (second) and convert to MB/s
    }
  else
    abort("Some interfaces are down in sampling!")
  end

  return {:one => one, :two => two, :speed => speed}                      # return one, two, and speed hash
end

def plot_graph(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr, 
              position_of_ipNetToMediaNetAddress, position_of_ipNetToMediaIfIndex, position_of_ipAdEntAddr)

  interface_with_speed = get_speed(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr, 
                                   position_of_ipNetToMediaNetAddress, position_of_ipNetToMediaIfIndex, position_of_ipAdEntAddr)

  graph = []                                                              # array of graph, to get [[x_1, y_1], ... , [x_n, y_n]]

  interface_with_speed[:one][:interface_name].zip(interface_with_speed[:speed]) { |a, b| #get interface name, and speed
     graph << [a, b]                                                      # put it in the form of [x_n, y_n], assign it to graph
  }

  print AsciiCharts::Cartesian.new(graph, :bar => true, :hide_zero => false).draw  # draw graph
  puts
  puts "\t Graph of speed (MB/s) vs interface's traffic with #{interval}s sampling rate"
end

def plot_graph_interface(host, community, interval, iteration, interface, output, ifTable_columns, position_of_octets, 
                         position_of_ifDescr, position_of_ipNetToMediaNetAddress, position_of_ipNetToMediaIfIndex, 
                         position_of_ipAdEntAddr)
  
  interface_with_speed = []
  graph = []                                                              # array of graph, to get [[x_1, y_1], ... , [x_n, y_n]]
  i = 0

  while i <= iteration  do
    interface_with_speed[i] = get_speed(host, community, interval, output, ifTable_columns, position_of_octets, position_of_ifDescr, 
                                        position_of_ipNetToMediaNetAddress, position_of_ipNetToMediaIfIndex, position_of_ipAdEntAddr)
    
      a = i*interval
      graph << [a, interface_with_speed[i][:speed][interface]]
      
    i += 1
  end

  print AsciiCharts::Cartesian.new(graph, :bar => true, :hide_zero => false).draw  # draw graph
  puts
  puts "\tGraph of speed (MB/s) vs traffic for #{interface_with_speed[0][:one][:interface_name][interface]} with #{interval}s sampling rate \n\t\t\t\tfor #{iteration} iterations"
end

def perform_plot_graph_operation                                          # Plot graph
  host = @host                      
  community = @community
  interval = @interval*5
  iteration = @iteration

  columns = ["ifDescr", "ifHCInOctets", "ifHCOutOctets"] #ifIndex not used as I made my own counter

  plot_graph(host, community, interval, false, columns, 1, 0, 99999, 99999, 99999)             # Set to 99999 as it is used to print IP interface
end

def perform_plot_graph_operation_interval                                 # Plot graph
  host = @host
  community = @community
  interval = @interval
  iteration = @iteration

  columns = ["ifDescr", "ifHCInOctets", "ifHCOutOctets"] #ifIndex not used as I made my own counter


  puts
  puts "\t ================ Downstream ================="
  plot_graph_interface(host, community, interval, iteration, 3, false, columns, 1, 0, 99999, 99999, 99999)  # Set to 99999 as it is used to print IP interface
  puts
  puts "\t ================= Upstream =================="
  plot_graph_interface(host, community, interval, iteration, 3, false, columns, 2, 0, 99999, 99999, 99999)  # Set to 99999 as it is used to print IP interface
end

def get_system_information
  host = @host
  community = @community

  puts "################## SYS INFORMATION BEGIN #####################"
  puts 

  SNMP::Manager.open(:host => host, :community => community) do |manager|
    response = manager.get(["sysDescr.0", "sysName.0", "sysLocation.0", "sysContact.0"])
    response.each_varbind do |vb|
      puts "#{vb.name.to_s}  #{vb.value.to_s}  #{vb.value.asn1_type}"
    end
  end

  puts 
  puts "################## SYS INFORMATION END #######################"
  puts
end

def list_all_interface
  host = @host
  community = @community
  columns = ["ipAdEntAddr"]

  get_result = snmp_walk(host, community, false, columns, 99999, 99999, 99999, 99999, 0) # Set to 99999 as it is used for graph operation

  i = 0

  puts "Interface"
  puts "#########################################"
  puts "# Number \t # IP                   #"
  puts "#########################################"
  get_result[:interface_ip].each do |a|
    puts "# #{i=i+1} \t \t # #{a}  \t#" 
  end 
  puts "#########################################"
  puts

end

def list_all_neighbor
  host = @host
  community = @community
  columns = ["ipNetToMediaNetAddress", "ipNetToMediaIfIndex"]

  get_result = snmp_walk(host, community, false, columns, 99999, 99999, 0, 1, 99999) # Set to 99999 as it is used for graph operation

  puts "Neighbor"
  puts "#########################################"
  puts "# Interface \t # Neighbor             #"
  puts "#########################################"
  get_result[:interface].zip(get_result[:neighbor_ip]) { |a, b| 
    puts "# #{a}  \t \t # #{b} \t#" 
  }
  puts "#########################################"

end

@interval = 0.5
@iteration = 10
@host = "192.168.1.252"
@community = "public"

get_system_information
list_all_interface
list_all_neighbor
perform_plot_graph_operation
perform_plot_graph_operation_interval


# ifInOctets (1.3.6.1.2.1.2.2.1.10)/ifOutOctets (1.3.6.1.2.1.2.2.1.16) 
# (ifInOctets(time1) - ifInOctets(time2)) / (time2 - time1)
# (ifOutOctets(time1) - ifOutOctets(time2)) / (time2 - time1)

#snmp_get_next(host, community, ipNetToMediaNetAddress)

# https://serverfault.com/questions/401162/how-to-get-interface-traffic-snmp-information-for-routers-cisco-zte-huawei
# https://fineconnection.com/how-to-monitor-interface-traffic-utilization-or-bandwidth-usage-in-real-time-2/