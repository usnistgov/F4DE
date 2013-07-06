# AVSS09/test/AVSS09Scorer

AVSS09Scorer_tester=AVSS09Scorer_tester.pl

CLEAR07_XSD=../../../CLEAR07/data

ifdef F4DE_TEST_INSTALLDIR
AVSS09Scorer=../../../bin/AVSS09Scorer
AVSS09ViPERValidator=../../../bin/AVSS09ViPERValidator
CLEAR07DTScorer=../../../bin/CLEARDTScorer
else
AVSS09Scorer_exec=AVSS09Scorer.pl
AVSS09Scorer_reldir=../../tools/AVSS09Scorer
AVSS09Scorer=${AVSS09Scorer_reldir}/${AVSS09Scorer_exec}
AVSS09ViPERValidator=../../tools/AVSS09ViPERValidator/AVSS09ViPERValidator.pl
CLEAR07DTScorer=../../../CLEAR07/tools/CLEARDTScorer/CLEARDTScorer.pl
endif
AVSS09Scorer_Add=--CLEARxsd ${CLEAR07_XSD} --Validator ${AVSS09ViPERValidator} --Scorer ${CLEAR07DTScorer}

CLEAR07_lib=../../../CLEAR07/lib
AVSS09_lib=../lib
F4DE_lib=../../../common/lib
PERL=perl -I${CLEAR07_lib} -I${AVSS09_lib} -I${F4DE_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${AVSS09Scorer_tester_exec} ${AVSS09Scorer}
	@(${PERL} ${AVSS09Scorer_tester} ${AVSS09Scorer} $@ ${AVSS09Scorer_Add})

makecheckfiles: ${AVSS09Scorer_tester_exec} ${AVSS09Scorer}
	@(${PERL} ${AVSS09Scorer_tester} ${AVSS09Scorer} $@ ${AVSS09Scorer_Add})

makecompcheckfiles: ${AVSS09Scorer_tester_exec} ${AVSS09Scorer}
	@(${PERL} ${AVSS09Scorer_tester} ${AVSS09Scorer} $@ ${AVSS09Scorer_Add})

cleanresfiles:
	@rm -f res_*.txt
