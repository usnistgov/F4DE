# CLEAR07/test

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd Pre; make $@)
	@(cd UnitTests; make $@)
	@(cd CLEARDTViperValidator; make $@)
	@(cd CLEARTRViperValidator; make $@)
	@(cd CLEARDTScorer; make $@)
	@(cd CLEARTRScorer; make $@)
	@echo "***** All tests ran succesfully"

makecheckfiles:
	@(cd Pre; make check)
	@(cd CLEARDTViperValidator; make $@)
	@(cd CLEARTRViperValidator; make $@)
	@(cd CLEARDTScorer; make $@)
	@(cd CLEARTRScorer; make $@)
	@echo "***** All files generated succesfully"

makecompcheckfiles:
	@(cd Pre; make check)
	@(cd CLEARDTViperValidator; make $@)
	@(cd CLEARTRViperValidator; make $@)
	@(cd CLEARDTScorer; make $@)
	@(cd CLEARTRScorer; make $@)
	@echo "***** All files generated succesfully"

cleanresfiles:
	@(cd CLEARDTViperValidator; make $@)
	@(cd CLEARTRViperValidator; make $@)
	@(cd CLEARDTScorer; make $@)
	@(cd CLEARTRScorer; make $@)
	@echo "***** All results files removed"
