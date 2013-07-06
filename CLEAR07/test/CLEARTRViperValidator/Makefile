# CLEAR07/test/CLEARTRViperValidator

CLEARTRViperValidator_tester=CLEARTRViperValidator_tester.pl


ifdef F4DE_TEST_INSTALLDIR
CLEARTRViperValidator=../../../bin/CLEARTRViperValidator
else
CLEARTRViperValidator_exec=CLEARTRViperValidator.pl
CLEARTRViperValidator_reldir=../../tools/CLEARTRViperValidator
CLEARTRViperValidator=${CLEARTRViperValidator_reldir}/${CLEARTRViperValidator_exec}
endif

CLEARTRTC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${CLEARTRTC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${CLEARTRViperValidator_tester_exec} ${CLEARTRViperValidator}
	@(${PERL} ${CLEARTRViperValidator_tester} ${CLEARTRViperValidator} $@)

makecheckfiles: ${CLEARTRViperValidator_tester_exec} ${CLEARTRViperValidator}
	@(${PERL} ${CLEARTRViperValidator_tester} ${CLEARTRViperValidator} $@)

makecompcheckfiles: ${CLEARTRViperValidator_tester_exec} ${CLEARTRViperValidator}
	@(${PERL} ${CLEARTRViperValidator_tester} ${CLEARTRViperValidator} $@)

cleanresfiles:
	@rm -f res*.txt
