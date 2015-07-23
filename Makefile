# Main F4DE directory Makefile
SHELL=/bin/bash

##########

F4DE_VERSION=.f4de_version

all:
	@echo "NOTE: Make sure to run this Makefile from the source directory"
	@echo ""
	@make from_installdir
	@make check_head
	@echo "Version Information : " `cat ${F4DE_VERSION}`
	@make get_f4dedir
	@echo ""
	@echo "Possible options are:"
	@echo ""
	@echo "  perl_install    a helper to try and install required Perl packages  -- make sure the tools listed in the README's 'INSTALLATION' 'Prerequisites' section are installed first. Also insure that Perl's 'cpanp' tool is configured and ready to be used (please note you might be prompted to follow dependencies)"
	@echo ""
	@echo "[checks section -- run before installing]"
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
	@echo "[install section -- create symbolic links]"
	@echo "( extend your PATH with: ${F4DE_DIR}/bin"
	@echo " and MANPATH with: ${F4DE_DIR}/man )"
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

F4DE_DIR:=$(shell perl -Icommon/lib -e 'use Cwd "abs_path"; use File::Basename "dirname"; if (exists $$ENV{F4DE_DIR}) { print $$ENV{F4DE_DIR} } else { print dirname(abs_path("./installer.pl"));}')

get_f4dedir: installer.pl
	@echo "F4DE directory: " ${F4DE_DIR}


########## Install
# moving the man install after the main install so that developper install is still "complete"

install:
	@make install_noman
	@make install_man

#####

install_man:
	@make commoninstall_man
	@make TV08install_man
	@make AVSS09install_man
	@make DEVAinstall_man

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
COMMONTOOLS=tools/{DETEdit/DETEdit.pl,DETMerge/DETMerge.pl,DETUtil/DETUtil.pl,xmllintTools/xsdxmllint.pl,TableMan/TableMan.pl}
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
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${CM_DIR}/${COMMONTOOLS}

commoninstall_man: 
	@perl installer.pl -l ${F4DE_DIR} man/man1 ${CM_DIR}/man/*.1

commoninstall_noman:
	@make commoninstall_common
	@echo "** NOT installing man files"
	@echo ""
	@echo ""

VidATinstall:
	@echo "** Installing VidAT"
	@make commoninstall_common
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${VIDATDIR}/*.pl

SQLitetoolsinstall:
	@echo "** Installing SQLite_tools"
	@make commoninstall_common
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${SQLITETOOLSDIR}/*.pl

#####

TV08DIR=TrecVid08
TV08TOOLS=tools/{TVED-SubmissionChecker/{TVED-SubmissionChecker.pl,TV{08,09,1{0,1,2,3,4,5}S}ED-SubmissionChecker.sh},TV08MergeHelper/TV08MergeHelper.pl,TV08Scorer/TV08Scorer.pl,TV08ViperValidator/{TV08_BigXML_ValidatorHelper.pl,TV08ViperValidator.pl}}
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
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${TV08DIR}/${TV08TOOLS}

TV08install_man:
	@perl installer.pl -l ${F4DE_DIR} man/man1 ${TV08DIR}/man/*.1
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
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${CL07DIR}/${CL07TOOLS}
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
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${AV09DIR}/${AV09TOOLS}

AVSS09install_man:
	@perl installer.pl -l ${F4DE_DIR} man/man1 ${AV09DIR}/man/*.1

AVSS09install_noman:
	@make AVSS09install_common
	@echo "** NOT installing man file"
	@echo ""
	@echo ""

#####

DEVADIR=DEVA
DEVATOOLS=tools/DEVA_{cli/DEVA_cli,filter/DEVA_filter,sci/DEVA_sci}.pl
MEDTOOLS=tools/MED-SubmissionChecker/{MED-SubmissionChecker.pl,TV1{1,2,3,5}MED-SubmissionChecker.sh}
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
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${DEVADIR}/${DEVATOOLS}
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${DEVADIR}/${MEDTOOLS}

DEVAinstall_man:
	@perl installer.pl -l ${F4DE_DIR} man/man1 ${DEVADIR}/man/*.1
	@make commoninstall_man

DEVAinstall_noman:
	@make DEVAinstall_common
	@echo "** NOT installing man file"
	@echo ""
	@echo ""

##########

KWSEVALDIR=KWSEval
KWSEVALTOOLS=tools/{KWSEval/KWSEval.pl,KWSListGenerator/KWSListGenerator.pl,ValidateKWSList/ValidateKWSList.pl,ValidateTermList/ValidateTermList.pl,ValidateTM/ValidateTM.pl,KWSEval-XMLvalidator/KWSEval-XMLvalidator.pl,KWSEval-SubmissionChecker/{KWSEval-SubmissionChecker.pl,KWS1{2,3}-SubmissionChecker.sh}}
KWSEVALBABEL=BABEL/Participants/BABEL{_Scorer.pl,1{2,3,4,5,6}_Scorer.sh}

KWSEvalinstall:
	@make KWSEvalinstall_common
	@echo ""
	@echo ""

KWSEvalinstall_common:
	@echo ""
	@echo "********** Installing KWSEval tools"
	@make commoninstall_common
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${KWSEVALDIR}/${KWSEVALTOOLS}
	@perl installer.pl -l -x -r ${F4DE_DIR} bin ${KWSEVALDIR}/${KWSEVALBABEL}


##########

install_head:
	@echo "** Checking that the F4DE_DIR is a writable directory"
	@test -d ${F4DE_DIR}
	@test -w ${F4DE_DIR}


########## Checks

mincheck:
	@make check_common
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
	@(perl -Icommon/lib -e 'use MMisc; MMisc::ok_exit() if ($$] < 5.018); MMisc::error_quit("the tools are known not to work with Perl 5.18 (or after), please install Perl 5.16 at most");')

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

check_head:
	@echo "***** Checking ${F4DE_VERSION}"
	@test -f ${F4DE_VERSION}
	@fgrep F4DE ${F4DE_VERSION} > /dev/null

# Include the distribution part of the Makefile (if the file is present)
-include ../F4DE-NISTonly/Makefile_distrib
