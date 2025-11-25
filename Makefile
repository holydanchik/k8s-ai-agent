up:
	@echo ">>> Creating cluster and deploying stack"
	bash cluster/install.sh

down:
	@echo ">>> Destroying k8s cluster"
	bash cluster/destroy.sh

restart:
	$(MAKE) down
	$(MAKE) up
