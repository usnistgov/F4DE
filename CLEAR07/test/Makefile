all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd UnitTests; make $@)
	@(cd CLEARDTViperValidator; make $@)
	@(cd CLEARTRViperValidator; make $@)
	@(cd CLEARDTScorer; make $@)
	@(cd CLEARTRScorer; make $@)
	@echo "***** All tests ran succesfully"

makecheckfiles:
	@(cd UnitTests; make $@)
	@(cd CLEARDTViperValidator; make $@)
	@(cd CLEARTRViperValidator; make $@)
	@(cd CLEARDTScorer; make $@)
	@(cd CLEARTRScorer; make $@)
	@echo "***** All files generated succesfully"

makecompcheckfiles:
	@(cd UnitTests; make $@)
	@(cd CLEARDTViperValidator; make $@)
	@(cd CLEARTRViperValidator; make $@)
	@(cd CLEARDTScorer; make $@)
	@(cd CLEARTRScorer; make $@)
	@echo "***** All files generated succesfully"

cleanresfiles:
	@(cd UnitTests; make $@)
	@(cd CLEARDTViperValidator; make $@)
	@(cd CLEARTRViperValidator; make $@)
	@(cd CLEARDTScorer; make $@)
	@(cd CLEARTRScorer; make $@)
	@echo "***** All results files removed"
