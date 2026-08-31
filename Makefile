# Eds Custom Addon — WotLK 3.3.5a
# Requires GNU Make. On Windows, PowerShell is used for the actual work.

PS     := powershell.exe -NoProfile -ExecutionPolicy Bypass -File
TASKS  := scripts/tasks.ps1

.PHONY: setup build test lint run clean validate package

setup:
	python -m pip install -r scripts/requirements-dev.txt
	$(PS) $(TASKS) -Task validate

build: package

test:
	python scripts/check.py

lint:
	python scripts/check.py

run:
	@echo Load the addon in-game (Interface 30300).
	@echo Commands: /eca ui   /eca help   /eca partyxp on|off|status   /eca debug

clean:
	$(PS) $(TASKS) -Task clean

validate:
	$(PS) $(TASKS) -Task validate

package:
	$(PS) $(TASKS) -Task package
