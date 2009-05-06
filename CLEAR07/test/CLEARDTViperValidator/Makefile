# CLEAR07/test/CLEARDTViperValidator

CLEARDTViperValidator_tester=CLEARDTViperValidator_tester.pl

CLEARDTViperValidator_exec=CLEARDTViperValidator.pl
CLEARDTViperValidator_reldir=../../tools/CLEARDTViperValidator
CLEARDTViperValidator=${CLEARDTViperValidator_reldir}/${CLEARDTViperValidator_exec}

CLEARDTTC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${CLEARDTTC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${CLEARDTViperValidator_tester_exec} ${CLEARDTViperValidator}
	@(${PERL} ${CLEARDTViperValidator_tester} ${CLEARDTViperValidator} $@)

makecheckfiles: ${CLEARDTViperValidator_tester_exec} ${CLEARDTViperValidator}
	@(${PERL} ${CLEARDTViperValidator_tester} ${CLEARDTViperValidator} $@)

makecompcheckfiles: ${CLEARDTViperValidator_tester_exec} ${CLEARDTViperValidator}
	@(${PERL} ${CLEARDTViperValidator_tester} ${CLEARDTViperValidator} $@)

cleanresfiles:
	@rm -f res*.txt
