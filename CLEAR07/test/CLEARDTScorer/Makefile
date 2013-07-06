# CLEAR07/test/CLEARDTScorer

CLEARDTScorer_tester=CLEARDTScorer_tester.pl

ifdef F4DE_TEST_INSTALLDIR
CLEARDTScorer=../../../bin/CLEARDTScorer
else
CLEARDTScorer_exec=CLEARDTScorer.pl
CLEARDTScorer_reldir=../../tools/CLEARDTScorer
CLEARDTScorer=${CLEARDTScorer_reldir}/${CLEARDTScorer_exec}
endif

CLEARDTTC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${CLEARDTTC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${CLEARDTScorer_tester_exec} ${CLEARDTScorer}
	@(${PERL} ${CLEARDTScorer_tester} ${CLEARDTScorer} $@)

makecheckfiles: ${CLEARDTScorer_tester_exec} ${CLEARDTScorer}
	@(${PERL} ${CLEARDTScorer_tester} ${CLEARDTScorer} $@)

makecompcheckfiles: ${CLEARDTScorer_tester_exec} ${CLEARDTScorer}
	@(${PERL} ${CLEARDTScorer_tester} ${CLEARDTScorer} $@)

cleanresfiles:
	@rm -f res*.txt
