all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd ../lib; perl -I . -e 'use DETCurveSet; DETCurveSet::unitTest()')
	@(cd ../lib; perl -I . -e 'use DETCurve; DETCurve::unitTest()')
	@(cd ../lib; perl -I . -e 'use Trials; Trials::unitTest()')
	@echo "***** All tests ran succesfully"

makecheckfiles:
	@echo "***** All files generated succesfully"

cleanresfiles:
	@echo "***** All results files removed"
