#!/bin/bash

# Update and Upgrade Packages
apt update -y && apt upgrade -y

# -----------------------
# ⁠Create Network Bridges
# -----------------------

ip link add br0 type bridge
ip link add br1 type bridge

# -------------------------
# Create Three Separate Network Namespaces
# -------------------------

ip netns add ns0
ip netns add ns1
ip netns add router-ns

# Verify namespace creation
ip netns

# -----------------------------------------
# Create Virtual Interfaces and Connections
# -----------------------------------------

# Create appropriate virtual ethernet (veth) pairs
ip link add v-ns0-ns type veth peer name v-ns0
ip link add v-ns1-ns type veth peer name v-ns1

ip link add vr-ns0 type veth peer name vr-ns0-ns
ip link add vr-ns1 type veth peer name vr-ns1-ns

# Connect interfaces to correct namespaces
ip link set v-ns0-ns netns ns0
ip link set v-ns1-ns netns ns1

ip link set vr-ns0-ns netns router-ns
ip link set vr-ns1-ns netns router-ns

# Connect interfaces to appropriate bridges
ip link set v-ns0 master br0
ip link set v-ns1 master br1

ip link set vr-ns0 master br0
ip link set vr-ns1 master br1

# -------------------------------------------------
# Ensure interfaces are properly configuns0 and active
# -------------------------------------------------

# Bring bridges UP
ip link set br0 up
ip link set br1 up

# Bring NICs UP
ip link set v-ns0 up
ip link set v-ns1 up
ip link set vr-ns0 up
ip link set vr-ns1 up

ip netns exec ns0 ip link set v-ns0-ns up
ip netns exec ns1 ip link set v-ns1-ns up

ip netns exec router-ns ip link set vr-ns0-ns up
ip netns exec router-ns ip link set vr-ns1-ns up

# ----------------------
# Configure IP Addresses
# ----------------------

# Assign appropriate IP addresses to all interfaces
# Ensure proper subnet configuration

# Assign IPs to bridges
ip addr add 10.11.0.1/24 dev br0
ip addr add 10.12.0.1/24 dev br1

# Assign IPs to NICs
ip netns exec ns0 ip addr add 10.11.0.2/24 dev v-ns0-ns
ip netns exec router-ns ip addr add 10.11.0.3/24 dev vr-ns0-ns

ip netns exec ns1 ip addr add 10.12.0.2/24 dev v-ns1-ns
ip netns exec router-ns ip addr add 10.12.0.3/24 dev vr-ns1-ns

# ------------------
# Add Default Routes
# ------------------

ip netns exec ns0 ip route add 10.12.0.0/24 via 10.11.0.3 dev v-ns0-ns
ip netns exec ns1 ip route add 10.11.0.0/24 via 10.12.0.3 dev v-ns1-ns

# --------------------
# Enable IP Forwarding
# --------------------

ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1
ip netns exec router-ns iptables -P FORWARD DROP # Control forwarding with rules


# ---------------------
# Add Rules To iptables
# ---------------------

iptables --append FORWARD --in-interface br0 --jump ACCEPT
iptables --append FORWARD --out-interface br0 --jump ACCEPT

iptables -A FORWARD --in-interface br1 -j ACCEPT
iptables -A FORWARD --out-interface br1 -j ACCEPT

ip netns exec router-ns iptables --append FORWARD --in-interface vr-ns0-ns --jump ACCEPT
ip netns exec router-ns iptables --append FORWARD --out-interface vr-ns0-ns --jump ACCEPT

ip netns exec router-ns iptables --append FORWARD --in-interface vr-ns1-ns --jump ACCEPT
ip netns exec router-ns iptables --append FORWARD --out-interface vr-ns1-ns --jump ACCEPT

# -----------------
# Test Connectivity
# -----------------

ip netns exec ns0 ping 10.12.0.2 -c 3
ip netns exec ns1 ping 10.11.0.2 -c 3

# ----------------------------------
# Cleanup The Bridges and Namespaces
# ----------------------------------

# ip link del br0
# ip link del br1

# ip netns del router-ns
# ip netns del ns0
# ip netns del ns1