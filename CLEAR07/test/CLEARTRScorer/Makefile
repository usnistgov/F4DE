# CLEAR07/test/CLEARTRScorer

CLEARTRScorer_tester=CLEARTRScorer_tester.pl

CLEARTRScorer_exec=CLEARTRScorer.pl
CLEARTRScorer_reldir=../../tools/CLEARTRScorer
CLEARTRScorer=${CLEARTRScorer_reldir}/${CLEARTRScorer_exec}

CLEARTRTC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${CLEARTRTC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${CLEARTRScorer_tester_exec} ${CLEARTRScorer}
	@(${PERL} ${CLEARTRScorer_tester} ${CLEARTRScorer} $@)

makecheckfiles: ${CLEARTRScorer_tester_exec} ${CLEARTRScorer}
	@(${PERL} ${CLEARTRScorer_tester} ${CLEARTRScorer} $@)

makecompcheckfiles: ${CLEARTRScorer_tester_exec} ${CLEARTRScorer}
	@(${PERL} ${CLEARTRScorer_tester} ${CLEARTRScorer} $@)

cleanresfiles:
	@rm -f res*.txt
