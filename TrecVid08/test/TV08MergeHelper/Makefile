# TrecVid08/test/TV08MergeHelper

TV08MergeHelper_tester=TV08MergeHelper_tester.pl

ifdef F4DE_TEST_INSTALLDIR
TV08MergeHelper=../../../bin/TV08MergeHelper
else
TV08MergeHelper_exec=TV08MergeHelper.pl
TV08MergeHelper_reldir=../../tools/TV08MergeHelper
TV08MergeHelper=${TV08MergeHelper_reldir}/${TV08MergeHelper_exec}
endif

TV08TC_lib=../lib
F4DEC_lib=../../../common/lib
PERL=perl -I${TV08TC_lib} -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${TV08MergeHelper_tester_exec} ${TV08MergeHelper}
	@(${PERL} ${TV08MergeHelper_tester} ${TV08MergeHelper} $@)

makecheckfiles: ${TV08MergeHelper_tester_exec} ${TV08MergeHelper}
	@(${PERL} ${TV08MergeHelper_tester} ${TV08MergeHelper} $@)

makecompcheckfiles: ${TV08MergeHelper_tester_exec} ${TV08MergeHelper}
	@(${PERL} ${TV08MergeHelper_tester} ${TV08MergeHelper} $@)

cleanresfiles:
	@rm -f res_*
