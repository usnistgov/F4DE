# KWSEval/test/KWSEval-XMLValidator

KWSEval-XMLValidator_tester=KWSEval-XMLValidator_tester.pl

KWSEval-XMLValidator_exec=KWSEval-XMLValidator.pl
KWSEval-XMLValidator_reldir=../../tools/KWSEval-XMLValidator
KWSEval-XMLValidator=${KWSEval-XMLValidator_reldir}/${KWSEval-XMLValidator_exec}

KWSEval_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${KWSEval_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${KWSEval-XMLValidator_tester_exec} ${KWSEval-XMLValidator}
	@(${PERL} ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator} $@)

makecheckfiles: ${KWSEval-XMLValidator_tester_exec} ${KWSEval-XMLValidator}
	@(${PERL} ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator} $@)

makecompcheckfiles: ${KWSEval-XMLValidator_tester_exec} ${KWSEval-XMLValidator}
	@(${PERL} ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator} $@)

cleanresfiles:
	@rm -f res_*.txt
