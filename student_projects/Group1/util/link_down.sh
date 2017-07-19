#!/bin/sh 

if [ $# -eq 1 ]
then 
	ifconfig $1 down 
else 
	echo "usage: linkdown interface"
fi 
