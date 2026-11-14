.PHONY: help

help:
	@echo "cleaner - clear all folders of old instances"
	@echo ""
	@echo "    ARBITER"
	@echo "release-arbiter - create a \"release-arbiter\" folder with files ready for execution on server"
	@echo "arbiter-test - to run tests"
	@echo "arbiter-test-run - run temporary docker OS for testing"
	@echo ""
	@echo "    APP"
	@echo "release-app - create a \"release-app\" folder with files ready for execution on client"
	@echo "app-run - to run project live"
	@echo "app-test - to run tests"
	@echo ""
	@echo "    DOCS"
	@echo "docs-run - to run live docs arbiter"
	@echo "docs-build - to build docs"



cleaner:
	@echo "Cleaning..."
	@rm -rf release-arbiter
	@rm -rf release-app
	@echo "Cleaning successfull"



release-arbiter: cleaner
	@echo "Creating arbiter release..."
	@mkdir release-arbiter
	@cp -a arbiter/scripts/. release-arbiter/
	@echo "Building arbiter..."
	@cd arbiter/arbiter && nimble buildlib
	@echo "Arbiter release created successfully"

arbiter-test-run: release-arbiter
	@docker build -t single-use-os -f arbiter/Dockerfile .
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

arbiter-test: 
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
