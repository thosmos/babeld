#!bash
set -eux

export LABPATH=./
export BABELPATH=../babeld

# This is a basic integration test for the Althea fork of Babeld, it focuses on
# validating that instances actually come up and communicate

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root :(" 
   exit 1
fi

fail_string()
{
 if grep -q $1 "$2"; then
   echo "FAILED: $1 in $2"
   exit 1
 fi
}

pass_string()
{
 if !grep -q $1 "$2"; then
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
  rm -f babeld-n*
 set -eux
}

cleanup

 source $LABPATH/network-lab.sh << EOF
{
  "nodes": {
    "1": { "ip": "1.0.0.1" },
    "2": { "ip": "1.0.0.2" },
    "3": { "ip": "1.0.0.3" }
  
},
  "edges": [
     {
      "nodes": ["1", "2"],
      "->": "loss random 0%",
      "<-": "loss random 0%"
     },
     {
      "nodes": ["2", "3"],
      "->": "loss random 0%",
      "<-": "loss random 0%"
     }
  ]
}
EOF



ip netns exec netlab-1 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-1 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-1 ../babeld -I babeld-n1.pid -d 1 -L babeld-n1.log -P 5 -w veth-1-2 & 

ip netns exec netlab-2 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-2 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-2 ../babeld -I babeld-n2.pid -d 1 -L babeld-n2.log -P 10 -w veth-2-1 -w veth-2-3 &

ip netns exec netlab-3 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-3 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-3 ../babeld -I babeld-n3.pid -d 1 -L babeld-n3.log -P 1 -w veth-3-2&

sleep 15
fail_string "malformed" "babeld-n1.log" 
fail_string "malformed" "babeld-n2.log" 
fail_string "malformed" "babeld-n3.log" 
fail_string "unknown version" "babeld-n1.log"
fail_string "unknown version" "babeld-n2.log"
fail_string "unknown version" "babeld-n3.log"
pass_string "dev veth-1-2 reach" "babeld-n1.log"
pass_string "dev veth-2-1 reach" "babeld-n2.log"
pass_string "dev veth-2-3 reach" "babeld-n2.log"
pass_string "dev veth-3-2 reach" "babeld-n3.log"
pass_string "nexthop 1.0.0.2" "babeld-n1.log"
pass_string "nexthop 1.0.0.1" "babeld-n2.log"
pass_string "nexthop 1.0.0.3" "babeld-n2.log"
pass_string "nexthop 1.0.0.2" "babeld-n3.log"

cleanup

echo "$0 PASS"
