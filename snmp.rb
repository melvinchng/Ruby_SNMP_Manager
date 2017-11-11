require 'ascii_charts'
require 'terminal-table'
require 'snmp'
require 'benchmark'
include SNMP

def snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr, position_of_ipNetToMediaNetAddress, 
              position_of_ipNetToMediaIfIndex, position_of_ipAdEntAddr)
  temp = []                                                               # temp array; to store values of octets
  interface_name = []                                                     # interface array; store the name of the interface
  neighbor_ip = []                                                        # store all neighbor IP
  interface_ip = []                                                       # store all interface IP
  interface = []                                                          # store interface for neighbor


  SNMP::Manager.open(:host => host, :community => community) do |manager| # open the connection
    time = Benchmark.measure {    
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
  }
  
    #puts time.real
  end                                                                     # end walk


  return {:value => temp, :interface_name => interface_name, :neighbor_ip => neighbor_ip, :interface => interface, :interface_ip => interface_ip} # put in hash and return
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

  begin
    Timeout::timeout(interval*1.5) do   # will timeout if there is an error
      print AsciiCharts::Cartesian.new(graph, :bar => true, :hide_zero => false).draw  # draw graph
      puts "Graph of speed (MB/s) vs All interface's traffic with #{interval*1.5}s sampling rate"
    end
  rescue
      puts "Error plotting graph for all interface; Unable to Graph Due to No Activity"
  end
end

def perform_plot_graph_operation                                                           # Plot graph
  columns = ["ifDescr", "ifHCInOctets", "ifHCOutOctets"]                                   # ifIndex not used as I made my own counter

  plot_graph(@host, @community, @interval*5, false, columns, 1, 0, nil, nil, nil)             # Set to nil as it is used to print IP interface
end

def get_all_interface_name
  count = 0

  ifTable_columns = ["ifIndex", "ifDescr", "ifInOctets", "ifOutOctets"]                     # Perform SNMP Walk to get all the columns
  SNMP::Manager.open(:host => @host, :community => @community) do |manager|
      manager.walk(ifTable_columns) do |row|                                                # Walk the table and print the values
          row.each { |vb| print "\t#{vb.value}" }
          puts

          count = count + 1
      end
  end

  return count
end

def get_system_information                                                     # Print system information
  host = @host
  community = @community

  puts "################## SYS INFORMATION BEGIN #####################"
  puts 

  SNMP::Manager.open(:host => host, :community => community) do |manager|
    response = manager.get(["sysDescr.0", "sysName.0", "sysLocation.0", "sysContact.0"])
    response.each_varbind do |vb|
      puts "#{vb.name.to_s}  #{vb.value.to_s}  #{vb.value.asn1_type}"          # Print system infromation
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
  rows = []

  get_result = snmp_walk(host, community, false, columns, nil, nil, nil, nil, 0) # Set to nil as it is used for graph operation

  i = 0

  get_result[:interface_ip].each do |a|
    rows <<  [ i=i+1, a ] 
  end 

  # Print interface IP
  puts Terminal::Table.new :title => "Interfaces", :headings => ['Number', 'IP'], :rows => rows
end

def list_all_neighbor
  host = @host
  community = @community
  columns = ["ipNetToMediaNetAddress", "ipNetToMediaIfIndex"]
  rows = []

  get_result = snmp_walk(host, community, false, columns, nil, nil, 0, 1, nil) # Set to nil as it is used for graph operation

  get_result[:interface].zip(get_result[:neighbor_ip]) { |a, b|                # Put the information into rows to be printed in table
    rows << [a, b]
  }

  # Print interface number and neightbor IP
  puts Terminal::Table.new :title => "Neighbors", :headings => ['Interface', 'Neighbor'], :rows => rows
end

def snmp_get(host, community, columns)                                        # SNMP Get Operation
  SNMP::Manager.open(:host => host, :community => community) do |manager|
    response = manager.get(columns)
    response.each_varbind do |vb|
        return vb.value.to_f 
    end
  end
end

def get_speed_using_snmp_get(community, host, column, interval, iteration)
  graph = []
  i = 0

  while i <= iteration
    a = snmp_get(host, community, column)
    sleep interval                                                            # sleep for interval of time
    b = snmp_get(host, community, column)

    graph << [i*interval, ((b - a)*8)/(interval*1024*1024)]                   # Calculate the speed and put into x_1, y_1 so that
                                                                              # it can be added to graph array
    i = i+1
  end
  
  print AsciiCharts::Cartesian.new(graph, :bar => true, :hide_zero => false).draw  # draw graph
end
  
def perform_plot_graph_operation_with_all_interface
  puts
  puts "Printing all Interfaces and the Corresponding Speed"

  puts "\t ===================== Down Stream ===================="
  puts 
  puts "\tInterf\tName\tifInOcters\tifOutHCOtets"
  puts

  for i in 1..get_all_interface_name
    begin
      Timeout::timeout((@interval*@iteration)*1.5) do   # will timeout if there is an error
        get_speed_using_snmp_get(@community, @host, ["ifHCInOctets."+i.to_s], @interval, @iteration)
        puts "Graph of speed (MB/s) vs interface #{i} traffic with #{@interval}s sampling rate"
        puts
      end
    rescue
        puts "Error plotting "+i.to_s+"; Unable to Graph Downstream Due to No Activity"
        next    # do_something* again, with the next i
    end
  end

  puts
  puts "\t ====================== Up Stream ===================="
  puts 
  puts "\tInterf\tName\tifInOcters\tifOutHCOtets"
  puts

  for i in 1..get_all_interface_name
    begin
      Timeout::timeout((@interval*@iteration)*1.5) do   # will timeout if there is an error
        get_speed_using_snmp_get(@community, @host, ["ifHCOutOctets."+i.to_s], @interval, @iteration)
        puts "Graph of speed (MB/s) vs interface #{i} traffic with #{@interval}s sampling rate"
        puts
      end
    rescue
        puts "Error plotting "+i.to_s+"; Unable to Graph Upstream Due to No Activity"
        next    # do_something* again, with the next i
    end
  end
end

############################ DATA ANALYSIS SECTION ################################

def traffic_accuracy_analysis(community, host, column, interval, iteration)
  i = 0

  puts "Benchmark for SNMP Get"

  while i <= iteration
    time = Benchmark.measure {                                                      # Perform benchark for SNMP Get for analysis
      print snmp_get(host, community, column)                                       # Print the information of get operation
    }
    print "\t#{time}"                                                               # Print the time taken for one iteration

    i = i+1
  end
end

############################## PROGRAM SECTION #####################################

# get_system_information
# list_all_interface
# list_all_neighbor
# perform_plot_graph_operation
# perform_plot_graph_operation_with_all_interface

################################ USER INPUT #######################################

# Default values
# @interval = 0.5
# @iteration = 10
# @host = "192.168.1.252"
# @community = "public"

loop do
  puts "What is your host?"
  @host = gets
  @host = @host.chomp

  puts "What is your community string?"
  @community = gets
  @community = @community.chomp

  puts "What is the interval of sampling?"
  @interval = gets
  @interval = @interval.chomp.to_f

  puts "What is the iteration of sampling?"
  @iteration = gets
  @iteration = @iteration.chomp.to_f

  get_system_information
  list_all_interface
  list_all_neighbor
  perform_plot_graph_operation
  perform_plot_graph_operation_with_all_interface

  traffic_accuracy_analysis(@community, @host, ["ifHCInOctets.6"], @interval, @iteration)  
end