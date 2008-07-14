all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd Pre; make check)
	@(cd TV08ViperValidator; make check)
	@(cd TV08Scorer; make check)
	@(cd TV08MergeHelper; make check)
	@echo "***** All tests ran succesfully"

makecheckfiles:
	@(cd Pre; make check)
	@(cd TV08ViperValidator; make makecheckfiles)
	@(cd TV08Scorer; make makecheckfiles)
	@(cd TV08MergeHelper; make makecheckfiles)
	@echo "***** All files generated succesfully"

makecompcheckfiles:
	@(cd Pre; make check)
	@(cd TV08ViperValidator; make makecompcheckfiles)
	@(cd TV08Scorer; make makecompcheckfiles)
	@(cd TV08MergeHelper; make makecompcheckfiles)
	@echo "***** All files generated succesfully"

cleanresfiles:
	@(cd TV08ViperValidator; make cleanresfiles)
	@(cd TV08Scorer; make cleanresfiles)
	@(cd TV08MergeHelper; make cleanresfiles)
	@echo "***** All results files removed"
