# TrecVid08/test

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd Pre; make $@)
	@(cd TV08ViperValidator; make $@)
	@(cd TV08Scorer; make $@)
	@(cd TV08MergeHelper; make $@)
	@echo "***** All tests ran succesfully"

makecheckfiles:
	@(cd Pre; make check)
	@(cd TV08ViperValidator; make $@)
	@(cd TV08Scorer; make $@)
	@(cd TV08MergeHelper; make $@)
	@echo "***** All files generated succesfully"

makecompcheckfiles:
	@(cd Pre; make check)
	@(cd TV08ViperValidator; make $@)
	@(cd TV08Scorer; make $@)
	@(cd TV08MergeHelper; make $@)
	@echo "***** All files generated succesfully"

cleanresfiles:
	@(cd TV08ViperValidator; make $@)
	@(cd TV08Scorer; make $@)
	@(cd TV08MergeHelper; make $@)
	@echo "***** All results files removed"
