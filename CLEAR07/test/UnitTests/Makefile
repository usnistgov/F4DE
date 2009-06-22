# CLEAR07/test/UnitTests

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd ../../lib; perl -I . -I ../../common/lib -e 'use OBox; OBox::unitTest()')
	@(cd ../../lib; perl -I . -I ../../common/lib -e 'use Object; Object::unitTest()')
	@(cd ../../lib; perl -I . -I ../../common/lib -e 'use CLEARFrame; CLEARFrame::unitTest()')
	@echo "***** All tests ran succesfully"
