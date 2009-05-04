# From within: test/CLEARTRViperValidator

CLEARTRViperValidator_tester=CLEARTRViperValidator_tester.pl

CLEARTRViperValidator_exec=CLEARTRViperValidator.pl
CLEARTRViperValidator_reldir=../../tools/CLEARTRViperValidator
CLEARTRViperValidator=${CLEARTRViperValidator_reldir}/${CLEARTRViperValidator_exec}

CLEARTRTC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${CLEARTRTC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${CLEARTRViperValidator_tester_exec} ${CLEARTRViperValidator}
	@(${PERL} ${CLEARTRViperValidator_tester} ${CLEARTRViperValidator} check)

makecheckfiles: ${CLEARTRViperValidator_tester_exec} ${CLEARTRViperValidator}
	@(${PERL} ${CLEARTRViperValidator_tester} ${CLEARTRViperValidator} makecheckfiles)

makecompcheckfiles: ${CLEARTRViperValidator_tester_exec} ${CLEARTRViperValidator}
	@(${PERL} ${CLEARTRViperValidator_tester} ${CLEARTRViperValidator} makecompcheckfiles)

cleanresfiles:
	@rm -f res*.txt
