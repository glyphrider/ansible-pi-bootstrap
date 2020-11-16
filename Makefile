
.PHONY: provision

provision: container
	docker run -ti --rm -v `pwd`:/playbook -v $(SSH_AUTH_SOCK):$(SSH_AUTH_SOCK) -e SSH_AUTH_SOCK=$(SSH_AUTH_SOCK) ansible-playbook --key-file ansible -i inventory.yml site.yml

.PHONY: ssh-enabled

ssh-enabled: container ansible
	docker run -ti --rm -v `pwd`:/playbook ansible-playbook -i inventory.yml ssh-key-bootstrap.yml -e "ansible_ssh_pass=raspberry"

ansible:
	ssh-keygen -f ansible -P ''
	ssh-add ansible

.PHONY: container

container: Dockerfile
	docker build -t ansible-playbook .
