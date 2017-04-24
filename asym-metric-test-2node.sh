#!bash

rm babeld-n*

source ./network-lab.sh << EOF
{
  "nodes": {
    "1": { "ip": "1.0.0.1" },
    "2": { "ip": "1.0.0.2" }
  },
  "edges": [
    {
      "nodes": ["1", "2"],
      "->": "loss random 2%",
      "<-": "loss random 20%"
    }
  ]
}
EOF

sleep 1

n1 sysctl -w net.ipv4.ip_forward=1
n1 babeld -I babeld-n1.pid -d 1 -L babeld-n1.log veth-1-2 &

n2 sysctl -w net.ipv4.ip_forward=1
n2 babeld -I babeld-n2.pid -d 1 -L babeld-n2.log veth-2-1 &
