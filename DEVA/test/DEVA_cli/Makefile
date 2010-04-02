# DEVA/test/DEVA_cli

DEVA_cli_tester=DEVA_cli_tester.pl

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
	${DEVA_cli_tester} ${DEVA_cli}
	@(${PERL} ${DEVA_cli_tester} ${DEVA_cli} $@)

cleanresfiles:
	@rm -f res*.txt
