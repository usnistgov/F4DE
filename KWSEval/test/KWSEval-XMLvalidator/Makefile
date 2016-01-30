# KWSEval/test/KWSEval-XMLValidator
include ../../../Makefile_common

KWSEval-XMLValidator_tester=KWSEval-XMLValidator_tester.pl

ifdef F4DE_TEST_INSTALLDIR
KWSEval-XMLValidator=../../../bin/KWSEval-XMLvalidator
else
KWSEval-XMLValidator_exec=KWSEval-XMLvalidator.pl
KWSEval-XMLValidator_reldir=../../tools/KWSEval-XMLvalidator
KWSEval-XMLValidator=${KWSEval-XMLValidator_reldir}/${KWSEval-XMLValidator_exec}
endif

KWSEval_lib=../lib
F4DEC_lib=../../../common/lib
PERL=${F4DEPERL} -I${KWSEval_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator}
	@(${PERL} ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator} $@)

makecheckfiles: ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator}
	@(${PERL} ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator} $@)

makecompcheckfiles: ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator}
	@(${PERL} ${KWSEval-XMLValidator_tester} ${KWSEval-XMLValidator} $@)

cleanresfiles:
	@rm -f res_*.txt
