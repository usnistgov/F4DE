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

#####

CM_DIR=common

commoninstall:
	@make from_installdir
	@make install_head
	@echo "** Installing common files"
	@perl installer.pl ${F4DE_BASE} lib ${CM_DIR}/lib/*.pm

#####

TV08DIR=TrecVid08
TV08TOOLS=tools/{TV08ED-SubmissionChecker/TV08ED-SubmissionChecker.pl,TV08MergeHelper/TV08MergeHelper.pl,TV08Scorer/TV08Scorer.pl,TV08ViperValidator/{TV08_BigXML_ValidatorHelper.pl,TV08ViperValidator.pl}}

TV08install:
	@echo ""
	@echo "********** Installing TrecVid08 tools"
	@make commoninstall
	@echo "** Installing TrecVid08 files"
	@perl installer.pl ${F4DE_BASE} lib ${TV08DIR}/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data ${TV08DIR}/data/*.xsd
	@perl installer.pl -x -r ${F4DE_BASE} bin ${TV08DIR}/${TV08TOOLS}
	@perl installer.pl ${F4DE_BASE} man/man1 ${TV08DIR}/man/*.1
	@echo ""
	@echo ""

#####

CL07DIR=CLEAR07
CL07TOOLS=tools/{CLEARDTScorer/CLEARDTScorer.pl,CLEARDTViperValidator/CLEARDTViperValidator.pl,CLEARTRScorer/CLEARTRScorer.pl,CLEARTRViperValidator/CLEARTRViperValidator.pl}

CLEAR07install:
	@echo ""
	@echo "********** Installing CLEAR07 tools"
	@make commoninstall
	@echo "** Installing CLEAR07 files"
	@perl installer.pl ${F4DE_BASE} lib ${CL07DIR}/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data ${CL07DIR}/data/*.xsd
	@perl installer.pl -x -r ${F4DE_BASE} bin ${CL07DIR}/${CL07TOOLS}
	@echo ""
	@echo ""

#####

AV09DIR=AVSS09
AV09TOOLS=tools/{AVSS09Scorer/AVSS09Scorer.pl,AVSS09ViPERValidator/AVSS09ViPERValidator.pl}

AVSS09install:
	@echo ""
	@echo "********** Installing AVSS09 tools"
	@echo "  (Relies on CLEAR07, running installer)"
	@make CLEAR07install
	@echo "** Installing AVSS09 files"
	@perl installer.pl ${F4DE_BASE} lib ${AV09DIR}/lib/*.pm
	@perl installer.pl -x -r ${F4DE_BASE} bin ${AV09DIR}/${AV09TOOLS}
	@perl installer.pl ${F4DE_BASE} man/man1 ${AV09DIR}/man/*.1
	@echo ""
	@echo ""

#####

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
	@(cd ${TV08DIR}/test; make check)
	@echo ""
	@echo "***** All TrecVid08 checks ran succesfully"
	@echo ""

CLEAR07check:
	@echo "***** Running CLEAR07 checks ..."
	@(cd ${CL07DIR}/test; make check)
	@echo ""
	@echo "***** All CLEAR07 checks ran succesfully"
	@echo ""

AVSS09check:
	@echo "***** Running AVSS09 checks ..."
	@(cd ${AV09DIR}/test; make check)
	@echo ""
	@echo "***** All AVSS09 checks ran succesfully"
	@echo ""

commoncheck:
	@echo "***** Running \"Common checks\" ..."
	@(cd ${CM_DIR}/test; make check)
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
	@rm -f /tmp/`cat .f4de_version`/${CL07DIR}/test/common/{BN_{[FT]DT,TR},{M,}MR_FDT}/*.rdf
# Corresponding "res" files
	@rm -f /tmp/`cat .f4de_version`/${CL07DIR}/test/CLEARDTViperValidator/res-test-[1235]b.txt
	@rm -f /tmp/`cat .f4de_version`/${CL07DIR}/test/CLEARTRViperValidator/res-test-1b.txt
	@rm -f /tmp/`cat .f4de_version`/${CL07DIR}/test/CLEARDTScorer/res-test-[1234].txt
	@rm -f /tmp/`cat .f4de_version`/${CL07DIR}/test/CLEARTRScorer/res-test-1[ab].txt

create_mans:
# TrecVid08
	@mkdir -p /tmp/`cat .f4de_version`/${TV08DIR}/man
	@for i in ${TV08TOOLS}; do g=`basename $$i .pl`; pod2man /tmp/`cat .f4de_version`/${TV08DIR}/$$i /tmp/`cat .f4de_version`/${TV08DIR}/man/$$g.1; done
# AVSS09
	@mkdir -p /tmp/`cat .f4de_version`/${AV09DIR}/man
	@for i in ${AV09TOOLS}; do g=`basename $$i .pl`; pod2man /tmp/`cat .f4de_version`/${AV09DIR}/$$i /tmp/`cat .f4de_version`/${AV09DIR}/man/$$g.1; done

dist_common:
	@cp .f4de_version /tmp
	@make dist_archive_pre_remove
	@make create_mans
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
