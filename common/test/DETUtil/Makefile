# common/test/AutoTable_Extra

tester=DETUtil_tester.pl

F4DEC_lib=../../../common/lib
PERL=perl -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

makecompcheckfiles makecheckfiles check:
	@(${PERL} ${tester} $@)

cleanresfiles:
	@rm -f res*.txt
