# From within: test/TV08MergeHelper

TV08MergeHelper_tester=TV08MergeHelper_tester.pl

TV08MergeHelper_exec=TV08MergeHelper.pl
TV08MergeHelper_reldir=../../tools/TV08MergeHelper
TV08MergeHelper=${TV08MergeHelper_reldir}/${TV08MergeHelper_exec}

TV08_XSDPATH_rel=../../data

TV08TC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${TV08TC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:	${TV08MergeHelper_tester_exec} ${TV08MergeHelper}
	@(env TV08_XSDPATH=${TV08_XSDPATH_rel} ${PERL} ${TV08MergeHelper_tester} ${TV08MergeHelper} check)

makecheckfiles:	${TV08MergeHelper_tester_exec}
	@make cleanresfiles
	@(env TV08_XSDPATH=${TV08_XSDPATH_rel} ${PERL} ${TV08MergeHelper_tester} ${TV08MergeHelper} makecheckfiles)

makecompcheckfiles:	${TV08MergeHelper_tester_exec}
	@(env TV08_XSDPATH=${TV08_XSDPATH_rel} ${PERL} ${TV08MergeHelper_tester} ${TV08MergeHelper} makecompcheckfiles)

cleanresfiles:
	@rm -f res_*
