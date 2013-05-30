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
	@echo "  perl_install    a helper to try and install required Perl packages  -- make sure the tools listed in the README's 'INSTALLATION' 'Prerequisites' section are installed first. Also insure that Perl's 'cpanp' tool is configured and ready to be used (please note you might be prompted to follow dependencies)"
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
	@echo "  KWSEvalcheck    only run checks for the KWSEval subsection"
	@echo "NOTE: for each tool specific check it is first required to run first 'make mincheck' to insure that the minimum requirements are met"
	@echo ""
	@echo "[install section -- requires the F4DE_BASE environment variable set]"
	@echo "  install         to install all the softwares"
	@echo "  TV08install     only install the TrecVid08 subsection"
	@echo "  CLEAR07install  only install the CLEAR07 subsection"
	@echo "  AVSS09install   only install the AVSS09 subsection"
	@echo "  VidATinstall    only install the VidAT tools set"
	@echo "  SQLitetoolsinstall  only install the SQLite tools set"
	@echo "  DEVAinstall     only install the DEVA subsection"
	@echo "  KWSEvalinstall  only install the KWSEval subsection"
	@echo "NOTE: before installing a tool subset, run both 'make mincheck' and the check related to this tool to confirm that your system has all the required components to run the tool"
	@echo ""

from_installdir:
	@echo "** Checking that \"make\" is called from the source directory"
	@test -f ${F4DE_VERSION}


########## Install

install:
	@make commoninstall
	@make TV08install
	@make CLEAR07install
	@make AVSS09install
	@make VidATinstall
	@make SQLitetoolsinstall
	@make DEVAinstall
	@make KWSEvalinstall

#####

install_noman:
	@make commoninstall_noman
	@make TV08install_noman
	@make CLEAR07install
	@make AVSS09install_noman
	@make VidATinstall
	@make SQLitetoolsinstall
	@make DEVAinstall_noman
	@make KWSEvalinstall

#####

CM_DIR=common
COMMONTOOLS=tools/{DETEdit/DETEdit.pl,DETMerge/DETMerge.pl,DETUtil/DETUtil.pl,xmllintTools/xsdxmllint.pl}
COMMONTOOLS_MAN=tools/DETUtil/DETUtil.pl
VIDATDIR=${CM_DIR}/tools/VidAT
SQLITETOOLSDIR=${CM_DIR}/tools/SQLite_tools

commoninstall:
	@make commoninstall_common
	@make commoninstall_man

commoninstall_common:
	@make from_installdir
	@make install_head
	@echo "** Installing common files"
	@perl installer.pl ${F4DE_BASE} lib ${CM_DIR}/lib/*.pm
	@perl installer.pl -x -r ${F4DE_BASE} bin ${CM_DIR}/${COMMONTOOLS}

commoninstall_man:
	@perl installer.pl ${F4DE_BASE} man/man1 ${CM_DIR}/man/*.1

commoninstall_noman:
	@make commoninstall_common
	@echo "** NOT installing man files"
	@echo ""
	@echo ""

VidATinstall:
	@echo "** Installing VidAT"
	@make commoninstall_common
	@perl installer.pl ${F4DE_BASE} lib ${VIDATDIR}/*.pm
	@perl installer.pl -x -r ${F4DE_BASE} bin ${VIDATDIR}/*.pl

SQLitetoolsinstall:
	@echo "** Installing SQLite_tools"
	@make commoninstall_common
	@perl installer.pl -x -r ${F4DE_BASE} bin ${SQLITETOOLSDIR}/*.pl

#####

TV08DIR=TrecVid08
TV08TOOLS=tools/{TVED-SubmissionChecker/{TVED-SubmissionChecker.pl,TV{08,09,1{0,1,2}S}ED-SubmissionChecker.sh},TV08MergeHelper/TV08MergeHelper.pl,TV08Scorer/TV08Scorer.pl,TV08ViperValidator/{TV08_BigXML_ValidatorHelper.pl,TV08ViperValidator.pl}}
TV08TOOLS_MAN=tools/{TVED-SubmissionChecker/TVED-SubmissionChecker.pl,TV08MergeHelper/TV08MergeHelper.pl,TV08Scorer/TV08Scorer.pl,TV08ViperValidator/{TV08_BigXML_ValidatorHelper.pl,TV08ViperValidator.pl}}

TV08install:
	@make TV08install_common
	@make TV08install_man
	@echo ""
	@echo ""

TV08install_common:
	@echo ""
	@echo "********** Installing TrecVid08 tools"
	@make commoninstall_common
	@echo "** Installing TrecVid08 files"
	@perl installer.pl ${F4DE_BASE} lib ${TV08DIR}/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data ${TV08DIR}/data/*.xsd
	@perl installer.pl ${F4DE_BASE} lib/data ${TV08DIR}/data/*.perl
	@perl installer.pl -x -r ${F4DE_BASE} bin ${TV08DIR}/${TV08TOOLS}

TV08install_man:
	@perl installer.pl ${F4DE_BASE} man/man1 ${TV08DIR}/man/*.1
	@make commoninstall_man

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
	@make commoninstall_common
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
MEDTOOLS=tools/MED-SubmissionChecker/{MED-SubmissionChecker.pl,TV1{1,2}MED-SubmissionChecker.sh}
DEVATOOLS_MAN=tools/DEVA_cli/DEVA_cli.pl

DEVAinstall:
	@make DEVAinstall_common
	@make DEVAinstall_man
	@echo ""
	@echo ""

DEVAinstall_common:
	@echo ""
	@echo "********** Installing DEVA tools"
	@make commoninstall_common
	@make SQLitetoolsinstall
	@echo "** Installing DEVA tools"
	@perl installer.pl -x -r ${F4DE_BASE} bin ${DEVADIR}/${DEVATOOLS}
	@perl installer.pl -x -r ${F4DE_BASE} bin ${DEVADIR}/${MEDTOOLS}
	@perl installer.pl ${F4DE_BASE} lib/data ${DEVADIR}/data/*.sql
	@perl installer.pl ${F4DE_BASE} lib/data ${DEVADIR}/data/*.perl

DEVAinstall_man:
	@perl installer.pl ${F4DE_BASE} man/man1 ${DEVADIR}/man/*.1
	@make commoninstall_man

DEVAinstall_noman:
	@make DEVAinstall_common
	@echo "** NOT installing man file"
	@echo ""
	@echo ""

##########

KWSEVALDIR=KWSEval
KWSEVALTOOLS=tools/{KWSEval/KWSEval.pl,KWSListGenerator/KWSListGenerator.pl,ValidateKWSList/ValidateKWSList.pl,ValidateTermList/ValidateTermList.pl,ValidateTM/ValidateTM.pl,KWSEval-XMLvalidator/KWSEval-XMLvalidator.pl,KWSEval-SubmissionChecker/{KWSEval-SubmissionChecker.pl,KWS1{2,3}-SubmissionChecker.sh}}
KWSEVALBABEL=BABEL/Participants/BABEL{_Scorer.pl,1{2,3}_Scorer.sh}

KWSEvalinstall:
	@make KWSEvalinstall_common
	@echo ""
	@echo ""

KWSEvalinstall_common:
	@echo ""
	@echo "********** Installing KWSEval tools"
	@make commoninstall_common
	@perl installer.pl -x -r ${F4DE_BASE} bin ${KWSEVALDIR}/${KWSEVALTOOLS}
	@perl installer.pl -x -r ${F4DE_BASE} bin ${KWSEVALDIR}/${KWSEVALBABEL}
	@perl installer.pl ${F4DE_BASE} lib ${KWSEVALDIR}/lib/*.pm
	@perl installer.pl ${F4DE_BASE} lib/data ${KWSEVALDIR}/data/*.xsd
	@perl installer.pl ${F4DE_BASE} lib/data ${KWSEVALDIR}/data/*.perl


##########

check_f4debase_set:
	@echo "** Checking that the F4DE_BASE environment variable is set"
	@test ${F4DE_BASE}
	@test ${F4DE_BASE} != "notset"

check_f4debase_notset:
	@echo "** Checking that the F4DE_BASE environment variable is NOT set"
	@test ${F4DE_BASE} == "notset"

install_head:
	@make check_f4debase_set
	@echo "** Checking that the F4DE_BASE is a writable directory"
	@test -d ${F4DE_BASE}
	@test -w ${F4DE_BASE}


########## Checks

mincheck:
	@make check_common
	@make check_f4debase_notset
	@make commoncheck

check:
	@make mincheck
	@make TV08check
	@make CLEAR07check
	@make AVSS09check
#	@make SQLitetoolscheck
# SQLitetoolscheck is done as part of DEVAcheck
	@make DEVAcheck
	@make KWSEvalcheck
	@echo ""
	@echo "***** All check tests successful"
	@echo ""

commoncheck:
	@echo "***** Running \"Common checks\" ..."
	@(cd ${CM_DIR}/test; make check)
	@echo ""
	@echo "***** All \"Common checks\" ran successfully"
	@echo ""

TV08check:
	@echo "***** Running TrecVid08 checks ..."
	@(cd ${TV08DIR}/test; make check)
	@echo ""
	@echo "***** All TrecVid08 checks ran successfully"
	@echo ""

CLEAR07check:
	@echo "***** Running CLEAR07 checks ..."
	@(cd ${CL07DIR}/test; make check)
	@echo ""
	@echo "***** All CLEAR07 checks ran successfully"
	@echo ""

AVSS09check:
	@echo "***** Running AVSS09 checks ..."
	@(cd ${AV09DIR}/test; make check)
	@echo ""
	@echo "***** All AVSS09 checks ran successfully"
	@echo ""

SQLitetoolscheck:
	@echo "***** Running SQLite_tools checks ..."
	@(cd ${CM_DIR}/test/SQLite_tools; make check)
	@echo ""
	@echo "***** All SQLite_tools checks ran successfully"
	@echo ""

DEVAcheck:
	@echo "***** Running DEVA checks ..."
	@(cd ${DEVADIR}/test; make check)
	@echo ""
	@echo "***** All DEVA checks ran successfully"
	@echo ""

KWSEvalcheck:
	@echo "***** Running KWSEval checks ..."
	@(cd ${KWSEVALDIR}/test; make check)
	@echo ""
	@echo "***** All KWSEval checks ran successfully"
	@echo ""

check_common:
	@make from_installdir


########## perl_install

perl_install:
	@echo "***** Trying to install all perl needed modules"
	@make from_installdir
	@(cd ${CM_DIR}; make $@)
	@(cd ${TV08DIR}; make $@)
	@(cd ${CL07DIR}; make $@)
	@(cd ${AV09DIR}; make $@)
	@(cd ${DEVADIR}; make $@)
	@(cd ${KWSEVALDIR}; make $@)


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
	@echo "Building a CVS release:" `cat ${F4DE_VERSION}`
	@rm -rf /tmp/`cat ${F4DE_VERSION}`
	@echo "CVS checkout in: /tmp/"`cat ${F4DE_VERSION}`
	@cp ${F4DE_VERSION} /tmp
	@(cd /tmp; cvs -z3 -q -d gaston:/home/sware/cvs checkout -d `cat ${F4DE_VERSION}` F4DE)
	@make dist_common
	@echo ""
	@echo ""
	@echo "***** Did you REMEMBER to update the version number and date in the README file ? *****"
	@echo " do a full 'make check' from the new archive"
	@echo "   and then do a 'make cvs-tag-current-distribution' here "

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
# Main
	@rm -f /tmp/`cat ${F4DE_VERSION}`/HOWTO_Release.txt
## CLEAR07
# Sys files
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/common/BN_{TDT,TR}/*.rdf
# Corresponding "res" files
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/CLEARDTViperValidator/res-test2b.txt
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/CLEARTRViperValidator/res-test1b.txt
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/CLEARDTScorer/res-test2.txt
	@rm -f /tmp/`cat ${F4DE_VERSION}`/${CL07DIR}/test/CLEARTRScorer/res-test1[ab].txt
## BarPlot
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/tools/BarPlot/ /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/lib/BarPlot.pm
## VidAT example
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${VIDAT_EX_DIR}
## CCD
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/CCD
## R_tools
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/tools/R_tools
## KWSEval
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${KWSEVALDIR}/tools/BabelTransParse/Lang*
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${KWSEVALDIR}/BABEL/Server
	@rm -rf /tmp/`cat ${F4DE_VERSION}`/${KWSEVALDIR}/BABEL/Participants/Checks/Comps*

dist_replace:
# Replace F4DEver in SubmissionHelper_common.cfg
	@perl -i -pe 's%^(F4DEver=).+$$%$$1"'`cat ${F4DE_VERSION}`'"%' /tmp/`cat ${F4DE_VERSION}`/${KWSEVALDIR}/BABEL/Participants/SubmissionHelper_common.cfg

create_mans:
# common
	@mkdir -p /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/man
	@for i in ${COMMONTOOLS_MAN}; do g=`basename $$i .pl`; pod2man /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/$$i /tmp/`cat ${F4DE_VERSION}`/${CM_DIR}/man/$$g.1; done
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
	@make dist_replace
	@make create_mans
	@echo ""
	@echo "Building the tar.bz2 file"
	@echo `cat ${F4DE_VERSION}`"-"`date -u +%Y%m%d-%H%M`"Z.tar.bz2" > /tmp/.f4de_distname
	@echo `pwd` > /tmp/.f4de_pwd
	@(cd /tmp; tar cfj `cat /tmp/.f4de_pwd`/`cat /tmp/.f4de_distname` --exclude CVS --exclude .DS_Store --exclude "*~" `cat ${F4DE_VERSION}`)
	@md5 `cat /tmp/.f4de_distname` > `cat /tmp/.f4de_distname`.md5
	@echo ""
	@echo ""
	@echo "** Release ready:" `cat /tmp/.f4de_distname`
#	@make dist_clean

dist_clean:
	@rm -rf /tmp/`cat ${F4DE_VERSION}`
	@rm -f /tmp/.f4de_{distname,version,pwd}

#################### Special ditributions

OpH_D=F4DE-OpenHaRT_minirelease

OpenHaRT_minirelease:
	@mkdir -p ${OpH_D}/common/{lib,tools/{SQLite_tools,CSVUtil},test/{AutoTable_Extra,SQLite_tools,common}}
	@rsync -a ${F4DE_VERSION} ${OpH_D}/.
	@rsync -a common/lib/{MMisc,MErrorH,CSVHelper,PropList,AutoTable,MtSQLite,F4DE_TestCore,TranscriptHolder}.pm ${OpH_D}/common/lib/.
	@rsync -a common/tools/SQLite_tools/*.pl ${OpH_D}/common/tools/SQLite_tools/.
	@rsync -a common/tools/CSVUtil/*.pl ${OpH_D}/common/tools/CSVUtil/.
	@rsync -a common/test/{Makefile,pre_tests.pl} ${OpH_D}/common/test/.
	@rsync -a common/test/common/*.* ${OpH_D}/common/test/common/.
	@rsync -a common/test/SQLite_tools/{Makefile,*.*} ${OpH_D}/common/test/SQLite_tools/.
	@rsync -a common/test/AutoTable_Extra/{Makefile,*.*} ${OpH_D}/common/test/AutoTable_Extra/.

##############################

cvs-tag-current-distribution:
	@make from_installdir
	@make dist_head
	@echo "Tagging the current CVS for distribution as '"`sed 's/\./dot/g' ${F4DE_VERSION}`"'"
	@(echo -n "Starting actual tag in "; for i in 10 9 8 7 6 5 4 3 2 1 0; do echo -n "$$i "; sleep 1; done; echo " -- Tagging")
	@cvs tag `sed 's/\./dot/g' ${F4DE_VERSION}`
