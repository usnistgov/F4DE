# From within: test/TV08Scorer

TV08Scorer_tester=TV08Scorer_tester.pl

TV08Scorer_exec=TV08Scorer.pl
TV08Scorer_reldir=../../tools/TV08Scorer
TV08Scorer=${TV08Scorer_reldir}/${TV08Scorer_exec}

TV08_XSDPATH_rel=../../data

TV08TC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${TV08TC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:	${TV08Scorer_tester_exec} ${TV08Scorer}
	@(env TV08_XSDPATH=${TV08_XSDPATH_rel} ${PERL} ${TV08Scorer_tester} ${TV08Scorer} check)

makecheckfiles:	${TV08Scorer_tester_exec}
	@make cleanresfiles
	@(env TV08_XSDPATH=${TV08_XSDPATH_rel} ${PERL} ${TV08Scorer_tester} ${TV08Scorer} makecheckfiles)

makecompcheckfiles:	${TV08Scorer_tester_exec}
	@(env TV08_XSDPATH=${TV08_XSDPATH_rel} ${PERL} ${TV08Scorer_tester} ${TV08Scorer} makecompcheckfiles)

cleanresfiles:
	@rm -f res*.txt
