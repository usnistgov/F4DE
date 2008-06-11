all:
	@echo "Possible options are:"
	@echo "  check       to run a check on all included evaluation tools"
	@echo "  TV08check   only run checks for the TrecVid08 subsection"
	@echo "  install     to install the software (requires the F4DE_BASE environment variable set)"

install:
	@echo "Nothing to do for install"

check:
	@(make TV08check)
	@echo ""
	@echo "***** All check tests successful"

TV08check:
	@echo "***** Running TV08check tests ..."
	@(cd TrecVid08/test; make check)
	@echo "***** All TV08check tests ran succesfully"

cvsdist:
	@make dist_head
	@echo "Building a CVS release:" `cat .f4de_version`
	@rm -rf /tmp/`cat .f4de_version`
	@echo "CVS checkout in: /tmp/"`cat .f4de_version`
	@cp .f4de_version /tmp
	@(cd /tmp; cvs -q -d gaston:/home/sware/cvs checkout -d `cat .f4de_version` F4DE)
	@make dist_common

localdist:
	@make dist_head
	@echo "Building a local copy release:" `cat .f4de_version`
	@rm -rf /tmp/`cat .f4de_version`
	@echo "Local copy in: /tmp/"`cat .f4de_version`
	@mkdir /tmp/`cat .f4de_version`
	@rsync -a . /tmp/`cat .f4de_version`/.
	@make dist_common

dist_head:
	@echo "***** Checking .f4de_version"
	@test -f .f4de_version
	@fgrep F4DE .f4de_version > /dev/null

dist_common:
	@echo ""
	@echo "***** Running all tests"
	@cp .f4de_version /tmp
	@(cd /tmp/`cat .f4de_version`; make check)
	@echo "Building the tar.bz2 file"
	@echo `cat .f4de_version`"-"`date +%Y%m%d-%H%M`.tar.bz2 > /tmp/.f4de_distname
	@echo `pwd` > /tmp/.f4de_pwd
	@(cd /tmp; tar cfj `cat /tmp/.f4de_pwd`/`cat /tmp/.f4de_distname` --exclude CVS --exclude .DS_Store --exclude "*~" `cat .f4de_version`)
	@echo ""
	@echo ""
	@echo "** Release ready:" `cat /tmp/.f4de_distname`
	@make dist_clean

dist_clean:
	@rm -rf /tmp/`cat .f4de_version`
	@rm -f /tmp/.f4de_{distname,version,pwd}
