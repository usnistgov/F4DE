submission_dir=$1
completeness_file=$2
xsd_name="MER13_output.xsd"

if [ -z $submission_dir ]; then
    echo "$0 MER_submission_dir [completeness_file]"
#    echo "Missing first argument, should be submission directory!"
    exit 1
fi

echo "Running MER submission checks"

tool_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($ARGV[0])); print $dir' $0`
data_path="${tool_dir}/../../data"
xsd=$data_path/$xsd_name
if [ -f $xsd ]; then
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
    echo "*Checking submission for completeness*"
    complete_list=`mktemp -t mer_check`
    echo $submission_dir > $complete_list
    cat $completeness_file | perl -ne 's/["\n]//g; next if ($_ eq "TrialID");($c, $e) = split(/\./); print "'$submission_dir'/$e\n'$submission_dir'/$e/$_.mer.xml\n"' | sort -u >> $complete_list

    diff_results=`mktemp -t mer_diff`
    find $submission_dir | diff - $complete_list > $diff_results
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


echo "*Validating mer.xml files*"
for mer in `find $submission_dir -type f -name '*mer.xml'`; do
    xmllint --noout --schema $xsd $mer
    if [ $? -ne 0 ]; then
	echo "**Validation failed, aborting!"
	exit 1
    fi
done
echo "  All files validated successfully!"
exit 0
