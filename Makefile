.PHONY: check

check:
	uv run ruff check tools/jiaolongctl tools/jiaolong-tui tools/*.py tests/*.py
	uv run ruff format --check tools/jiaolongctl tools/jiaolong-tui tools/*.py tests/*.py
	uv run python -m unittest discover -s tests -v
	bash -n tools/*.sh
