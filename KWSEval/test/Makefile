# common/test
include ../../Makefile_common

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd Pre; make $@)
	@echo "* Running unit tests"
	@(cd ../lib; ${F4DEPERL} -I. -I../../common/lib -e 'use RTTMList; use Encode; use if $^V lt 5.18.0, "encoding", "euc-cn"; use if $^V ge 5.18.0, "Encode::CN"; use if $^V lt 5.18.0, "encoding", "utf8"; use if $^V ge 5.18.0, "utf8"; exit(1) if (! RTTMList::unitTest("../test/common/test1.rttm", "../test/common/test4.cantonese.rttm", "../test/common/test4.cantonese.kwlist.xml", "../test/common/rttm_seg_test.rttm"));')
	@(cd ../lib; ${F4DEPERL} -I. -I../../common/lib -e 'use KWSecf; exit(1) if (! KWSecf::unitTest("../test/common/test1.ecf.xml"));')
	@(cd ../lib; ${F4DEPERL} -I. -I../../common/lib -e 'use KWSAlignment;exit(1) if (! KWSAlignment::unitTest("../test/common/"));')
	@(cd ../lib; ${F4DEPERL} -I. -I../../common/lib -e 'use KWSSegAlign;exit(1) if (! KWSSegAlign::unitTest("../test/common/"));')
	@(echo "")
	@(cd KWSEval-XMLvalidator; make $@)
	@(echo "")
	@(cd ValidateKWSList; make $@)
	@(echo "")
	@(cd KWSEval; make $@)
	@(rm -f ../../common/lib/foomerge*)
	@echo "***** All tests ran succesfully"
