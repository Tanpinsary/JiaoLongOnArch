.PHONY: check

check:
	ruff check tools/jiaolongctl tools/*.py tests/*.py
	ruff format --check tools/jiaolongctl tools/*.py tests/*.py
	python3 -m unittest discover -s tests -v
	bash -n tools/*.sh
