.PHONY: check

check:
	ruff check tools/jiaolongctl tests/*.py
	ruff format --check tools/jiaolongctl tests/*.py
	python3 -m unittest discover -s tests -v
	bash -n tools/collect-linux.sh
