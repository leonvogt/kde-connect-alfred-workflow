BUNDLE_ID := com.leonvogt.kde-connect
WORKFLOW_DIR := workflow
PACKAGE := dist/KDE-Connect.alfredworkflow

# Alfred reads workflows from its sync folder, which the user configures in
# Alfred Preferences → Advanced → Syncing. If no sync folder is set, Alfred
# falls back to ~/Library/Application Support/Alfred/Alfred.alfredpreferences.
ALFRED_SYNC := $(shell defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null)
ifeq ($(ALFRED_SYNC),)
ALFRED_PREFS := $(HOME)/Library/Application Support/Alfred/Alfred.alfredpreferences
else
ALFRED_PREFS := $(shell eval echo $(ALFRED_SYNC))/Alfred.alfredpreferences
endif
ALFRED_WORKFLOWS := $(ALFRED_PREFS)/workflows
LINK_PATH := $(ALFRED_WORKFLOWS)/$(BUNDLE_ID)

.PHONY: link unlink package clean where

where:
	@echo "Alfred workflows dir: $(ALFRED_WORKFLOWS)"
	@echo "Link path:            $(LINK_PATH)"

link:
	@mkdir -p "$(ALFRED_WORKFLOWS)"
	@if [ -e "$(LINK_PATH)" ] && [ ! -L "$(LINK_PATH)" ]; then \
		echo "Refusing to overwrite non-symlink at $(LINK_PATH)"; exit 1; \
	fi
	@rm -f "$(LINK_PATH)"
	@ln -s "$(CURDIR)/$(WORKFLOW_DIR)" "$(LINK_PATH)"
	@echo "Linked $(LINK_PATH) -> $(CURDIR)/$(WORKFLOW_DIR)"

unlink:
	@if [ -L "$(LINK_PATH)" ]; then rm "$(LINK_PATH)" && echo "Unlinked $(LINK_PATH)"; \
	else echo "No symlink at $(LINK_PATH)"; fi

package: clean
	@mkdir -p dist
	@cd "$(WORKFLOW_DIR)" && zip -qr "$(CURDIR)/$(PACKAGE)" .
	@echo "Built $(PACKAGE)"

clean:
	@rm -rf dist
