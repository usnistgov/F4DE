# DEVA/test

F4DEC_lib=../../common/lib
PERL=perl -I${F4DEC_lib}

PRE_tests=Pre/pre_tests.pl

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

makecompcheckfiles makecheckfiles check:
	@(cd ../../common/test/SQLite_tools; make $@)
	@(${PERL} ${PRE_tests})	
	@(cd DEVA_cli; make $@)
	@echo "***** All tests ran succesfully"
