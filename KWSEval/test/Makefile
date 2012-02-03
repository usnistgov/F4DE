# common/test

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@echo "* Running unit tests"
	@(cd ../lib; perl -I. -I../../common/lib -e 'use RTTMList; exit(1) if (! RTTMList::unitTest("../test/common/test1.rttm"));')
	@(cd ../lib; perl -I. -I../../common/lib -e 'use KWSecf; exit(1) if (! KWSecf::unitTest("../test/common/test1.ecf.xml"));')
	@(cd ../lib; perl -I. -I../../common/lib -e 'use KWSAlignment;exit(1) if (! KWSAlignment::unitTest());')
	@(cd ../lib; perl -I. -I../../common/lib -e 'use KWSTrials; exit(1) if (! KWSTrials::unitTest());')
	@(echo "")
	@(cd KWSEval; make $@)
	@echo "***** All tests ran succesfully"
