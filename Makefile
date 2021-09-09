SHELL = bash -eo pipefail
GNU_SED := $(shell command -v gsed || command -v sed)

all:
	@echo -n "Building dashit... "
	@cat src/main.sh src/_*.sh | \
		$(GNU_SED) -e '/^# shellcheck source=.*$$/,+1d' \
			-e '/^main "$$@"$$/{H;d};$${p;x;s/^\n//}' \
			-e '/^\(SCRIPT_ROOT=\|$$\)/d' \
		> dashit
	@chmod +x dashit && echo "Done!"
