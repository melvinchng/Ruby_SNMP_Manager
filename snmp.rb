require 'ascii_charts'
require 'snmp'
include SNMP

host = "melvinchng.asuscomm.com"
community = "public"

ipNetToMediaNetAddress = "1.3.6.1.2.1.4.22.1.3"
egpNeighTable = "1.3.6.1.2.1.8.5"
ifInOctets = "1.3.6.1.2.1.2.2.1.10" #ifTable > ifEntry > ifInOctets

def snmp_walk(host, community, output, ifTable_columns, position_of_octets, position_of_ifDescr)
  temp = []
  interface = []

  SNMP::Manager.open(:host => host, :community => community) do |manager|
    manager.walk(ifTable_columns) do |row|
      row.each_with_index { |vb, index| 
        if output
          print "\t#{vb.value}" 
        end

        if index == position_of_ifDescr
          interface << vb.value
        end

        if index == position_of_octets
          temp << vb.value
        end
      }
      puts
    end
  end

  return {:value => temp, :interface => interface}
end

def snmp_get_next(host, community, oid)
  puts "======== Network Interface ========"
  Manager.open(:host => host, :community => community) do |manager|
    oid = ObjectId.new(oid) #ipNetToMediaNetAddress Table
    next_oid = oid
    while next_oid.subtree_of?(oid)
      response = manager.get_next(next_oid)
      varbind = response.varbind_list.first
      next_oid = varbind.name
      puts varbind.value
    end
  end
end

# ifInOctets (1.3.6.1.2.1.2.2.1.10)/ifOutOctets (1.3.6.1.2.1.2.2.1.16) 
# (ifInOctets(time1) - ifInOctets(time2)) / (time2 - time1)
# (ifOutOctets(time1) - ifOutOctets(time2)) / (time2 - time1)

#snmp_get_next(host, community, ipNetToMediaNetAddress)

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

puts "TESTTTTTTTTTTTTTTTTTTTTTTTTTTTT"

#puts one.inspect
#puts two.inspect

def get_speed(host, community)

  ifTable_columns = ["ifIndex", "ifDescr", "ifAdminStatus", "ifHCInOctets", "ifHCOutOctets"]
  
  interval = 1
  one = snmp_walk(host, community, true, ifTable_columns, 3, 1)
  sleep interval
  two = snmp_walk(host, community, false, ifTable_columns, 3, 1)

  speed = []

  one[:value].zip(two[:value]) { |a, b|
    speed << (((b.to_f - a.to_f)*8)/(interval*1024*1024)).round(4)
  }

  return {:one => one, :two => two, :speed => speed}
end


# https://serverfault.com/questions/401162/how-to-get-interface-traffic-snmp-information-for-routers-cisco-zte-huawei
# https://fineconnection.com/how-to-monitor-interface-traffic-utilization-or-bandwidth-usage-in-real-time-2/

#puts AsciiCharts::Cartesian.new([[0, 1], [1, 3], [2, 7], [3, 15], [4, 4]], :bar => true, :hide_zero => true).draw



def plot_graph(host, community)
  interface_with_speed = get_speed(host, community)

  graph = []

  interface_with_speed[:one][:interface].zip(interface_with_speed[:speed]) { |a, b|
     graph << [a, b]
  }

  puts AsciiCharts::Cartesian.new(graph, :bar => true, :hide_zero => false).draw
end

plot_graph(host, community)