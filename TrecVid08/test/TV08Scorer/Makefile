# TrecVid08/test/TV08Scorer
include ../../../Makefile_common

TV08Scorer_tester=TV08Scorer_tester.pl

ifdef F4DE_TEST_INSTALLDIR
TV08Scorer=../../../bin/TV08Scorer
else
TV08Scorer_exec=TV08Scorer.pl
TV08Scorer_reldir=../../tools/TV08Scorer
TV08Scorer=${TV08Scorer_reldir}/${TV08Scorer_exec}
endif

TV08TC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=${F4DEPERL} -I${TV08TC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${TV08Scorer_tester_exec} ${TV08Scorer}
	@(${PERL} ${TV08Scorer_tester} ${TV08Scorer} $@)

makecheckfiles: ${TV08Scorer_tester_exec} ${TV08Scorer}
	@(${PERL} ${TV08Scorer_tester} ${TV08Scorer} $@)

makecompcheckfiles: ${TV08Scorer_tester_exec} ${TV08Scorer}
	@(${PERL} ${TV08Scorer_tester} ${TV08Scorer} $@)

cleanresfiles:
	@rm -f res*.txt
