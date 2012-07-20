# KWSEval/test/KWSEval

KWSEval_tester=KWSEval_tester.pl
KWSEval=../../tools/KWSEval/KWSEval.pl

KWSEval_lib=../../../KWSEval/lib
F4DE_lib=../../../common/lib

PERL=perl -I${KWSEval_lib} -I${F4DE_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${KWSEval_tester} ${KWSEval}
	@(${PERL} ${KWSEval_tester} ${KWSEval} $@)
	@make cleanup

makecheckfiles: ${KWSEval_tester} ${KWSEval}
	@(${PERL} ${KWSEval_tester} ${KWSEval} $@)
	@make cleanup

makecompcheckfiles: ${KWSEval_tester} ${KWSEval}
	@(${PERL} ${KWSEval_tester} ${KWSEval} $@)
	@make cleanup

cleanresfiles:
	@rm -f res_*.txt

cleanup:
	@rm -f alignment.csv
