# common/test/SQLite_tools

PRE_tests=pre_tests.pl
DBI_check=DBI_check.pl
SQLite_tools_tester1=SQLite_tools_cfg_helper_tester.pl
SQLite_tools_tester2=SQLite_tools_tables_creator_tester.pl

SQLite_tools_exec1_core=SQLite_cfg_helper
SQLite_tools_exec2_core=SQLite_tables_creator

SQLite_tools_reldir=../../tools/SQLite_tools
F4DE_BIN=../../../bin

ifdef F4DE_TEST_INSTALLDIR
SQLite_tools1=${F4DE_BIN}/${SQLite_tools_exec1_core}
SQLite_tools2=${F4DE_BIN}/${SQLite_tools_exec2_core}
else
SQLite_tools1=${SQLite_tools_reldir}/${SQLite_tools_exec1_core}.pl
SQLite_tools2=${SQLite_tools_reldir}/${SQLite_tools_exec2_core}.pl
endif

F4DEC_lib=../../../common/lib
PERL=perl -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

makecompcheckfiles makecheckfiles check: \
	${PRE_tests} ${DBI_check} \
	${SQLite_tools_tester1} ${SQLite_tools1} \
	${SQLite_tools_tester2} ${SQLite_tools2}
	@(${PERL} ${PRE_tests})
	@(${PERL} ${DBI_check})
	@(${PERL} ${SQLite_tools_tester1} ${SQLite_tools1} $@)
	@(${PERL} ${SQLite_tools_tester2} ${SQLite_tools2} $@)

cleanresfiles:
	@rm -f res*.txt
