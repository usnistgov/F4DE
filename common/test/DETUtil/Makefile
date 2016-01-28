# common/test/AutoTable_Extra
include ../../../Makefile_common

tester=DETUtil_tester.pl

F4DEC_lib=../../../common/lib
PERL=${F4DEPERL} -I${F4DEC_lib}

ifdef F4DE_TEST_INSTALLDIR
DETUtilcmd=../../../bin/DETUtil
else
DETUtilcmd=../../../common/tools/DETUtil/DETUtil.pl
endif

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

makecompcheckfiles makecheckfiles check:
	@(${PERL} ${tester} ${DETUtilcmd} $@)

cleanresfiles:
	@rm -f res*.txt
