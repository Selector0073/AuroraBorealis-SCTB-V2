.PHONY: help

help:
	@echo "    API"
	@echo "api-run - to run project live"
	@echo "api-test - to run tests"
	@echo ""
	@echo "    Frontend"
	@echo "site-run - to run project live"
	@echo "site-test - to run tests"
	@echo ""
	@echo "    Docs"
	@echo "docs-run - to run live docs server"
	@echo "docs-build - to build docs"



dependencies: 
	@echo "Not ready"



api-run: api/.env
	@echo "Not ready"

api-test: 
	@echo "Not ready"



site-run: site/.env
	@echo "Not ready"

site-test: 
	@echo "Not ready"



docs-run:
	@echo "Running docs server..."
	@cd docs && poetry run mkdocs serve

docs-build:
	@echo "Building docs..."
	@cd docs && poetry run mkdocs build