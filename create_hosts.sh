#!/bin/bash
workernodes=2
template=../hosts.tmpl
hosts="$(terraform output --json)"
hostfile=../hosts

cd terraform
cp $template $hostfile

masterip=$(echo $hosts | jq -r '.master_ip.value')
line="master ansible_host=$masterip ansible_user=root"
sed -i "/\[masters\]/a $line" $hostfile

for((no=1;no<=$workernodes;no++))
do
    workerip=$(echo $hosts | jq -r --arg no "$no" ".worker_${no}_ip.value")
    line="worker${no} ansible_host=$workerip ansible_user=root"
    sed -i "/\[workers\]/a $line" $hostfile
done

cd ..
mv hosts ./ansible/hosts