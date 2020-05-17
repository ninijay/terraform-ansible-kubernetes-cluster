#!/bin/bash
cd terraform
template=../hosts.tmpl
hosts="$(terraform output --json)"
hostfile=../hosts
cp $template $hostfile
masterip=$(echo $hosts | jq -r '.master_ip.value')
line="master ansible_host=$masterip ansible_user=root"
sed -i "/\[masters\]/a $line" $hostfile
workerip=$(echo $hosts | jq -r '.worker_1_ip.value')
line="worker1 ansible_host=$workerip ansible_user=root"
sed -i "/\[workers\]/a $line" $hostfile
workerip=$(echo $hosts | jq -r '.worker_2_ip.value')
line="worker2 ansible_host=$workerip ansible_user=root"
sed -i "/\[workers\]/a $line" $hostfile
cd ..
mv hosts ./ansible/hosts