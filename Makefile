create:
	cd terraform &&	terraform init && terraform apply -auto-approve
	./create_hosts.sh
	ansible-playbook -i ./ansible/hosts ./ansible/cluster.yml
