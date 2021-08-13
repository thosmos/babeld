#!/usr/bin/env bash
set -eux

BABELPATH=${BABELPATH:=../babeld}
LABPATH=${LABPATH:=./network-lab.sh}

# This is a basic integration test for the Althea fork of Babeld, it focuses on
# validating that instances actually come up and communicate

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root :("
   exit 1
fi

fail_string()
{
 if grep  "$1" "$2"; then
   echo "FAILED: $1 in $2"
   exit 1
 fi
}

pass_string()
{
 if ! grep "$1" "$2"; then
   echo "FAILED: $1 not in $2"
   exit 1
 fi
}

cleanup()
{
 set +eux
  kill -9 $(cat babeld-n1.pid)
  kill -9 $(cat babeld-n2.pid)
  kill -9 $(cat babeld-n3.pid)
  kill -9 $(cat babeld-n4.pid)
  rm -f babeld-n*
 set -eux
}

cleanup

 source $LABPATH << EOF
{
  "nodes": {
    "1": { "ip": "1.0.0.1" },
    "2": { "ip": "1.0.0.2" },
    "3": { "ip": "1.0.0.3" },
    "4": { "ip": "1.0.0.4" }
},
  "edges": [
     {
      "nodes": ["1", "2"],
      "->": "",
      "<-": ""
     },
     {
      "nodes": ["2", "3"],
      "->": "",
      "<-": ""
     },
     {
      "nodes": ["3", "4"],
      "->": "",
      "<-": ""
     },
     {
      "nodes": ["4", "1"],
      "->": "",
      "<-": ""
     }
  ]
}
EOF


cat << EOF
         ======== TOPOLOGY ========

     ,---- netlab-2 (price \$10) -----,
    /                                  \\
   /                                    \\
netlab-1 (price \$5)                 netlab-3 (price \$1)
   \\                                    /
    \\                                  /
     \`---- netlab-4 (price \$7) ------\`

EOF

ip netns exec netlab-1 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-1 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-1 $BABELPATH -I babeld-n1.pid -d 1 -L babeld-n1.log -F 5 \
  -w veth-1-4 -w veth-1-2 -h 1 -H 1 -C "default update-interval 1" -a 0 &

ip netns exec netlab-2 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-2 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-2 $BABELPATH -I babeld-n2.pid -d 1 -L babeld-n2.log -F 10 \
  -w veth-2-1 -w veth-2-3 -h 1 -H 1 -C "default update-interval 1" -a 0 &

ip netns exec netlab-3 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-3 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-3 $BABELPATH -I babeld-n3.pid -d 1 -L babeld-n3.log -F 1 \
  -w veth-3-2 -w veth-3-4 -h 1 -H 1 -C "default update-interval 1" -a 0 &

ip netns exec netlab-4 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-4 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-4 $BABELPATH -I babeld-n4.pid -d 1 -L babeld-n4.log -F 7 \
  -w veth-4-3 -w veth-4-1 -h 1 -H 1 -C "default update-interval 1" -a 0&

sleep 5

# Rule out obvious Babel message problems
fail_string "malformed" "babeld-n1.log"
fail_string "malformed" "babeld-n2.log"
fail_string "malformed" "babeld-n3.log"
fail_string "malformed" "babeld-n4.log"
fail_string "unknown version" "babeld-n1.log"
fail_string "unknown version" "babeld-n2.log"
fail_string "unknown version" "babeld-n3.log"
fail_string "unknown version" "babeld-n4.log"

# ============================ PRICE TESTS =====================================

# Note: suboptimal routes are commented out due to ridiculous amount time it
# takes for them to appear.

pass_string "1.0.0.3/32 from.*price 7 fee 5.*via veth-1-4.*nexthop 1.0.0.4" "babeld-n1.log"
#pass_string "1.0.0.3/32 from.*price 10 fee 5.*via veth-1-2.*nexthop 1.0.0.2" "babeld-n1.log"

pass_string "1.0.0.4/32 from.*price 0 fee 5.*via veth-1-4.*nexthop 1.0.0.4" "babeld-n1.log"
#pass_string "1.0.0.4/32 from.*price 11 fee 5.*via veth-1-2.*nexthop 1.0.0.2" "babeld-n1.log"

# netlab-2
pass_string "1.0.0.1/32 from.*price 0 fee 10.*via veth-2-1.*nexthop 1.0.0.1" "babeld-n2.log"
#pass_string "1.0.0.1/32 from.*price 8 fee 10.*via veth-2-3.*nexthop 1.0.0.3" "babeld-n2.log"

pass_string "1.0.0.3/32 from.*price 0 fee 10.*via veth-2-3.*nexthop 1.0.0.3" "babeld-n2.log"
#pass_string "1.0.0.3/32 from.*price 12 fee 10.*via veth-2-1.*nexthop 1.0.0.1" "babeld-n2.log"

pass_string "1.0.0.4/32 from.*price 1 fee 10.*via veth-2-3.*nexthop 1.0.0.3" "babeld-n2.log"
#pass_string "1.0.0.4/32 from.*price 5 fee 10.*via veth-2-1.*nexthop 1.0.0.1" "babeld-n2.log"

# netlab-3
pass_string "1.0.0.1/32 from.*price 7 fee 1.*via veth-3-4.*nexthop 1.0.0.4" "babeld-n3.log"
#pass_string "1.0.0.1/32 from.*price 10 fee 1.*via veth-3-2.*nexthop 1.0.0.2" "babeld-n3.log"

pass_string "1.0.0.2/32 from.*price 0 fee 1.*via veth-3-2.*nexthop 1.0.0.2" "babeld-n3.log"
#pass_string "1.0.0.2/32 from.*price 12 fee 1.*via veth-3-4.*nexthop 1.0.0.4" "babeld-n3.log"

pass_string "1.0.0.4/32 from.*price 0 fee 1.*via veth-3-4.*nexthop 1.0.0.4" "babeld-n3.log"
#pass_string "1.0.0.4/32 from.*price 15 fee 1.*via veth-3-2.*nexthop 1.0.0.2" "babeld-n3.log"

# netlab-4
pass_string "1.0.0.1/32 from.*price 0 fee 7.*via veth-4-1.*nexthop 1.0.0.1" "babeld-n4.log"
#pass_string "1.0.0.1/32 from.*price 11 fee 7.*via veth-4-3.*nexthop 1.0.0.3" "babeld-n4.log"

pass_string "1.0.0.2/32 from.*price 1 fee 7.*via veth-4-3.*nexthop 1.0.0.3" "babeld-n4.log"
#pass_string "1.0.0.2/32 from.*price 5 fee 7.*via veth-4-1.*nexthop 1.0.0.1" "babeld-n4.log"

pass_string "1.0.0.3/32 from.*price 0 fee 7.*via veth-4-3.*nexthop 1.0.0.3" "babeld-n4.log"
#pass_string "1.0.0.3/32 from.*price 15 fee 7.*via veth-4-1.*nexthop 1.0.0.1" "babeld-n4.log"

cleanup

echo "$0 PASS"
