#!/bin/bash

# this script compiles all papyrus files from the package folder
# into a matching folder structure in the build folder

# make sure we clean up on exit
ORIGINAL_DIR=$(pwd)
function clean_up {
  cd "$ORIGINAL_DIR"
}
trap clean_up EXIT
set -e

# check arguments
QUIET=0
for VAR in "$@"
do
  case "$VAR" in
    "-q" )
      QUIET=1;;
    "--quiet" )
      QUIET=1;;
    * )
      if [[ "$VAR" != "-h" && "$VAR" != "--help" ]]
      then
        echo "Invalid argument: $VAR"
      fi
      echo "Usage: $(basename "$0") [-q|--quiet]"
      exit -1;;
  esac
done

# switch to base directory of repo
SCRIPTS_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
BASE_DIR=$(realpath "$SCRIPTS_DIR/..")
cd "$BASE_DIR"

# find tools and set env variables pointing to them
echo "#!/bin/bash" > build/setenv.sh
scripts/find_tools.sh -g >> build/setenv.sh
. build/setenv.sh
rm ./build/setenv.sh

# find base source directory for papyrus compiler (installed with creation kit)
SOURCE_BASE="$DIR_FALLOUT4CREATIONKIT/Data/Scripts/Source/Base"
if [[ ! -f "$SOURCE_BASE/Institute_Papyrus_Flags.flg" ]]
then
    SOURCE_BASE="$DIR_FALLOUT4/Data/Scripts/Source/Base"
    if [[ ! -f "$SOURCE_BASE/Institute_Papyrus_Flags.flg" ]]
    then
      SOURCE_BASE="$DIR_FALLOUT4CREATIONKIT/Data/Scripts/Source/Base"
      if [[ -f "$SOURCE_BASE/Base.zip" ]]
      then
        echo "Trying to extract '$SOURCE_BASE/Base.zip'..."
        "$TOOL_7ZIP" x "-o$SOURCE_BASE" "$SOURCE_BASE/Base.zip"
      fi
      if [[ ! -f "$SOURCE_BASE/Institute_Papyrus_Flags.flg" ]]
      then
        >&2 echo "ERROR: Unable to find papyrus base source dir."
        >&2 echo "      (expected in: $SOURCE_BASE)"
        exit -1
      fi
    fi
fi
SOURCE_BASE=$(echo "$SOURCE_BASE" | sed -e 's/\///' -e 's/\//:\\/' -e 's/\//\\/g')

# find F4SE scripts source directory for papyrus compiler
SOURCE_F4SE="$DIR_FALLOUT4CREATIONKIT/Data/Scripts/Source"
if [[ ! -f "$SOURCE_F4SE/F4SE.psc" ]]
then
    SOURCE_F4SE="$DIR_FALLOUT4/Data/Scripts/Source"
    if [[ ! -f "$SOURCE_F4SE/F4SE.psc" ]]
    then
      >&2 echo "ERROR: Unable to find papyrus F4SE source dir."
      >&2 echo "       (expected in: $SOURCE_F4SE)"
      exit -1
    fi
fi
SOURCE_F4SE=$(echo "$SOURCE_F4SE" | sed -e 's/\///' -e 's/\//:\\/' -e 's/\//\\/g')

# set up a function to compile all scripts in a folder using parallel execution
# $1: input folder (must be subfolder of "package")
# $2: path in input folder (usually 'Source/User')
# $3: additional imports
function compile_folder() {
  if [[ $QUIET == 0 ]]
  then
    echo "Compiling: $1"
  fi
  cd "$BASE_DIR/$1/$2"
  files=()
  pids=()
  # the for loops works because the folders (which correspond to namespaces) have no whitespace
  for f in $(find . -name '*.psc' |  sed -e 's/.\///' -e 's/\//\\/g')
  do
    files+=( "$f" )
    if [[ "$f" =~ "Debug" ]]
    then
      options="-final -optimize -quiet"
    else
      options="-release -final -optimize -quiet"
    fi
    "$DIR_FALLOUT4CREATIONKIT/Papyrus Compiler/PapyrusCompiler.exe" "$f" $options -flags="$SOURCE_BASE\\Institute_Papyrus_Flags.flg" -import="$(cygpath -w "$BASE_DIR/stubs");$SOURCE_F4SE;$SOURCE_BASE;$3" -output="$(echo "$BASE_DIR/build/$1" | sed -e 's/\///' -e 's/\//:\\/' -e 's/\//\\/g')" &
    pids+=( "$!" )
  done
  failures=()
  for index in ${!pids[*]}
  do 
    wait ${pids[$index]} || failures+=( "${files[$index]}" )
  done
  if [[ ${#failures[@]} > 0 ]]
  then
    for file in "${failures[@]}"
    do
      echo "ERROR: Compilation failed for: $1/Source/User/$(echo $file | sed 's/\\/\//g')."
    done
    exit -1
  else
    if [[ $QUIET == 0 ]]
    then
      echo "  Compiled ${#pids[@]} files."
    fi
  fi
  cd "$BASE_DIR"
}

# call the function for the package/Data folder
compile_folder "package/Data/Scripts" "Source/User"
