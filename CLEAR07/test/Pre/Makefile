# CLEAR07/test/Pre

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@echo "***** F4DE common checks"
	@(cd ../../..; make mincheck)
	@echo ""
	@perl -I../lib -I../../../common/lib -I../../lib pre_tests.pl

