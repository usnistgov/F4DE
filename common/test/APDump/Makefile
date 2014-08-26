# DEVA/test/MTest

APDump_tester=APDump_tester.pl

ifdef F4DE_TEST_INSTALLDIR
APDump=../../../bin/APDump
else
APDump_exec=APDump.pl
APDump_reldir=../../tools/APDump
APDump=${APDump_reldir}/${APDump_exec}
endif

F4DEC_lib=../../../common/lib
PERL=perl -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

makecompcheckfiles makecheckfiles check: \
	${APDump_tester} ${APDump}
	@(${PERL} ${APDump_tester} ${APDump} $@)
	@make cleanresdir

cleanresdir:
	@rm -rf res-test*.txt.dir

cleanresfiles:
	@rm -f res*.txt
