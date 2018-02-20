#!/bin/sh

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
cd ..

BUMP_TYPE=$1
if [ "$BUMP_TYPE" != "patch" ] && [ "$BUMP_TYPE" != "minor" ] && [ "$BUMP_TYPE" != "major" ]; then
	echo $"Usage: $0 <patch|minor|major>"
	exit 1
fi

# Get current package version
LAST_VERSION=`cat StitchCore.podspec | grep "s.version" | head -1 | sed -E 's/[[:space:]]+s\.version.*=.*"(.*)"/\1/'`
LAST_VERSION_MAJOR=$(echo $LAST_VERSION | cut -d. -f1)
LAST_VERSION_MINOR=$(echo $LAST_VERSION | cut -d. -f2)
LAST_VERSION_PATCH=$(echo $LAST_VERSION | cut -d. -f3)

NEW_VERSION_MAJOR=$LAST_VERSION_MAJOR
NEW_VERSION_MINOR=$LAST_VERSION_MINOR
NEW_VERSION_PATCH=$LAST_VERSION_PATCH

if [ "$BUMP_TYPE" == "patch" ]; then
	NEW_VERSION_PATCH=$(($LAST_VERSION_PATCH+1))
elif [ "$BUMP_TYPE" == "minor" ]; then
	NEW_VERSION_MINOR=$(($LAST_VERSION_MINOR+1))
	NEW_VERSION_PATCH=0
else
	NEW_VERSION_MAJOR=$(($LAST_VERSION_MAJOR+1))
	NEW_VERSION_MINOR=0
	NEW_VERSION_PATCH=0
fi

NEW_VERSION=$NEW_VERSION_MAJOR.$NEW_VERSION_MINOR.$NEW_VERSION_PATCH

echo "Bumping $LAST_VERSION to $NEW_VERSION ($BUMP_TYPE)"

echo "Updating StitchCore.podspec"
sed -i "" -E "s/([[:space:]]+s\.version[[[:space:]]+=).*$/\1 \"$NEW_VERSION\"/" ./StitchCore.podspec

for file in ./*.podspec ; do
  if grep 's\.dependency "StitchCore' > /dev/null $file; then
	sed -i "" -E "s/([[:space:]]+s\.dependency[[:space:]]+\"StitchCore\",[[:space:]]+\"~>[[:space:]]+).*(\".*)$/\1$NEW_VERSION\2/" $file
	sed -i "" -E "s/([[:space:]]+s\.version[[[:space:]]+=).*$/\1 \"$NEW_VERSION\"/" ./$file
  fi
  git add $file
done

git commit -m "Release $NEW_VERSION"
BODY=`git log --no-merges $LAST_VERSION..HEAD --pretty="format:%s (%h); %an"`
BODY="Changelog since $LAST_VERSION:
$BODY"
git tag -a "$NEW_VERSION" -m "$BODY"
