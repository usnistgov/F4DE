# Main F4DE directory Makefile

F4DE_BASE ?= "notset"

##########

all:
	@echo "NOTE: Make sure to run this Makefile from the source directory"
	@echo ""
	@echo "Possible options are:"
	@echo ""
	@echo "[checks section -- recommended to run before installation -- DO NOT set the F4DE_BASE environment variable]"
	@echo "(note that each tool individual test can take from a few seconds to a few minutes to complete)"
	@echo "  mincheck        run only a few common checks"
	@echo "  check           to run checks on all included evaluation tools"
	@echo "  TV08check       only run checks for the TrecVid08 subsection"
	@echo "  CLEAR07check    only run checks for the CLEAR07 subsection"
	@echo "  AVSS09check     only run checks for the AVSS09 subsection"
	@echo ""
	@echo "[install section -- requires the F4DE_BASE environment variable set]"
	@echo "  install         to install all the softwares"
	@echo "  TV08install     only install the TrecVid08 subsection"
	@echo "  CLEAR07install  only install the CLEAR07 subsection"
	@echo "  AVSS09install   only install the AVSS09 subsection"
	@echo ""
	@make from_installdir

from_installdir:
	@echo "** Checking that \"make\" is called from the source directory"
	@test -f .f4de_version


########## Install

install:
	@make TV08install
	@make CLEAR07install
	@make AVSS09install

commoninstall:
	@make from_installdir
	@make install_head
	@echo "** Installing common files"
	@perl installer.pl ${F4DE_BASE} lib common/lib/*.pm

TV08install:
	@echo ""
	@echo "********** Installing TrecVid08 tools"
	@make commoninstall
	@echo "** Installing TrecVid08 files"
	@perl installer.pl ${F4DE_BASE} lib TrecVid08/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data TrecVid08/data/*.xsd
	@perl installer.pl -x -r ${F4DE_BASE} bin TrecVid08/tools/TV08ED-SubmissionChecker/TV08ED-SubmissionChecker.pl TrecVid08/tools/TV08MergeHelper/TV08MergeHelper.pl TrecVid08/tools/TV08Scorer/TV08Scorer.pl TrecVid08/tools/TV08ViperValidator/TV08_BigXML_ValidatorHelper.pl TrecVid08/tools/TV08ViperValidator/TV08ViperValidator.pl 
	@echo ""
	@echo ""

CLEAR07install:
	@echo ""
	@echo "********** Installing CLEAR07 tools"
	@make commoninstall
	@echo "** Installing CLEAR07 files"
	@perl installer.pl ${F4DE_BASE} lib CLEAR07/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data CLEAR07/data/*.xsd
	@perl installer.pl -x -r ${F4DE_BASE} bin CLEAR07/tools/CLEARDTScorer/CLEARDTScorer.pl CLEAR07/tools/CLEARDTViperValidator/CLEARDTViperValidator.pl CLEAR07/tools/CLEARTRScorer/CLEARTRScorer.pl CLEAR07/tools/CLEARTRViperValidator/CLEARTRViperValidator.pl
	@echo ""
	@echo ""

AVSS09install:
	@echo ""
	@echo "********** Installing AVSS09 tools"
	@echo "  (Relies on CLEAR07, running installer)"
	@make CLEAR07install
	@echo "** Installing AVSS09 files"
	@perl installer.pl ${F4DE_BASE} lib AVSS09/lib/*.pm
	@perl installer.pl -x -r ${F4DE_BASE} bin AVSS09/tools/AVSS09Scorer/AVSS09Scorer.pl AVSS09/tools/AVSS09ViPERValidator/AVSS09ViPERValidator.pl
	@echo ""
	@echo ""

install_head:
	@echo "** Checking that the F4DE_BASE environment variable is set"
	@test ${F4DE_BASE}
	@test ${F4DE_BASE} != "notset"
	@echo "** Checking that the F4DE_BASE is a writable directory"
	@test -d ${F4DE_BASE}
	@test -w ${F4DE_BASE}


########## Checks

mincheck:
	@make check_common
	@make commoncheck

check:
	@make commoncheck
	@make TV08check
	@make CLEAR07check
	@echo ""
	@echo "***** All check tests successful"
	@echo ""

TV08check:
	@echo "***** Running TrecVid08 checks ..."
	@(cd TrecVid08/test; make check)
	@echo ""
	@echo "***** All TrecVid08 checks ran succesfully"
	@echo ""

CLEAR07check:
	@echo "***** Running CLEAR07 checks ..."
	@(cd CLEAR07/test; make check)
	@echo ""
	@echo "***** All CLEAR07 checks ran succesfully"
	@echo ""

AVSS09check:
	@echo "***** Running AVSS09 checks ..."
	@(cd AVSS09/test; make check)
	@echo ""
	@echo "***** All AVSS09 checks ran succesfully"
	@echo ""

commoncheck:
	@echo "***** Running \"Common checks\" ..."
	@(cd common/test; make check)
	@echo ""
	@echo "***** All \"Common checks\" ran succesfully"
	@echo ""

check_common:
	@make from_installdir

########################################
########## For distribution purpose


# 'cvsdist' can only be run by developpers
cvsdist:
	@make from_installdir
	@make dist_head
	@echo "Building a CVS release:" `cat .f4de_version`
	@rm -rf /tmp/`cat .f4de_version`
	@echo "CVS checkout in: /tmp/"`cat .f4de_version`
	@cp .f4de_version /tmp
	@(cd /tmp; cvs -z3 -q -d gaston:/home/sware/cvs checkout -d `cat .f4de_version` F4DE)
	@make dist_common

localdist:
	@make from_installdir
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

dist_archive_pre_remove:
## CLEAR07
# Sys files
	@rm -f /tmp/`cat .f4de_version`/CLEAR07/test/common/{BN_{{F,T}DT,TR},{M,}MR_FDT}/*.rdf
# Corresponding "res" files
	@rm -f /tmp/`cat .f4de_version`/CLEAR07/test/CLEARDTViperValidator/res-test-{1,2,3,5}b.txt
	@rm -f /tmp/`cat .f4de_version`/CLEAR07/test/CLEARTRViperValidator/res-test-1b.txt
	@rm -f /tmp/`cat .f4de_version`/CLEAR07/test/CLEARDTScorer/res-test-{1,2,3,4}.txt
	@rm -f /tmp/`cat .f4de_version`/CLEAR07/test/CLEARTRScorer/res-test-1{a,b}.txt

dist_common:
	@cp .f4de_version /tmp
	@make dist_archive_pre_remove
	@echo ""
	@echo "Building the tar.bz2 file"
	@echo `cat .f4de_version`"-"`date +%Y%m%d-%H%M`.tar.bz2 > /tmp/.f4de_distname
	@echo `pwd` > /tmp/.f4de_pwd
	@(cd /tmp; tar cfj `cat /tmp/.f4de_pwd`/`cat /tmp/.f4de_distname` --exclude CVS --exclude .DS_Store --exclude "*~" `cat .f4de_version`)
	@echo ""
	@echo ""
	@echo "** Release ready:" `cat /tmp/.f4de_distname`
#	@make dist_clean

dist_clean:
	@rm -rf /tmp/`cat .f4de_version`
	@rm -f /tmp/.f4de_{distname,version,pwd}
