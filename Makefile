# Main F4DE directory Makefile
SHELL=/bin/bash

F4DE_BASE ?= "notset"

##########

F4DE_VERSION=.f4de_version

all:
	@echo "NOTE: Make sure to run this Makefile from the source directory"
	@echo ""
	@make from_installdir
	@make dist_head
	@echo "Version Information : " `cat ${F4DE_VERSION}`
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
	@echo "  SQLitetoolscheck  only run checks for the SQLite_tools subsection"
	@echo "  DEVAcheck       only run checks for the DEVA subsection"
	@echo ""
	@echo "[install section -- requires the F4DE_BASE environment variable set]"
	@echo "  install         to install all the softwares"
	@echo "  TV08install     only install the TrecVid08 subsection"
	@echo "  CLEAR07install  only install the CLEAR07 subsection"
	@echo "  AVSS09install   only install the AVSS09 subsection"
	@echo "  VidATinstall    only install the VidAT tools set"
	@echo "  SQLitetoolsinstall  only install the SQLite tools set"
	@echo "  DEVAinstall     only install the DEVA subsection"
	@echo ""
	@make from_installdir

from_installdir:
	@echo "** Checking that \"make\" is called from the source directory"
	@test -f ${F4DE_VERSION}


########## Install

install:
	@make TV08install
	@make CLEAR07install
	@make AVSS09install
	@make VidATinstall
	@make SQLitetoolsinstall
	@make DEVAinstall

#####

install_noman:
	@make TV08install_noman
	@make CLEAR07install
	@make AVSS09install_noman
	@make VidATinstall
	@make SQLitetoolsinstall
	@make DEVAinstall_noman

#####

CM_DIR=common
COMMONTOOLS=tools/{DETEdit/DETEdit.pl,DETMerge/DETMerge.pl,DETUtil/DETUtil.pl}
VIDATDIR=${CM_DIR}/tools/VidAT
SQLITETOOLSDIR=${CM_DIR}/tools/SQLite_tools

commoninstall:
	@make from_installdir
	@make install_head
	@echo "** Installing common files"
	@perl installer.pl ${F4DE_BASE} lib ${CM_DIR}/lib/*.pm
	@perl installer.pl -x -r ${F4DE_BASE} bin ${CM_DIR}/${COMMONTOOLS}

VidATinstall:
	@echo "** Installing VidAT"
	@perl installer.pl ${F4DE_BASE} lib ${VIDATDIR}/*.pm
	@perl installer.pl -x -r ${F4DE_BASE} bin ${VIDATDIR}/*.pl

SQLitetoolsinstall:
	@echo "** Installing SQLite_tools"
	@perl installer.pl -x -r ${F4DE_BASE} bin ${SQLITETOOLSDIR}/*.pl


#####

TV08DIR=TrecVid08
TV08TOOLS_MAN=tools/{TVED-SubmissionChecker/TVED-SubmissionChecker.pl,TV08MergeHelper/TV08MergeHelper.pl,TV08Scorer/TV08Scorer.pl,TV08ViperValidator/{TV08_BigXML_ValidatorHelper.pl,TV08ViperValidator.pl}}
TV08TOOLS=tools/{TVED-SubmissionChecker/{TVED-SubmissionChecker.pl,TV{08,09,10S}ED-SubmissionChecker.sh},TV08MergeHelper/TV08MergeHelper.pl,TV08Scorer/TV08Scorer.pl,TV08ViperValidator/{TV08_BigXML_ValidatorHelper.pl,TV08ViperValidator.pl}}

TV08install:
	@make TV08install_common
	@make TV08install_man
	@echo ""
	@echo ""

TV08install_common:
	@echo ""
	@echo "********** Installing TrecVid08 tools"
	@make commoninstall
	@echo "** Installing TrecVid08 files"
	@perl installer.pl ${F4DE_BASE} lib ${TV08DIR}/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data ${TV08DIR}/data/*.xsd
	@perl installer.pl ${F4DE_BASE} lib/data ${TV08DIR}/data/*.perl
	@perl installer.pl -x -r ${F4DE_BASE} bin ${TV08DIR}/${TV08TOOLS}

TV08install_man:
	@perl installer.pl ${F4DE_BASE} man/man1 ${TV08DIR}/man/*.1

TV08install_noman:
	@make TV08install_common
	@echo "** NOT installing man files"
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
AV09TOOLS_MAN=tools/{AVSS09Scorer/AVSS09Scorer.pl,AVSS09ViPERValidator/AVSS09ViPERValidator.pl,AVSS-SubmissionChecker/AVSS-SubmissionChecker.pl}
AV09TOOLS=tools/{AVSS09Scorer/AVSS09Scorer.pl,AVSS09ViPERValidator/AVSS09ViPERValidator.pl,AVSS-SubmissionChecker/{AVSS-SubmissionChecker.pl,AVSS09-SubmissionChecker.sh}}

AVSS09install:
	@make AVSS09install_common
	@make AVSS09install_man
	@echo ""
	@echo ""

AVSS09install_common:
	@echo ""
	@echo "********** Installing AVSS09 tools"
	@echo "  (Relies on CLEAR07, running installer)"
	@make CLEAR07install
	@echo "** Installing AVSS09 files"
	@perl installer.pl ${F4DE_BASE} lib ${AV09DIR}/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data ${AV09DIR}/data/*.xsd
	@perl installer.pl ${F4DE_BASE} lib/data ${AV09DIR}/data/*.perl
	@perl installer.pl -x -r ${F4DE_BASE} bin ${AV09DIR}/${AV09TOOLS}

AVSS09install_man:
	@perl installer.pl ${F4DE_BASE} man/man1 ${AV09DIR}/man/*.1

AVSS09install_noman:
	@make AVSS09install_common
	@echo "** NOT installing man file"
	@echo ""
	@echo ""

#####

DEVADIR=DEVA
DEVATOOLS=tools/DEVA_{cli/DEVA_cli,filter/DEVA_filter,sci/DEVA_sci}.pl
DEVATOOLS_MAN=tools/DEVA_cli/DEVA_cli.pl

DEVAinstall_noman:
	@echo ""
	@echo "********** Installing DEVA tools"
	@make commoninstall
	@echo "** Installing DEVA tools"
	@perl installer.pl -x -r ${F4DE_BASE} bin ${DEVADIR}/${DEVATOOLS}

DEVAinstall_man:
	@make DEVAinstall_noman
	@perl installer.pl ${F4DE_BASE} man/man1 ${DEVADIR}/man/*.1


##########

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
	@make AVSS09check
#	@make SQLitetoolscheck
# SQLitetoolscheck is done as part of DEVAcheck
	@make DEVAcheck
	@echo ""
	@echo "***** All check tests successful"
	@echo ""

commoncheck:
	@echo "***** Running \"Common checks\" ..."
	@(cd ${CM_DIR}/test; make check)
	@echo ""
	@echo "***** All \"Common checks\" ran succesfully"
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

SQLitetoolscheck:
	@echo "***** Running SQLite_tools checks ..."
	@(cd ${CM_DIR}/test/SQLite_tools; make check)
	@echo ""
	@echo "***** All SQLite_tools checks ran succesfully"
	@echo ""

DEVAcheck:
	@echo "***** Running DEVA checks ..."
	@(cd ${DEVADIR}/test; make check)
	@echo ""
	@echo "***** All DEVA checks ran succesfully"
	@echo ""

check_common:
	@make from_installdir

########################################
########## For distribution purpose

VIDAT_EX_DIR=${VIDATDIR}/example
VIDAT_EX_TBZ=VidAT_example.tar.bz2

VidAT_example: ${VIDAT_EX_DIR}
	@(cd ${VIDATDIR} && tar cfj ../../../${VIDAT_EX_TBZ} --exclude CVS --exclude .DS_Store --exclude "*~" example)
	@make VidAT_example_post

VidAT_example_post: ${VIDAT_EX_TBZ}
	@echo "Created: ${VIDAT_EX_TBZ}"

#####

# 'cvsdist' can only be run by developpers
cvsdist:
	@make from_installdir
	@make dist_head
	@echo ""
	@echo ""
	@echo "***** REMEMBER to update the version number in the README file *****"
	@echo ""
	@echo ""
	@echo "Building a CVS release:" `cat ${F4DE_VERSION}`
	@rm -rf /tmp/`cat ${F4DE_VERSION}`
	@echo "CVS checkout in: /tmp/"`cat ${F4DE_VERSION}`
	@cp ${F4DE_VERSION} /tmp
	@(cd /tmp; cvs -z3 -q -d gaston:/home/sware/cvs checkout -d `cat ${F4DE_VERSION}` F4DE)
	@make dist_common

localdist:
	@make from_installdir
	@make dist_head
	@echo "Building a local copy release:" `cat ${F4DE_VERSION}`
	@rm -rf /tmp/`cat ${F4DE_VERSION}`
	@echo "Local copy in: /tmp/"`cat ${F4DE_VERSION}`
	@mkdir /tmp/`cat ${F4DE_VERSION}`
	@rsync -a . /tmp/`cat ${F4DE_VERSION}`/.
	@make dist_common

dist_head:
	@echo "***** Checking ${F4DE_VERSION}"
	@test -f ${F4DE_VERSION}
	@fgrep F4DE ${F4DE_VERSION} > /dev/null

dist_archive_pre_remove:
## CLEAR07
# Sys files
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/common/BN_{TDT,TR}/*.rdf
# Corresponding "res" files
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/CLEARDTViperValidator/res-test-2b.txt
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/CLEARTRViperValidator/res-test-1b.txt
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/CLEARDTScorer/res-test-2.txt
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/CLEARTRScorer/res-test-1[ab].txt
## BarPlot
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/tools/BarPlot/ /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/lib/BarPlot.pm
## CSVUtil
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/tools/CSVUtil/
## VidAT example
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${VIDAT_EX_DIR}
## DEVA
#	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${DEVADIR}
## CCD
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/CCD

create_mans:
# TrecVid08
	@mkdir -p /tmp/`cat ${F4DE_VERSION}`/${TV08DIR}/man
	@for i in ${TV08TOOLS_MAN}; do g=`basename $$i .pl`; pod2man /tmp/`cat ${F4DE_VERSION}`/${TV08DIR}/$$i /tmp/`cat ${F4DE_VERSION}`/${TV08DIR}/man/$$g.1; done
# AVSS09
	@mkdir -p /tmp/`cat ${F4DE_VERSION}`/${AV09DIR}/man
	@for i in ${AV09TOOLS_MAN}; do g=`basename $$i .pl`; pod2man /tmp/`cat ${F4DE_VERSION}`/${AV09DIR}/$$i /tmp/`cat ${F4DE_VERSION}`/${AV09DIR}/man/$$g.1; done
# DEVA
	@mkdir -p /tmp/`cat ${F4DE_VERSION}`/${DEVADIR}/man
	@for i in ${DEVATOOLS_MAN}; do g=`basename $$i .pl`; pod2man /tmp/`cat ${F4DE_VERSION}`/${DEVADIR}/$$i /tmp/`cat ${F4DE_VERSION}`/${DEVADIR}/man/$$g.1; done


dist_common:
	@cp ${F4DE_VERSION} /tmp
	@make dist_archive_pre_remove
	@make create_mans
	@echo ""
	@echo "Building the tar.bz2 file"
	@echo `cat ${F4DE_VERSION}`"-"`date +%Y%m%d-%H%M`.tar.bz2 > /tmp/.f4de_distname
	@echo `pwd` > /tmp/.f4de_pwd
	@(cd /tmp; tar cfj `cat /tmp/.f4de_pwd`/`cat /tmp/.f4de_distname` --exclude CVS --exclude .DS_Store --exclude "*~" `cat ${F4DE_VERSION}`)
	@echo ""
	@echo ""
	@echo "** Release ready:" `cat /tmp/.f4de_distname`
#	@make dist_clean

dist_clean:
	@rm -rf /tmp/`cat ${F4DE_VERSION}`
	@rm -f /tmp/.f4de_{distname,version,pwd}

##########

cvs-tag-current-distribution:
	@make from_installdir
	@make dist_head
	@echo "Tagging the current CVS for distribution as '"`sed 's/\./dot/' ${F4DE_VERSION}`"'"
	@(echo -n "Starting actual tag in "; for i in 10 9 8 7 6 5 4 3 2 1 0; do echo -n "$$i "; sleep 1; done; echo " -- Tagging")
	@cvs tag `sed 's/\./dot/' ${F4DE_VERSION}`
