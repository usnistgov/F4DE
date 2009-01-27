all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd ../../lib; perl -I . -I ../../common/lib -e 'use OBox; OBox::unitTest()')
	@(cd ../../lib; perl -I . -I ../../common/lib -e 'use Object; Object::unitTest()')
	@(cd ../../lib; perl -I . -I ../../common/lib -e 'use Frame; Frame::unitTest()')
	@echo "***** All tests ran succesfully"

makecheckfiles:
	@echo "***** All files generated succesfully"

cleanresfiles:
	@echo "***** All results files removed"
