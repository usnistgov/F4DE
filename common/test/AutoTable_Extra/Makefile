# common/test/AutoTable_Extra

AT_tester=AutoTable_tester.pl

F4DEC_lib=../../../common/lib
PERL=perl -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

makecompcheckfiles makecheckfiles check:
	@(${PERL} ${AT_tester} $@)

cleanresfiles:
	@rm -f res*.txt
