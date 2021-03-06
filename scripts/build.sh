#!/bin/bash

# this script builds the mod from the package folder
# the final result is a .7z file in the build folder
# this script calls most of the other scripts, so it is not necessary to call them before

# make sure we clean up on exit
ORIGINAL_DIR=$(pwd)
function clean_up {
  cd "$ORIGINAL_DIR"
}
trap clean_up EXIT
set -e

# check arguments
CLEAN=1
QUIET=""
for VAR in "$@"
do
  case "$VAR" in
    "-n" )
      CLEAN=0;;
    "--no-clean" )
      CLEAN=0;;
    "-q" )
      QUIET="-q";;
    "--quiet" )
      QUIET="q";;
    * )
      if [[ "$VAR" != "-h" && "$VAR" != "--help" ]]
      then
        echo "Invalid argument: $VAR"
      fi
      echo "Usage: $(basename "$0") [-q|--quiet] [-n|--no-clean]"
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

# clean if flag was given
if [[ $CLEAN == 1 ]]
then
  if [[ "$QUIET" == "" ]]
  then
    echo Cleaning.
  fi
  scripts/clean.sh $QUIET
fi

# compile papyrus scripts
scripts/compile_papyrus.sh $QUIET

# copy remaining files from package to build
if [[ "$QUIET" == "" ]]
then
  echo Copying files.
fi
cp -r -p package build
cp changelog.txt build/package
cp LICENSE.txt build/package

VERSION=$(cat build/package/Data/Scripts/Source/User/BadEndsFurniture/Installer.psc | sed -nr 's/^\s*String\s+Property\s+DetailedVersion\s*=\s*"([^"]+)"\s+AutoReadOnly\s*(;.*)$/\1/p')
if [[ "$QUIET" == "" ]]
then
  echo "  Version: $VERSION"
fi
mv build/package/FOMod/info.xml build/package/FOMod/info.xml.old
VERSION=$VERSION envsubst < build/package/FOMod/info.xml.old > build/package/FOMod/info.xml
rm build/package/FOMod/info.xml.old

# set up function to pack assets
# $1: folder (must be folder in build/package, without the "build" part
# $2: name of the archive to create
function pack_assets() {
  if [[ "$QUIET" == "" ]]
  then
     echo "Packing assets in $1:"
  fi
  cd "$BASE_DIR/build/$1"
  ROOT=$(pwd | sed -e 's/\///' -e 's/\//:\\/' -e 's/\//\\/g')
  find . -type f ! -path './MCM/*' ! -name '*.psc' ! -name *'.esp' | sed -e 's/.\///' > "$BASE_DIR/build/assets.txt"
  if [[ "$QUIET" == "" ]]
  then
     echo "  $(wc -l < "$BASE_DIR/build/assets.txt") assets found."
  fi
  if [[ -s "$BASE_DIR/build/assets.txt" ]]
  then
    "$DIR_FALLOUT4CREATIONKIT/Tools/Archive2/Archive2.exe" -create="$2" -sourceFile="$BASE_DIR/build/assets.txt" -root="$ROOT" -format="General" -compression="None" -quiet -cleanup
    xargs -a "$BASE_DIR/build/assets.txt" -d '\n' rm
    find . -type d -empty -delete
    if [[ "$QUIET" == "" ]]
    then
      echo "  $2 ($(stat --printf="%s" "$2") bytes)"
    fi
  fi
  rm "$BASE_DIR/build/assets.txt"
  cd "$BASE_DIR"
}

# call the functions for the package/Data folder
pack_assets "package/Data" "BadEndsFurniture - Main.ba2"

# create archive of build/package
if [[ "$QUIET" == "" ]]
then
 echo "Creating archive:"
fi
"$TOOL_7ZIP" a -t7z -mx=9 -mmt=off "build\BadEndsFurniture.$VERSION.7z" ".\build\package\*" > /dev/null
if [[ "$QUIET" == "" ]]
then
 echo "  build/BadEndsFurniture.$VERSION.7z ($(stat --printf="%s" "$BASE_DIR/build/BadEndsFurniture.$VERSION.7z") bytes)"
fi
