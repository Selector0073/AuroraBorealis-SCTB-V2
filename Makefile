.PHONY: help

help:
	@echo "cleaner - clear all folders of old instances"
	@echo ""
	@echo "    SERVER"
	@echo "release-server - create a \"release-server\" folder with files ready for execution on server"
	@echo "server-test - to run tests"
	@echo "server-test-run - run temporary docker OS for testing"
	@echo ""
	@echo "    APP"
	@echo "release-app - create a \"release-app\" folder with files ready for execution on client"
	@echo "app-run - to run project live"
	@echo "app-test - to run tests"
	@echo ""
	@echo "    Docs"
	@echo "docs-run - to run live docs server"
	@echo "docs-build - to build docs"



cleaner:
	@echo "Cleaning..."
	@rm -rf release-server
	@rm -rf release-app
	@echo "Cleaning successfull"



release-server: cleaner
	@echo "Creating server release..."
	@mkdir release-server
	@cp -a server/scripts/. release-server/
	@cd server && cargo build --release
	find server/target/release/ -maxdepth 1 -type f -executable -exec cp {} release-server/ \;
	@echo "Server release created successfully"

server-test-run: release-server
	@docker build -t single-use-os -f server/Dockerfile .
	@docker rm -f single-use-os >/dev/null 2>&1 || true
	@docker run -d --rm --name single-use-os --hostname clean-server \
		--cgroupns=host \
		--tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
		-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
		--cap-add SYS_ADMIN --cap-add NET_ADMIN \
		single-use-os >/dev/null
	@trap 'docker stop -t 10 single-use-os >/dev/null 2>&1' EXIT INT TERM; \
	docker exec single-use-os systemctl is-system-running --wait >/dev/null 2>&1 || true; \
	docker exec -it single-use-os bash -l || true

server-test: 
	@echo "Not ready"



release-app: cleaner
	@echo "Not ready"

app-run:
	@echo "Not ready"

app-test: 
	@echo "Not ready"



docs-run:
	@echo "Running docs server..."
	@cd docs && poetry run mkdocs serve

docs-build:
	@echo "Building docs..."
	@cd docs && poetry run mkdocs build