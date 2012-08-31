# common/test

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd Pre; make $@)
	@echo "* Running unit tests"
	@(cd ../lib; perl -I. -I../../common/lib -e 'use RTTMList; use Encode; use encoding "euc-cn"; use encoding "utf8"; exit(1) if (! RTTMList::unitTest("../test/common/test1.rttm", "../test/common/test4.cantonese.rttm", "../test/common/test4.cantonese.kwlist.xml"));')
	@(cd ../lib; perl -I. -I../../common/lib -e 'use KWSecf; exit(1) if (! KWSecf::unitTest("../test/common/test1.ecf.xml"));')
	@(cd ../lib; perl -I. -I../../common/lib -e 'use KWSAlignment;exit(1) if (! KWSAlignment::unitTest("../test/common/"));')
	@(cd ../lib; perl -I. -I../../common/lib -e 'use KWSSegAlign;exit(1) if (! KWSSegAlign::unitTest("../test/common/"));')
	@(echo "")
	@(cd KWSEval-XMLvalidator; make $@)
	@(echo "")
	@(cd KWSEval; make $@)
	@echo "***** All tests ran succesfully"
