F4DE_BASE ?= "notset"

##########

all:
	@echo "Possible options are:"
	@echo ""
	@echo "  check         to run a check on all included evaluation tools"
	@echo "  TV08check     only run checks for the TrecVid08 subsection"
	@echo ""
	@echo "  install       to install the softwares (requires the F4DE_BASE environment variable set)"
	@echo "  TV08install   only install the TrecVid08 subsection"

########## Install

install:
	@make TV08install


commoninstall:
	@make install_head
	@echo "** Installing common files"
	@perl installer.pl ${F4DE_BASE} lib common/lib/*.pm

TV08install:
	@make commoninstall
	@echo "** Installing TrecVid08 files"
	@perl installer.pl ${F4DE_BASE} lib TrecVid08/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data TrecVid08/data/*.xsd
	@perl installer.pl -x -r ${F4DE_BASE} bin TrecVid08/tools/TV08MergeHelper/TV08MergeHelper.pl TrecVid08/tools/TV08ViperValidator/TV08ViperValidator.pl TrecVid08/tools/TV08ViperValidator/TV08_BigXML_ValidatorHelper.pl TrecVid08/tools/TV08Scorer/TV08Scorer.pl  TrecVid08/tools/TV08ED-SubmissionChecker/TV08ED-SubmissionChecker.pl

install_head:
	@echo "** Checking that the F4DE_BASE environment variable is set"
	@test ${F4DE_BASE}
	@test ${F4DE_BASE} != "notset"
	@echo "** Checking that the F4DE_BASE is a writable directory"
	@test -d ${F4DE_BASE}
	@test -w ${F4DE_BASE}
	@echo "** Checking that install is called from the source directory"
	@test -f .f4de_version


########## Checks

check:
	@(make commoncheck)
	@(make TV08check)
	@echo ""
	@echo "***** All check tests successful"

TV08check:
	@echo "***** Running TV08check tests ..."
	@(cd TrecVid08/test; make check)
	@echo "***** All TV08check tests ran succesfully"

commoncheck:
	@echo "***** Running Common tests ..."
	@(cd common/test; make check)
	@echo "***** All common tests ran succesfully"




########################################
########## For distribution purpose


# 'cvsdist' can only be run by developpers
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
	@cp .f4de_version /tmp
	@echo ""
#	@echo "***** Removing CLEAR07 Directory (for now)"
#	@(cd /tmp/`cat .f4de_version`; rm -rf CLEAR07)
#	@echo "***** Removing AVSS09 Directory (for now)"
#	@(cd /tmp/`cat .f4de_version`; rm -rf AVSS09)
#	@echo ""
#	@echo "***** Running all tests"
#	@(cd /tmp/`cat .f4de_version`; make check)
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
