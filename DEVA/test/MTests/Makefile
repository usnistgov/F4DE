# DEVA/test/MTest

MTest_tester=MTest_tester.pl

DEVA_cli_exec=DEVA_cli.pl
DEVA_cli_reldir=../../tools/DEVA_cli
DEVA_cli=${DEVA_cli_reldir}/${DEVA_cli_exec}

F4DEC_lib=../../../common/lib
PERL=perl -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

makecompcheckfiles makecheckfiles check: \
	${MTest_tester} ${DEVA_cli}
	@(${PERL} ${MTest_tester} ${DEVA_cli} $@)
	@make cleanresdir

cleanresdir:
	@rm -rf res-test*.txt.dir

cleanresfiles:
	@rm -f res*.txt
