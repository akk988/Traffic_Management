#!/bin/bash

# This script uses tc htb to control bandwidth of several hosts
#HTB The Hierarchy Token Bucket implements a rich linksharing
#  hierarchy of classes with an emphasis on conforming to
#  existing practices. HTB facilitates guaranteeing bandwidth
#  to classes, while also allowing specification of upper
#  limits to inter-class sharing. It contains shaping
#  elements, based on TBF and can prioritize classes.
#TBF The Token Bucket Filter is suited for slowing traffic down
#  to a precisely configured rate. Scales well to large bandwidths.

TC=/sbin/tc


# interface traffic will leave on
IF=wlp1s0

# The parent limit, children can borrow from this amount of bandwidth
# based on what's available.

LIMIT=10mbit

# the rate each child should start at

START_RATE=1.8mbit

# the max rate each child should get to, if there is bandwidth
# to borrow from the parent.
# e.g. if parent is limited to 100mbits, both children, if transmitting at max at the same time,
# would be limited to 50mbits each.
CHILD_LIMIT=7.5mbit

# host 1
DST_CIDR=192.168.0.101
# host 2
DST_CIDR_2=192.168.0.103


# filter command -- add ip dst match at the end
U32="$TC filter add dev $IF protocol ip parent 1:0 prio 1 u32"



create () {
  echo "== SHAPING INIT =="
  # create the root qdisc
  $TC qdisc add dev $IF root handle 1:0 htb default 30
  
  # create the parent qdisc, children will borrow bandwidth from
  $TC class add dev $IF parent 1:0 classid 1:1 htb rate $LIMIT

  # create children qdiscs; reference parent
  $TC class add dev $IF parent 1:1 classid 1:10 htb rate $START_RATE ceil $CHILD_LIMIT
  $TC class add dev $IF parent 1:1 classid 1:30 htb rate $START_RATE ceil $CHILD_LIMIT

  # setup filters to ensure packets are enqueued to the correct
  # child based on the dst IP of the packet

  $U32 match ip dst $DST_CIDR flowid 1:10
  $U32 match ip dst $DST_CIDR_2 flowid 1:30

  echo "== SHAPING DONE =="
}

# run clean to ensure existing tc is not configured
clean () {
  echo "== CLEAN INIT =="
  $TC qdisc del dev $IF root
  echo "== CLEAN DONE =="
}

clean
create
