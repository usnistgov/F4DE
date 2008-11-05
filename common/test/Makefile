all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd ../lib; perl -I . -e 'use DETCurveSet; DETCurveSet::unitTest()')
	@(cd ../lib; perl -I . -e 'use DETCurve; DETCurve::unitTest()')
	@(cd ../lib; perl -I . -e 'use DETCurveGnuplotRenderer; DETCurveGnuplotRenderer::unitTest()')
	@(cd ../lib; perl -I . -e 'use Trials; Trials::unitTest()')
	@echo "***** All tests ran succesfully"

makecheckfiles:
	@(perl -I ../lib -I ../../TrecVid08/lib -e 'use DETCurveGnuplotRenderer; DETCurveGnuplotRenderer::renderUnitTest("rendtmp")')
	@(perl -I ../lib -I ../../TrecVid08/lib ../tools/DETUtil/DETUtil.pl -o DETUtil.g1.png ./rendtmp/g1.nd.nd*srl.gz)
	@(perl -I ../lib -I ../../TrecVid08/lib ../tools/DETMerge/DETMerge.pl -o Merge.g1.srl ./rendtmp/g1.nd.nd*srl.gz)
	@(perl -I ../lib -I ../../TrecVid08/lib ../tools/DETUtil/DETUtil.pl -o DETUtil.g1.merge.png Merge.g1.srl.gz ./rendtmp/g1.nd.nd*srl.gz)
	@echo "***** All files generated succesfully"

cleanresfiles:
	@rm -rf rendtmp *png *srl.gz
	@echo "***** All results files removed"
