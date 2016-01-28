# common

CPANP_IH=../common/tools/cpanp_installhelper/cpanp_installhelper.sh

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check:
	@(cd test; make $@)

perl_install:
	@echo "-- Installing Perl packages needed for common"
	@${CPANP_IH} Getopt::Long
	@${CPANP_IH} Data::Dumper
	@${CPANP_IH} File::Copy
	@${CPANP_IH} File::Temp
	@${CPANP_IH} Cwd
	@${CPANP_IH} Text::CSV_XS
	@${CPANP_IH} Text::CSV
	@${CPANP_IH} Time::HiRes
	@${CPANP_IH} Math::Random::OO::Uniform
	@${CPANP_IH} Math::Random::OO::Normal
	@${CPANP_IH} Statistics::Descriptive
	@${CPANP_IH} Statistics::Descriptive::Discrete
	@${CPANP_IH} Statistics::Distributions
	@${CPANP_IH} DBI
	@${CPANP_IH} DBD::SQLite
	@${CPANP_IH} File::Find
	@${CPANP_IH} File::Monitor
	@${CPANP_IH} File::Monitor::Object
	@${CPANP_IH} YAML
	@${CPANP_IH} Data::Dump
	@${CPANP_IH} Digest::SHA || ${CPANP_IH} Digest::SHA::PurePerl
