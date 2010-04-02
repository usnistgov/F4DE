# common/test/SQLite_tools

SQLite_tools_tester1=SQLite_tools_cfg_helper_tester.pl
SQLite_tools_tester2=SQLite_tools_tables_creator_tester.pl

SQLite_tools_exec1=SQLite_cfg_helper.pl
SQLite_tools_exec2=SQLite_tables_creator.pl
SQLite_tools_reldir=../../tools/SQLite_tools
SQLite_tools1=${SQLite_tools_reldir}/${SQLite_tools_exec1}
SQLite_tools2=${SQLite_tools_reldir}/${SQLite_tools_exec2}

F4DEC_lib=../../../common/lib
PERL=perl -I${F4DEC_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

makecompcheckfiles makecheckfiles check: \
	${SQLite_tools_tester1} ${SQLite_tools1} \
	${SQLite_tools_tester2} ${SQLite_tools2}
	@(${PERL} ${SQLite_tools_tester1} ${SQLite_tools1} $@)
	@(${PERL} ${SQLite_tools_tester2} ${SQLite_tools2} $@)

cleanresfiles:
	@rm -f res*.txt
