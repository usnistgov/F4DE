#!/bin/bash

# BABEL Participant Submission Helper
#   (by Martial Michel)
# ID: $Id$
# Revision: $Revision$

## Exit with error status
# call: error_quit errormessage
error_quit () {
  echo "ERROR: $1"
  exit 1
}


########## Usage/Options Processing
usage()
{
cat << EOF
Usage: $0 [-h] [-r] [-A] [-R] [-S SystemDescription.txt] [-X] [-E] <EXPID>.kwslist.xml|<EXPID>.ctm

The script will submit the <EXPID>.kwslist.xml or <EXPID>.ctm to the BABEL Scoring Server

OPTIONS:
   -h      Show this message
   -r      Redownload results
   -A      Authorize TERMs defined in KWList file but not in the KWSlist file
   -R      Resubmit a system file
   -S      System Description file
   -X      Pass the XmllintBypass option to KWSList validation and scoring tools
   -E      Exlude PNG file from result table
EOF
}

RESUBMIT=0
REDODOWNLOAD=0
SYSDESC=""
AUTH_TERM=0
validator_cmdadd=""
XMLLINTBYPASS=0
XPNG=0
while getopts "hrARS:X" OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    r)
      REDODOWNLOAD=1
      shift $((OPTIND-1)); OPTIND=1
      ;;
    A)
      AUTH_TERM=1
      validator_cmdadd="${validator_cmdadd} -A"
      shift $((OPTIND-1)); OPTIND=1
      ;;
    R)
      RESUBMIT=1
      shift $((OPTIND-1)); OPTIND=1
      ;;
    S)
      SYSDESC=${OPTARG}
      shift $((OPTIND-1)); OPTIND=1
      shift $((OPTIND-1)); OPTIND=1
      ;;
    X)
      XMLLINTBYPASS=1
      validator_cmdadd="${validator_cmdadd} -X"
      shift $((OPTIND-1)); OPTIND=1
      ;;
    E)
      XPNG=1
      shift $((OPTIND-1)); OPTIND=1
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done



## Create expected directory if not present, exit with error if not capable
# Also check we can write in the directory if it already exists
# call: make_dir dir name 
make_dir () {
  if [ ! -d "$1" ]; then mkdir -p $1; fi
  if [ ! -d "$1" ]; then error_quit "Problem creating $2 directory ($1)"; fi
  if [ ! -w "$1" ]; then error_quit "Problem with $2 directory ($1), not user writable"; fi
}

## Check that a file exists, is a file and is readable
# call: check_file filename
check_file () {
  if [ ! -e "$1" ]; then error_quit "File ($1) does not exist"; fi
  if [ ! -f "$1" ]; then error_quit "File ($1) is not a file"; fi
  if [ ! -r "$1" ]; then error_quit "File ($1) is not readable"; fi
}

## Check that a file pass check_file and is also executable
# call: check_file_x filename
check_file_x () {
  check_file "$1"
  if [ ! -x "$1" ]; then error_quit "File ($1) is not executable"; fi
}  

## Check that a directory exists, is a directory and is readable
# call: check_dir filename
check_dir () {
  if [ ! -e "$1" ]; then error_quit "Directory ($1) does not exist"; fi
  if [ ! -d "$1" ]; then error_quit "Directory ($1) is not a directory"; fi
  if [ ! -r "$1" ]; then error_quit "Directory ($1) is not readable"; fi
}

########################################
## Command line check

if  [ $# != 1 ]; then usage; error_quit "No submission file on command line, quitting" ; fi
if=$1
check_file "$if"

kmode=`echo $if | perl -ne 's%^.+/%%;s%\_.+$%%; print uc($_)'`
if [ "A$kmode" == "A" ]; then error_quit "No KWS mode information found"; fi

subhelp_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($1)); print $dir' $0`

conf="${subhelp_dir}/${kmode}_SubmissionHelper.cfg"
echo "-- Loading Configuration file: $conf"
check_file "$conf"
source "$conf"

########################################
## Check variables 
if [ -z "${lockdir+xxx}" ]; then error_quit "lockdir is not set"; fi
if [ -z "$lockdir" ] && [ "${lockdir+xxx}" = "xxx" ]; then error_quit "lockdir has no value set"; fi
#
if [ -z "${dloaddir+xxx}" ]; then error_quit "dloaddir is not set"; fi
if [ -z "$dloaddir" ] && [ "${dloaddir+xxx}" = "xxx" ]; then error_quit "dloaddir has no value set"; fi
#
if [ -z "${statusdir+xxx}" ]; then error_quit "statusdir is not set"; fi
if [ -z "$statusdir" ] && [ "${statusdir+xxx}" = "xxx" ]; then error_quit "statusdir has no value set"; fi
#
if [ -z "${scp_cmd+xxx}" ]; then error_quit "scp_cmd is not set"; fi
if [ -z "$scp_cmd" ] && [ "${scp_cmd+xxx}" = "xxx" ]; then error_quit "scp_cmd has no value set"; fi
#
if [ -z "${scp_user+xxx}" ]; then error_quit "scp_user is not set"; fi
if [ -z "$scp_user" ] && [ "${scp_user+xxx}" = "xxx" ]; then error_quit "scp_user has no value set"; fi
#
if [ -z "${scp_host+xxx}" ]; then error_quit "scp_host is not set"; fi
if [ -z "$scp_host" ] && [ "${scp_host+xxx}" = "xxx" ]; then error_quit "scp_host has no value set"; fi
#
if [ -z "${scp_uploads+xxx}" ]; then error_quit "scp_uploads is not set"; fi
if [ -z "$scp_uploads" ] && [ "${scp_uploads+xxx}" = "xxx" ]; then error_quit "scp_uploads has no value set"; fi
#
if [ -z "${scp_downloads+xxx}" ]; then error_quit "scp_downloads is not set"; fi
if [ -z "$scp_downloads" ] && [ "${scp_downloads+xxx}" = "xxx" ]; then error_quit "scp_downloads has no value set"; fi
#
if [ -z "${scp_status+xxx}" ]; then error_quit "scp_status is not set"; fi
if [ -z "$scp_status" ] && [ "${scp_status+xxx}" = "xxx" ]; then error_quit "scp_status has no value set"; fi
#
if [ -z "${scp_lockext+xxx}" ]; then error_quit "scp_lockext is not set"; fi
if [ -z "$scp_lockext" ] && [ "${scp_lockext+xxx}" = "xxx" ]; then error_quit "scp_lockext has no value set"; fi
#
if [ -z "${jobrunner+xxx}" ]; then error_quit "jobrunner is not set"; fi
if [ -z "$jobrunner" ] && [ "${jobrunner+xxx}" = "xxx" ]; then error_quit "jobrunner has no value set"; fi
#
if [ -z "${JRlockdir+xxx}" ]; then error_quit "JRlockdir is not set"; fi
if [ -z "$JRlockdir" ] && [ "${JRlockdir+xxx}" = "xxx" ]; then error_quit "JRlockdir has no value set"; fi
#
if [ -z "${F4DEclib+xxx}" ]; then error_quit "F4DEclib is not set"; fi
if [ -z "$F4DEclib" ] && [ "${F4DEclib+xxx}" = "xxx" ]; then error_quit "F4DEclib has no value set"; fi
#
if [ -z "${validator+xxx}" ]; then error_quit "validator is not set"; fi
if [ -z "$validator" ] && [ "${validator+xxx}" = "xxx" ]; then error_quit "validator has no value set"; fi
#
if [ -z "${TMvalidator+xxx}" ]; then error_quit "TMvalidator is not set"; fi
if [ -z "$TMvalidator" ] && [ "${TMvalidator+xxx}" = "xxx" ]; then error_quit "TMvalidator has no value set"; fi
#
if [ -z "${subcheck+xxx}" ]; then error_quit "subcheck is not set"; fi
if [ -z "$subcheck" ] && [ "${subcheck+xxx}" = "xxx" ]; then error_quit "subcheck has no value set"; fi
#
if [ -z "${dbDir+xxx}" ]; then error_quit "dbDir is not set"; fi
if [ -z "$dbDir" ] && [ "${dbDir+xxx}" = "xxx" ]; then error_quit "dbDir has no value set"; fi
#
if [ -z "${uncompdir+xxx}" ]; then error_quit "uncompdir is not set"; fi
uncomp=1
if [ -z "$uncompdir" ] && [ "${uncompdir+xxx}" = "xxx" ];then uncomp=0; fi


########################################

# Check tools
for tool in "$subcheck" "$validator" "$TMvalidator" "$jobrunner"
do
  check_file_x "$tool"
done

# Check Dir
dbDir_check=$(echo $dbDir | tr ":" "\n")
for dir in "$F4DEclib" $dbDir_check
do
  check_dir "$dir"
done

########################################

# Precreate directories if needed
make_dir "$lockdir" "Lock directory"
make_dir "$dloaddir" "Download directory"
make_dir "$statusdir" "Status directory"
make_dir "$JRlockdir" "JobRunner lock directory"
if [ "A$uncomp" == "A1" ]; then
  make_dir "$uncompdir" "Uncompress directory"
fi

############################################################
echo "** Submission file: [$if]"

# we want to get the file's SHA256
sha256=`perl -I$F4DEclib -e 'use MMisc; $if=$ARGV[0]; my ($e, $s) = MMisc::file_sha256digest($if); MMisc::error_quit($e) if (! MMisc::is_blank($e)); print $s;' $if`
if [ "${?}" -ne "0" ]; then error_quit "Problem obtaining file's SHA256 ($if): $sha256"; fi
echo "   SHA256 : $sha256"
lf_base="$lockdir/$sha256"

# FYI:
# Step 1: Submission Validation
# Step 2: Submission Upload
# Step 3: Awaiting on Scoring Server
# Step 4: Download Results
# Step 5: Uncompress Results
# if a step is redone, its remove the next lock file to force a redo of the next step ...

# if resubmit was requested, erase validation lock
if [ "A$RESUBMIT" == "A1" ]; then rm -f $lf_base.01-*; fi
# do not redownload unless the scoring server tells us the file is ready for download
if [ "A$REDODOWNLOAD" == "A1" ]; then rm -f $lf_base.03-*; fi

########## Step 1
echo "++ Validation step"
lf="$lf_base.01-validated"
nlf="$lf_base.02-uploaded"
if [ ! -f "$lf" ]; then
  echo "  -> validating submission file"
  tld="${sha256}-Validation"
  $jobrunner -b -l "$JRlockdir" -n "$tld" -S 99 -- "$subcheck" -d "$dbDir" -k "$validator" $validator_cmdadd -T "$TMvalidator" "$if" &> "$lf.log"
  if [ "${?}" -ne "99" ]; then error_quit "**** Submission did not validate, aborting (check within a directory starting with \'$JRlockdir/$tld\' for details, as well as: $lf.log)"; fi
  # if 'redoBad' was triggered, consider the submission new: remove any lock files (and logs)
  rm -f $lf_base.*
  touch "$lf"
  rm -f "$nlf"
else
  echo "  -- validated earlier, skipping revalidation"
fi

expid=`echo $if | perl -pe 's%\.(kwslist\d*\.xml|ctm)$%%i; s%^.*/%%;'`
sfile="${sha256}.status"

########## Step 2
echo "++ Archive Generation and Upload"
lf="$nlf"
nlf="$lf_base.03-scored"
if [ ! -f "$lf" ]; then
  bnm=`basename $if`
  tid=`perl -I$F4DEclib -e 'use MMisc; print MMisc::get_tmpdir();'`
  tif="$tid/$bnm"
  cat "$if" > "$tif"
  epoch=`perl -I$F4DEclib -e 'use MMisc; print MMisc::get_scalar_currenttime();'`
  commentChar=""
  if [ "`echo $if|sed 's/.*\.//'`" = "ctm" ] ; then
      commentChar=";;"
  fi
  echo "$commentChar" >> "$tif"
  echo "$commentChar"'<!''--'" File: $bnm -->" >> "$tif"
  echo "$commentChar"'<!''--'" Epoch: $epoch -->" >> "$tif"

  lsha256=`perl -I$F4DEclib -e 'use MMisc; $if=$ARGV[0]; my ($e, $s) = MMisc::file_sha256digest($if); MMisc::error_quit($e) if (! MMisc::is_blank($e)); print $s;' $tif`
  if [ "${?}" -ne "0" ]; then error_quit "Problem obtaining file's SHA256 ($tif): $lsha256"; fi

  if [ "A${SYSDESC}" != "A" ]; then
    mkdir "${tid}/SystemDescription"
    cp "${SYSDESC}" "${tid}/SystemDescription/"
  fi

  if [ "A${AUTH_TERM}" == "A1" ]; then
    if [ ! -d "${tid}/ExtraOptions" ]; then mkdir "${tid}/ExtraOptions"; fi
    echo "1" > "${tid}/ExtraOptions/AUTH_TERM"
  fi

  if [ "A${XMLLINTBYPASS}" == "A1" ]; then
    if [ ! -d "${tid}/ExtraOptions" ]; then mkdir "${tid}/ExtraOptions"; fi
    echo "1" > "${tid}/ExtraOptions/XMLLINTBYPASS"
  fi

  if [ "A${XPNG}" == "A1" ]; then
    if [ ! -d "${tid}/ExtraOptions" ]; then mkdir "${tid}/ExtraOptions"; fi
    echo "1" > "${tid}/ExtraOptions/XPNG"
  fi

  pwd=`pwd`
  cd $tid
  atif="$tid/${lsha256}.tar.bz2"
  tar cfj "$atif" *
  cd "$pwd"

  llsha256=`perl -I$F4DEclib -e 'use MMisc; $if=$ARGV[0]; my ($e, $s) = MMisc::file_sha256digest($if); MMisc::error_quit($e) if (! MMisc::is_blank($e)); print $s;' $atif`
  if [ "${?}" -ne "0" ]; then error_quit "Problem obtaining file's SHA256 ($atif): $llsha256"; fi

  echo "  -> transfer file"
  ${scp_cmd} "$atif" "${scp_user}@${scp_host}:${scp_uploads}/." &> "$lf.log"
  if [ "${?}" -ne "0" ]; then error_quit "Problem uploading file ($atif), see: $lf.log"; fi

  latif="${atif}.${scp_lockext}"
  echo "$llsha256" > $latif

  ${scp_cmd} "$latif" "${scp_user}@${scp_host}:${scp_uploads}/." &> "$lf.log2"
  if [ "${?}" -ne "0" ]; then error_quit "Problem uploading file ($latif), see: $lf.log2"; fi

  echo "$lsha256" > "$lf"
  rm -f "$nlf"
else
  echo "  -- transfered earlier, skipping reupload"
fi

# obtain last uploaded file's SHA256 for download
lsha256=`cat $lf` 
if [ -z "$lsha256" ]; then error_quit "No previous SHA value available, aborting"; fi
echo "Remote SHA256 : $lsha256"
sfile="${lsha256}.status"

########## Step 3
echo "++ Awaiting scoring server completion"
status_file="${scp_user}@${scp_host}:${scp_status}/$sfile"
lf="$nlf"
nlf="$lf_base.04-returned"
if [ -f "$lf" ]; then
  echo "  -- scored earlier, skipping step"
else 
  sv="30"
  expected="Report Uploaded"
  read=""
  lastread=""
  efile="$statusdir/$sfile"
  while [ "A$read" != "A$expected" ]
  do
    $scp_cmd "$status_file" "$efile" &> $lf.log
    if [ -e $efile ]; then
      read=`head -1 $efile`
      mv "$efile" "$efile.last"
    else
      read="Awaiting Status update from scoring server"
    fi
    if  [ "A$read" != "A$lastread" ]; then echo "Remote Server: $read"; fi
    lastread="$read"
    if [[ $read == ERROR* ]]; then error_quit "$read"; fi
    if [ "A$read" != "A$expected" ]; then sleep $sv; fi
  done
  touch "$lf"
  rm -f "$nlf"
fi

########## Step 4
echo "++ Downloading Results"
lf="$nlf"
nlf="$lf_base.05-uncompressed"
file=`find $dloaddir | grep $lsha256.tar.bz2 | perl -l -ne '$_{$_} = -M; END { $,="\n"; print sort {$_{$b} <=> $_{$a}} keys %_; }' | tail -1` # get the list, sort it by modification time and get the latest file (bottom of the list in this case)
# solution could work but AAA file creation date is path use this instead:
if [ "A$REDODOWNLOAD" == "A1" ]; then
  if [ ! -z "$file" ]; then
    echo "  == result file present, but re-download requested, will try to redownload before using it"
    echo "  == Result File: $file"
    old_file="$file"
  fi
  file=""
fi
sv="60"
if [ -f "$lf" ]; then
  echo "  -- received earlier, skipping redownload"
elif [ ! -z "$file" ]; then
  echo "  == result file present, skipping redownload"
  touch "$lf"
else
  echo "  <- Trying to download result file"
  $scp_cmd "$scp_user@$scp_host:$scp_downloads/$lsha256.tar.bz2" "$dloaddir/." >& "$lf.log"
  if [ "${?}" -ne "0" ]; then error_quit "Problem downloading result file (see: $lf.log)"; fi
  file=`find $dloaddir | grep $lsha256.tar.bz2 | perl -l -ne '$_{$_} = -M; END { $,="\n"; print sort {$_{$b} <=> $_{$a}} keys %_; }' | tail -1`
  if [ -z "$file" ]; then error_quit "Problem downloading result file"; fi
  touch "$lf"
  rm -f "$nlf"
fi


#################### Step 5 (not for manual mode)
echo "** Result file: $file"
if [ "A$REDODOWNLOAD" == "A1" ]; then
  if [ "A$old_file" == "A$file" ]; then
    echo "  == No newer file obtained, using old file for unarchiving"
  fi
fi
lf="$nlf"
if [ "A$uncomp" == "A1" ]; then
  if [ -f "$lf" ]; then
    echo "  -- uncompressed earlier, skipping"
  else
    pwd=`pwd`
    cd "$uncompdir"
    # Erase old result of the same name
    rm -rf "$expid"
    # create it (again)
    make_dir "$expid"
    cd "$expid"
    tar xfj "$file"
    cd "$pwd"
    touch "$lf"
  fi
  echo "** Uncompressed in: $uncompdir/$expid"
fi

# Done
