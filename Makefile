.PHONY: clean deepclean install dev mypy ruff ruff-format toml-sort lint pre-commit test-run test build publish doc-autobuild changelog doc-gen doc-mypy doc-coverage doc

########################################################################################
# Variables
########################################################################################

# Global option for pdm, when in CI or readthedocs environment, no need to use venv.
PDM_GLOBAL := $(shell [ "$$CI" = "true" ] || [ "$$READTHEDOCS" = "True" ] && echo "--global --project .")

# Documentation target directory, will be adapted to specific folder for readthedocs.
PUBLIC_DIR := $(shell [ "$$READTHEDOCS" = "True" ] && echo "$$READTHEDOCS_OUTPUT/html" || echo "public")

# URL and Path of changelog source code.
CHANGELOG_URL := $(shell echo $${CI_PAGES_URL:-https://serious-scaffold.github.io/ss-python}/_sources/changelog.md.txt)
CHANGELOG_PATH := docs/changelog.md

########################################################################################
# Development Environment Management
########################################################################################

# Remove common intermediate files.
clean:
	-rm -rf \
		$(PUBLIC_DIR) \
		.copier-answers.yml \
		.coverage \
		.mypy_cache \
		.pdm-build \
		.pdm-python \
		.pytest_cache \
		.ruff_cache \
		Pipfile* \
		__pypackages__ \
		build \
		coverage.xml \
		dist \
		release-notes.md
	find . -name '*.egg-info' -print0 | xargs -0 rm -rf
	find . -name '*.pyc' -print0 | xargs -0 rm -f
	find . -name '*.swp' -print0 | xargs -0 rm -f
	find . -name '.DS_Store' -print0 | xargs -0 rm -f
	find . -name '__pycache__' -print0 | xargs -0 rm -rf

# Remove pre-commit hook, virtual environment alongside itermediate files.
deepclean: clean
	if command -v pre-commit > /dev/null 2>&1; then pre-commit uninstall; fi
	if command -v pdm >/dev/null 2>&1 && pdm venv list | grep -q in-project ; then pdm venv remove --yes in-project >/dev/null 2>&1; fi

# Install the package in editable mode.
install:
	pdm install $(PDM_GLOBAL) --prod

# Install the package in editable mode with specific optional dependencies.
dev-%:
	pdm install $(PDM_GLOBAL) --dev --group $*

# Prepare the development environment.
# Install the pacakge in editable mode with all optional dependencies and pre-commit hoook.
dev:
	pdm install $(PDM_GLOBAL)
	if [ "$(CI)" != "true" ] && command -v pre-commit > /dev/null 2>&1; then pre-commit install; fi

########################################################################################
# Lint and pre-commit
########################################################################################

# Check lint with mypy.
mypy:
	pdm run $(PDM_GLOBAL) python -m mypy .

# Lint with ruff.
ruff:
	pdm run $(PDM_GLOBAL) python -m ruff check .

# Format with ruff.
ruff-format:
	pdm run $(PDM_GLOBAL) python -m ruff format --check .

# Check lint with toml-sort.
toml-sort:
	pdm run $(PDM_GLOBAL) toml-sort --check pyproject.toml

# Check lint with all linters.
lint: mypy ruff ruff-format toml-sort

# Run pre-commit with autofix against all files.
pre-commit:
	pre-commit run --all-files --hook-stage manual

########################################################################################
# Test
########################################################################################

# Clean and run test with coverage.
test-run:
	pdm run $(PDM_GLOBAL) python -m coverage erase
	pdm run $(PDM_GLOBAL) python -m coverage run -m pytest

# Generate coverage report for terminal and xml.
test: test-run
	pdm run $(PDM_GLOBAL) python -m coverage report
	pdm run $(PDM_GLOBAL) python -m coverage xml

########################################################################################
# Package
########################################################################################

# Build the package.
build:
	pdm build

# Publish the package.
publish:
	pdm publish

########################################################################################
# Documentation
########################################################################################

# Generate documentation with auto build when changes happen.
doc-autobuild:
	pdm run $(PDM_GLOBAL) python -m sphinx_autobuild docs $(PUBLIC_DIR) \
		--watch README.md \
		--watch src

# Generate changelog from git commits.
# NOTE(xuan.hu): Need to be run before document generation to take effect.
changelog:
	@if wget -q --spider $(CHANGELOG_URL); then \
		echo "Existing Changelog found at '$(CHANGELOG_URL)', download for incremental generation."; \
		wget -q -O $(CHANGELOG_PATH) $(CHANGELOG_URL); \
	fi
	pdm run $(PDM_GLOBAL) git-changelog -ETrio $(CHANGELOG_PATH) -c conventional -s build,chore,ci,doc,feat,fix,perf,refactor,revert,style,test

# Generate release notes from changelog.
release-notes:
	@pdm run $(PDM_GLOBAL) git-changelog --input $(CHANGELOG_PATH) --release-notes

# Build documentation only from src.
doc-gen:
	pdm run $(PDM_GLOBAL) python -m sphinx.cmd.build docs $(PUBLIC_DIR)

# Generate mypy reports.
doc-mypy: doc-gen
	pdm run $(PDM_GLOBAL) python -m mypy src tests --html-report $(PUBLIC_DIR)/reports/mypy

# Generate html coverage reports with badge.
doc-coverage: test-run doc-gen
	pdm run $(PDM_GLOBAL) python -m coverage html -d $(PUBLIC_DIR)/reports/coverage
	pdm run $(PDM_GLOBAL) bash scripts/generate-coverage-badge.sh $(PUBLIC_DIR)/_static/badges

# Generate all documentation with reports.
doc: changelog doc-gen doc-mypy doc-coverage

########################################################################################
# End
########################################################################################
