submission_dir=$1
completeness_file=$2
xsd_name="MER13_output.xsd"

if [ -z $submission_dir ]; then
    echo "$0 MER_submission_dir [completeness_file]"
    exit 1
fi

echo "Running MER submission checks"

tool_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($ARGV[0])); print $dir' $0`
data_path="${tool_dir}/../../data"
xsd=$data_path/$xsd_name
if [ ! -f $xsd ]; then
  echo "**Could not find the needed xsd files ($xsd)"
  exit 1
fi

if [ $completeness_file ]; then
  if [ ! -f $completeness_file ]; then
      echo "**Could not find requested completeness_file ($completeness_file)"
      exit 1
  fi
  if [ ! -r $completeness_file ]; then
      echo "**Could not read requested completeness_file ($completeness_file)"
      exit 1
  fi
    echo "*Checking submission directory for completeness*"
    complete_list=`perl -I${tool_dir}/../../../common/lib -e 'use MMisc; print MMisc::get_tmpfile("mer_check")';`
    echo $submission_dir > $complete_list
    cat $completeness_file | perl -ne 's/["\n]//g; next if ($_ eq "TrialID");($c, $e) = split(/\./); print "'$submission_dir'/$e\n'$submission_dir'/$e/$_.mer.xml\n"' | sort -u >> $complete_list

    diff_results=`perl -I${tool_dir}/../../../common/lib -e 'use MMisc; print MMisc::get_tmpfile("mer_diff")';`
    find $submission_dir \( ! -iname '*._*' \) | diff - $complete_list > $diff_results
    if [ -s $diff_results ]; then
	echo "*Completeness check failed, aborting!"
	echo "**Missing files/dirs**"
	sed -n '/^>/ s/^> /  /p' $diff_results
	echo "**Extraneous files/dirs**"
	sed -n '/^</ s/^< /  /p' $diff_results
	exit 1
    fi
    echo "  Completion check passed!"
else
    echo "*Skipping completeness check*"
fi

if [ ! -d $submission_dir ]; then
    echo "**Could not find MER_submission_dir ($MER_submission_dir)"
    exit 1
fi
if [ ! -r $submission_dir ]; then
    echo "**Could not read from MER_submission_dir ($MER_submission_dir)"
    exit 1
fi

scan_for_errors() {
    perl -ne '$ok =0; unless (m%validates$%) { print "[Problem with XML validation of entry]\n$_"; exit(1); } if (s%^.+?clip_ID=\"HVC(\d+)\"\s+event_ID=\"(\w+)\".+\"(.+/(\d+)\.(\w+)\.mer\.xml)\svalidates$%$3%) { if ($1 ne $4) { print "Problem with clip_ID in entry (exp: $4 / got: $1) in file: $_"; exit(1); } if ($2 ne $5) { print "Problem with event_ID in entry (exp: $5 / got: $2) in file: $_"; exit(1); } }'
}

echo "*Validating mer.xml files*"
find $submission_dir -type f \( ! -iname '*._*' \) | xargs -n100 xmllint --schema $xsd --xpath '/mer/@*' 2>&1 | scan_for_errors
if [ $? != 0 ]; then
    echo "  An error occurred during validation"; exit 1
fi

echo "  All files validated successfully!"
exit 0
