# AVSS09/test/Pre
include ../../../Makefile_common

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@echo "***** Relying on CLEAR07: checking its preliminary tests (includes F4DE common checks)"
	@(cd ../../../CLEAR07/test/Pre; make $@)
	@echo ""
	@${F4DEPERL} -I../lib -I../../../common/lib -I../../../CLEAR07/lib -I../../lib pre_tests.pl
