# KWSEval/test/ValidateKWSList

ValidateKWSList_tester=ValidateKWSList_tester.pl

ifdef F4DE_TEST_INSTALLDIR
ValidateKWSList=../../../bin/ValidateKWSList
else
ValidateKWSList_exec=ValidateKWSList.pl
ValidateKWSList_reldir=../../tools/ValidateKWSList
ValidateKWSList=${ValidateKWSList_reldir}/${ValidateKWSList_exec}
endif

KWSEval_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${KWSEval_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${ValidateKWSList_tester} ${ValidateKWSList}
	@(${PERL} ${ValidateKWSList_tester} ${ValidateKWSList} $@)

makecheckfiles: ${ValidateKWSList_tester} ${ValidateKWSList}
	@(${PERL} ${ValidateKWSList_tester} ${ValidateKWSList} $@)

makecompcheckfiles: ${ValidateKWSList_tester} ${ValidateKWSList}
	@(${PERL} ${ValidateKWSList_tester} ${ValidateKWSList} $@)

cleanresfiles:
	@rm -f res_*.txt
