# common/test
include ../../Makefile_common

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@${F4DEPERL} -I../lib -I../../../common/lib -I../../lib pre_tests.pl
	@echo "* Running unit tests"
	@(cd ../lib; ${F4DEPERL} -I. -e 'use DETCurveSet; DETCurveSet::unitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use DETCurve; DETCurve::globalMeasureUnitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use DETCurve; DETCurve::unitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use DETCurveGnuplotRenderer; DETCurveGnuplotRenderer::unitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use TrialsFuncs; TrialsFuncs::unitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use MetricNormLinearCostFunct; MetricNormLinearCostFunct::unitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use MetricLinearCostFunct; MetricLinearCostFunct::unitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use MetricTWV; MetricTWV::unitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use ViperFramespan; ViperFramespan::unit_test(0, 1);')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use BipartiteMatch; BipartiteMatch::unit_test(1);')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use PropList; PropList::unit_test(1);')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use SimpleAutoTable; SimpleAutoTable::unitTest(1);')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use MMisc; MMisc::unitTest();')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use TranscriptHolder; TranscriptHolder::unitTest()')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use MetricRo; MetricRo::unitTest()')
	@(cd AutoTable_Extra; make check)
	@(cd DETUtil; make check)
	@(cd APDump; make check)
	@echo ""
	@echo "***** All tests ran succesfully"

makecheckfiles:
	@(${F4DEPERL} -I ../lib -e 'use DETCurveGnuplotRenderer; DETCurveGnuplotRenderer::renderUnitTest("rendtmp")')
	@(${F4DEPERL} -I ../lib ../tools/DETUtil/DETUtil.pl -o DETUtil.g1.png ./rendtmp/g1.nd.nd*srl.gz)
	@(${F4DEPERL} -I ../lib ../tools/DETMerge/DETMerge.pl -o Merge.g1.srl ./rendtmp/g1.nd.nd*srl.gz)
	@(${F4DEPERL} -I ../lib ../tools/DETUtil/DETUtil.pl -o DETUtil.g1.merge.png -p 'ExtraPoint=paeg 1:.01:0.4:2:2:rgb "#ff00ff":left' -p 'ExtraPoint=paeg 1:.2:0.8:1:2:rgb "#ff00ff":' Merge.g1.srl.gz ./rendtmp/g1.nd.nd*srl.gz)
	@echo "***** All files generated succesfully"

cleanresfiles:
	@rm -rf rendtmp *png *srl.gz
	@echo "***** All results files removed"

OpenHaRT_minirelease_check:
	@${F4DEPERL} -I../lib -I../../../common/lib -I../../lib pre_tests.pl $@
	@echo "* Running unit tests"
	@(cd ../lib; ${F4DEPERL} -I. -e 'use PropList; PropList::unit_test(1);')
	@(cd ../lib; ${F4DEPERL} -I. -e 'use MMisc; MMisc::unitTest();')
	@echo ""
	@(cd AutoTable_Extra; make check)
	@(cd SQLite_tools; make check)
	@echo "***** All tests ran succesfully"
