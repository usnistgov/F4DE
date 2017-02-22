# Framework for Detection Evaluation (F4DE)

**Version:** 3.3.1

**Date:** February 22, 2017

## Table of Content

[Overview](#overview)
  
[Setup](#setup)

[Usage](#usage)

[Supported Evaluations](#supported_eval)

[Report a bug](#contacts)

[Authors](#authors)

[Copyright](#copyright)

## <a name="overview"></a>Overview

This directory contains the **Framework for Detection Evaluation** (F4DE) software package.  It contains a set of evaluation tools for detection evaluations and for specific [NIST-coordinated evaluations](#supported_eval).

## <a name="setup"></a>Setup

F4DE consists of a set of Perl scripts that can be run under a shell terminal. 

F4DE's source files are publicly available on [GitHub](https://github.com), see: [https://github.com/usnistgov/F4DE](https://github.com/usnistgov/F4DE)

It has been confirmed to work under Linux, OS X and Cygwin.

After confirming the [prerequisites](#prerequisites) are met, F4DE does not have to be installed as the tools can be run directly from their  base location. An installation method is made available if you intend to add some of more common tools to your path. See the [installation](installation) subsection for more details.

A [docker](https://www.docker.com/) release for F4DE is available, please see:   [https://hub.docker.com/r/martialnist/docker-f4de/](https://hub.docker.com/r/martialnist/docker-f4de/)

Unless using the [docker](https://www.docker.com/) release of F4DE, some prerequisites need to be fulfilled. 

### <a name="prerequisites"></a> Prerequisites

- a version of [Perl](https://www.perl.org/), above 5.14. 

  * If you do not have Modules installation privileges on your host for the version of Perl you are running, it is recommended to install an HOME directory perl installation using [Perlbrew](http://perlbrew.pl/).


  * If using Perl 5.18 (or above), the tools will use it by forcing `PERL_PERTURB_KEYS=0` and `PERL_HASH_SEED=0` in order to have repeatable results, as Perl 5.18 and above use a new Hash algorithm that will not always produce results comparable with runs done using Perl 5.16 and below.

   * For Perl before 5.20, an installed and configured version of [cpanp](http://perldoc.perl.org/cpanp.html). For Perl 5.20 and above, an installed and configured version of [cpanm](https://github.com/miyagawa/cpanminus).
  
- a recent version of [gnuplot](http://www.gnuplot.info/) (at least 4.4 with `ligdb`'s `png` support) to create plots for DETCurves among others. Of note, F4DE does not currently support `libcairo`'s `pngcairo` `terminal` type.

- a recent version of `xmllint` (at least 2.6.30) (part of [libxml2](http://xmlsoft.org/)) to validate XML files against their corresponding schema files.

- a recent version of [SQLite](https://sqlite.org/) (at least 3.6.12) to use all the SQLite based tools (including DEVA)

- the [rsync](https://rsync.samba.org/) tool available in your PATH (used in the installation process)

- Some Perl Modules installed:
    [Text::CSV](http://search.cpan.org/perldoc?Text%3A%3ACSV), 
    [Text::CSV_XS](http://search.cpan.org/perldoc?Text%3A%3ACSV_XS), 
    [Math::Random::OO::Uniform](http://search.cpan.org/perldoc?Math%3A%3ARandom%3A%3AOO%3A%3AUniform),
    [Math::Random::OO::Normal](http://search.cpan.org/perldoc?Math%3A%3ARandom%3A%3AOO%3A%3ANormal),
    [Statistics::Descriptive](http://search.cpan.org/perldoc?Statistics%3A%3ADescriptive),
    [Statistics::Descriptive::Discrete](http://search.cpan.org/perldoc?Statistics%3A%3ADescriptive%3A%3ADiscrete),
	[Statistics::Distributions](http://search.cpan.org/perldoc?Statistics%3A%3ADistributions),
    [DBI](http://search.cpan.org/perldoc?Statistics%3A%3ADBI),
    [DBD::SQLite](http://search.cpan.org/perldoc?Statistics%3A%3ADBI%3A%3ASQLite),
    [File::Monitor](http://search.cpan.org/perldoc?File%3A%3AMonitor),
    [File::Monitor::Object](http://search.cpan.org/perldoc?File%3A%3AMonitor%3A%3AObject),
    [Digest::SHA](http://search.cpan.org/perldoc?Digest%3A%3ASHA),
    [YAML](http://search.cpan.org/perldoc?YAML),
    [Data::Dump](http://search.cpan.org/perldoc?Data%3A%3ADump).

   * Automatic installation (using the `cpanp`/`cpanm` tools) can be executed from the main directory by using the 'make perl_install' command line. Note that you need to be able to install Modules within your Perl installation, which might require administrative privileges.

  * Availability of those will can be tested using `make check` from F4DE main directory.

### <a name="installation"></a>Installation

All of the F4DE tools are made so that they can be run from the directory they are uncompressed from, and therefore installation is optional, but useful if you want to launch some tools from anywhere.
Also, a reminder that a docker release for F4DE is available at: https://hub.docker.com/r/martialnist/docker-f4de/

If installing on a [cygwin](https://www.cygwin.com/) system, please read the [cygwin pre-installation notes](#cygwinpreinst) first.
 
Installation is a 4 step process:

  1. Make sure all the steps in [Prerequisites](#prerequisites) are done.

  2. Run `make` to get a list of the *check* options available.
   * At minimum, run `make mincheck` followed by the appropriate check for your tool set you intend to use (i.e. if you intend to use `DEVA`, run `make DEVAcheck`) to make sure all required libraries and executables are available on the system. Note that each tool's individual test can take from a few seconds to a few minutes to complete.
  	* We recommend running `make check` to run a full check to confirm that all software checks pass.
  	* If one of the Tools tests fails, please follow the bug reports submission instructions detailed in the *[test case bug report](#bugreport)* section.

  2. Execute the `make install` command to make symbolic links from the executables into the F4DE uncompression directory's `bin` and `man` directories
  
  3. Add F4DE uncompression directory's `bin` directory to your `PATH` environment variable and its `man` directory to your `MANPATH` environment variable.


### <a name="cygwinpreinst"></a>Cygwin pre-installation notes

The tools have been confirmed to work under windows when running cygwin. 
After downloading the latest `setup.exe` from [http://www.cygwin.com/](http://www.cygwin.com/), make sure to add the following when in the `Select Packages`: 
in `Archive` select `unzip`, 
in `Database` select `sqlite3`,
in `Devel` select `gcc`, `gcc4` and `make`,
in `Libs` select `libxml2`,
in `Math` select `gnuplot`, 
in `Net` select `rsync`, 
in `Perl` select `perl`, `perl-ExtUtils-Depends` and `perl-ExtUtils-PkgConfig`.

After installation, from shell, run `cpan` from which you will want to `install` first the `ExtUtils::CBuilder` modules and then the modules listed in the [prerequisites](#prerequisites) section of the [setup](#setup) instructions.

After this, refer to the rest of the [installation](#installation) section.

## <a name="usage"></a>Usage

A manual page can be printed by each command by executing the command with the `--man` command line argument.  For example:

	%  TV08Scorer --man

Some manual pages contain command line examples for the tool in question, but each NIST evaluation specific set of tools should be more detailed in its evaluation plan.

### Command line examples

Some command line examples are provided as part of the `test` directory relative to the evaluation tool you are trying to test (for example `CLEAR/test/`*\<TOOLNAME\>* or `TrecVid08/test/`*\<TOOLNAME\>*) and use the `[[COMMANDLINE]]` line listed in the first entry of the `res*.txt` test case files.
For example, in `TrecVid08/test/TV08ViperValidator/res_test0.txt`, the first line contains:


	[[COMMANDLINE]] ../../tools/TV08ViperValidator/TV08ViperValidator.pl -X

the command line to try is:


	../../tools/TV08ViperValidator/TV08ViperValidator.pl -X

which will run the `TV08ViperValidator.pl` tool with its `-XMLbase` command line option, which will result in: *Print a ViPER file with an empty <data> section and a populated <config> section, and exit (to a file if one provided on the command line)*.
The expected result of the command line can be found in the test file below the `[[STDOUT]]` section.


## <a name="supported_eval"></a>Supported Evaluations

Advanced Video and Signal Based Surveillance (AVSS): [2009](#avss2009) [2010](#avss2010)
 
Classification of Events, Activities, and Relationships (CLEAR): [2007](#clear2007)

KeyWord Search (KWS / OpenKWS): [KWS](#kws) [2015](#openkws2015)

TRECVID Multimedia Event Detection(MED): [2010](#med2010) [2011](#med2011) [2012](#med2012) [2013](#med2013) [2015](#med2015) [2016](#med2016)

TRECVID Multimedia Event Recounting (MER): [2013](#mer2013)

TRECVID Surveillance Event Detection (SED): [2008](#sed2008) [2009](#sed2009) [2010](#sed2010) [2011](#sed2011) [2012](#sed2012) [2013](#sed2013) [2014](#sed2014) [2015](#sed2015) [2016](#sed2016)


### <a name="clear2007"></a>2007 CLEAR Evaluation:
- Domains: Broadcast News, Meeting Room, Surveillance and UAV
- Measures: Area and Point
- Detection and Tracking (DT) tools:
  - `CLEARDTScorer` - The main DT evaluation script.
  - `CLEARDTViperValidator` - A syntactic and semantic validator for both system output ViPER files and reference annotation files.
- Text Recognition (TR) tools:
  - `CLEARTRScorer` - The main TR evaluation script.
  - `CLEARTRViperValidator` - A syntactic and semantic validator for 
        both system output ViPER files and reference annotation files.
	
### <a name="sed2008"></a>2008 TRECVID SED Evaluation:
- `TV08Scorer` - The main evaluation script. 
- `TV08ViperValidator` - A syntactic and semantic validator for both system output ViPER files and reference annotation files.
- `TV08MergeHelper` - A TRECVID '08 ViPER-formatted file merging program.  
- `TV08_BigXML_ValidatorHelper` - A helper program (that relies on `TV08ViperValidator` and `TV08MergeHelper`) to perform syntactic and semantic validation on ViPER-formatted files containing a large number of event observations.
- `TV08ED-SubmissionChecker` - A tool designed to help confirm submission archives before transmitting them to NIST. 

### <a name="avss2009"></a>2009 AVSS Evaluation:
- `AVSS09Scorer` - The main evaluation script. 
- `AVSS09ViperValidator` - A syntactic and semantic validator for both system output ViPER files and reference annotation files.
- `AVSS09-SubmissionChecker` - A tool designed to help confirm submission archives before transmitting them to NIST. 

### <a name="sed2009"></a>2009 TRECVID SED Evaluation:
- Same tools as the [2008 TRECVID SED](#sed2008) Evaluation (`TV08Scorer`, `TV08ViperValidator`, `TV08MergeHelper`, `TV08_BigXML_ValidatorHelper`)
- `TV09ED-SubmissionChecker` - A tool designed to help confirm submission archives before transmitting them to NIST. 

### <a name="avss2010"></a>2010 AVSS Evaluation:
- Same tools as the [2009 AVSS](#avss2009) Evaluation (`AVSS09Scorer`, `AVSS09ViperValidator`, `AVSS09-SubmissionChecker`)

### <a name="med2010"></a>2010 TRECVID MED Evaluation 
- `DEVA_cli` - The main evaluation script. 

### <a name="sed2010"></a>2010 TRECVID SED Evaluation:
- Same tools as the [2009 TRECVID SED](#sed2009) Evaluation (`TV08Scorer`, `TV08ViperValidator`, `TV08MergeHelper`, `TV08_BigXML_ValidatorHelper`, `TV09ED-SubmissionChecker`)
- `TV10SED-SubmissionChecker` - A tool designed to help confirm submission archives before transmitting them to NIST.

### <a name="med2011"></a>2011 TRECVID MED Evaluation:
- Same tool as the [2010 MED](#med2010) Evaluation (`DEVA_cli`).
- `TV11MED-SubmissionChecker` - A tool designed to help confirm MED11 submission archives before transmitting them to NIST.
- Scoring Primer: `DEVA/doc/TRECVid-MED11-ScoringPrimer.html`

### <a name="sed2011"></a>2011 TRECVID SED Evaluation:
- Same tools as the [2010 TRECVID SED](#sed2010) Evaluation (`TV08Scorer`, `TV08ViperValidator`, `TV08MergeHelper`, `TV08_BigXML_ValidatorHelper`)
- `TV11SED-SubmissionChecker` - A tool designed to help confirm SED11 submission archives before transmitting them to NIST. 

### <a name="kws"></a>KWS Evaluation:
- `KWSEval` - The main KeyWord Search evaluation program derived from STDEval.
- UTF-8 code set support.

### <a name="med2012"></a>2012 TRECVID MED Evaluation:
- Same tool as the [2011 MED](#med2011) Evaluation (`DEVA_cli`).
- `TV12MED-SubmissionChecker` - A tool designed to help confirm MED12 submission archives before transmitting them to NIST.
- Scoring Primer: `DEVA/doc/TRECVid-MED12-ScoringPrimer.html`

### <a name="sed2012"></a>2012 TRECVID SED Evaluation:
- Same tools as the [2011 TRECVID SED](#sed2011) Evaluation (`TV08Scorer`, `TV08ViperValidator`, `TV08MergeHelper`, `TV08_BigXML_ValidatorHelper`)
- `TV12SED-SubmissionChecker` - A tool designed to help confirm SED12 submission archives before transmitting them to NIST. 

### <a name="med2013"></a>2013 TRECVID MED Evaluation:
- Same tool as the [2012 MED](#med2012) Evaluation (`DEVA_cli`).
- `TV13MED-SubmissionChecker` - A tool designed to help confirm MED13 submission archives before transmitting them to NIST.
- Scoring Primer: `DEVA/doc/TRECVid-MED13-ScoringPrimer.html`

### <a name="mer2013"></a>2013 TRECVID MER Evaluation:
- `TV13MED-SubmissionChecker` - A tool designed to help confirm MED13 and MER13 submission archives before transmitting them to NIST.

### <a name="sed2013"></a>2013 TRECVID SED Evaluation:
- Same tools as the [2012 TRECVID SED](#sed2012) Evaluation (`TV08Scorer`, `TV08ViperValidator`, `TV08MergeHelper`, `TV08_BigXML_ValidatorHelper`)
- `TV13SED-SubmissionChecker` - A tool designed to help confirm SED13 submission archives before transmitting them to NIST. 

### <a name="sed2014"></a>2014 TRECVID SED Evaluation:
- Same tools as the [2013 TRECVID SED](#sed2013) Evaluation (`TV08Scorer`, `TV08ViperValidator`, `TV08MergeHelper`, `TV08_BigXML_ValidatorHelper`)
- `TV14SED-SubmissionChecker` - A tool designed to help confirm SED14 submission archives before transmitting them to NIST. 

### <a name="openkws2015"></a>2015 OpenKWS Evaluation:
- Participant's side of the *BABEL Scorer*

### <a name="sed2015"></a>2015 TRECVID SED Evaluation: 
- Same tools as the [2014 TRECVID SED](#sed2014) Evaluation (`TV08Scorer`, `TV08ViperValidator`, `TV08MergeHelper`, `TV08_BigXML_ValidatorHelper`)
- `TV15SED-SubmissionChecker` - A tool designed to help confirm SED15 submission archives before transmitting them to NIST. 

### <a name="med2015"></a>2015 TRECVID MED Evaluation: 
- Same tool as the [2013 MED](#med2013) Evaluation (`DEVA_cli`).
- `TV15MED-SubmissionChecker` - A tool designed to help confirm MED15 submission archives before transmitting them to NIST.
- Scoring Primer: `DEVA/doc/TRECVid-MED15-ScoringPrimer.html`

### <a name="sed2016"></a>2016 TRECVID SED Evaluation: 
- Same tools as the [2014 TRECVID SED](#sed2014) Evaluation (`TV08Scorer`, `TV08ViperValidator`, `TV08MergeHelper`, `TV08_BigXML_ValidatorHelper`)
- `TV16SED-SubmissionChecker` - A tool designed to help confirm SED16 submission archives before transmitting them to NIST. 

### <a name="med2016"></a>2016 TRECVID MED Evaluation: 
- Same tool as the [2013 MED](#med2013) Evaluation (`DEVA_cli`).
- `TV16MED-SubmissionChecker` - A tool designed to help confirm MED16 submission archives before transmitting them to NIST.
- Scoring Primer: `DEVA/doc/TRECVid-MED16-ScoringPrimer.html`

### Misc tools:
* VidAT (`common/tools/VidAT`): a suite of tools designed to overlay video with boxes, polygons, etc. on a frame-by-frame basis by using the output logs generated by `CLEARDTScorer`. Consult the `README` within the directory for special installation details and usage. VidAT's tools require [FFmpeg](https://www.ffmpeg.org/), [Ghostscript](http://www.ghostscript.com/) and [ImageMagick](https://www.imagemagick.org/script/index.php).
* SQLite_tools (`common/tools/SQLite_tools`): a suite of tools designed to help interface `CSV` files and [SQLite](https://sqlite.org/) databases.


## <a name="contacts"></a> Report a bug

Please send bug reports to [nist_f4de@nist.gov](mailto:nist_f4de@nist.gov)

For the bug report to be useful, please include the command line, files and text output, including the error message in your email.


### <a name="bugreport"></a>Test case bug report

If the error occurred while doing a `make check`, go in the directory associated with the tool that failed (for example: `CLEAR/test/`*\<TOOLNAME\>*), and type `make makecompcheckfiles`. This process will create a file corresponding to each test number named `res_test*.txt-comp`. These file are (like their `.txt` equivalent) text files that can be compared to the original `res_test*.txt` files.

For information, for each of those tests, the command line that was run by the test can be found in the corresponding `res*.txt` file as the first line in the `[[COMMANDLINE]]` section.

When a test fails, please send us the `res_test*.txt-comp` file of the failed test(s) for us to try to understand what happened, as well as information about your system (OS, architecture, ...) that you think might help us.  

Thank you for helping us improve F4DE.


## <a name="authors"></a> Authors

Martial Michel &lt;martial.michel@nist.gov&gt;

David Joy &lt;david.joy@nist.gov&gt;

Jonathan Fiscus &lt;jonathan.fiscus@nist.gov&gt;

Vladimir Dreyvitser

Vasant Manohar

Jerome Ajot

Bradford N. Barr


## <a name="copyright"></a> Copyright 

Full details can be found at: [http://nist.gov/data/license.cfm](http://nist.gov/data/license.cfm)

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. F4DE is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees, expressed or implied, about its quality, reliability, or any other characteristic.

We would appreciate acknowledgement if the software is used.  This software can be redistributed and/or modified freely provided that any derivative works bear some notice that they are derived from it, and any modified versions bear some notice that they have been modified.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
