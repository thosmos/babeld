#!bash
kill -9 $(cat babeld-n1.pid)
kill -9 $(cat babeld-n2.pid)
kill -9 $(cat babeld-n3.pid)
kill -9 $(cat babeld-n4.pid)
rm babeld-n*

source ../network-lab/network-lab.sh << EOF
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
      "->": "loss random 2%",
      "<-": "loss random 40%"
    },
    {
      "nodes": ["1", "3"],
      "->": "loss random 20%",
      "<-": "loss random 20%"
    },
    {
      "nodes": ["2", "4"],
      "->": "loss random 2%",
      "<-": "loss random 40%"
    },
    {
      "nodes": ["3", "4"],
      "->": "loss random 20%",
      "<-": "loss random 20%"
    }
  ]
}
EOF

sleep 1

n1 sysctl -w net.ipv4.ip_forward=1
n1 babeld -I babeld-n1.pid -d 1 -L babeld-n1.log -w veth-1-2 veth-1-3 &

n2 sysctl -w net.ipv4.ip_forward=1
n2 babeld -I babeld-n2.pid -d 1 -L babeld-n2.log -w veth-2-1 veth-2-4 &

n3 sysctl -w net.ipv4.ip_forward=1
n3 babeld -I babeld-n3.pid -d 1 -L babeld-n3.log -w veth-3-1 veth-3-4 &

n4 sysctl -w net.ipv4.ip_forward=1
n4 babeld -I babeld-n4.pid -d 1 -L babeld-n4.log -w veth-4-2 veth-4-3 &
