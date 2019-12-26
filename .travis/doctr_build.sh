# This script is called from travis.yml for the "Docs" job
echo "# DOCTR - deploy documentation"

echo "## Generate main html documentation"
tox -e docs

if [[ -z "$TRAVIS_TAG" ]]; then

    echo "Deploying as BRANCH $TRAVIS_BRANCH"

else

    echo "Deploying as TAG $TRAVIS_TAG"

    echo "## Generate documentation downloads"
    # We generate documentation downloads only for tags (which are assumed to
    # correspond to releases). Otherwise, we'd quickly fill up git with binary
    # artifacts for every single push.
    mkdir docs/_build/artifacts

    echo "### [zip]"
    cp -r docs/_build/html "docs/pypkg_x8uqn_$TRAVIS_TAG"
    cd docs/ || exit
    zip -r "pypkg_x8uqn_$TRAVIS_TAG.zip" "pypkg_x8uqn_$TRAVIS_TAG"
    rm -rf "pypkg_x8uqn_$TRAVIS_TAG"
    cd ../ || exit
    mv docs/*.zip docs/_build/artifacts

    echo "### [epub]"
    tox -e docs -- -b epub _build/epub
    mv docs/_build/epub/*.epub "docs/_build/artifacts/pypkg_x8uqn_$TRAVIS_TAG.epub"

    # upload as release assets
    # adapted from https://gist.github.com/stefanbuck/ce788fee19ab6eb0b4447a85fc99f447
    # This relies on the encrypted $GITHUB_TOKEN variable in .travis.yml
    GH_API="https://api.github.com"
    GH_REPO="$GH_API/repos/$TRAVIS_REPO_SLUG"
    GH_RELEASES="$GH_REPO/releases"
    GH_TAG="$GH_RELEASES/tags/$TRAVIS_TAG"
    AUTH="Authorization: token $GITHUB_TOKEN"
    WGET_ARGS="--content-disposition --auth-no-challenge --no-cookie"
    CURL_ARGS="-LJO#"
    curl -o /dev/null -sH "$AUTH" "$GH_REPO" || { echo "Error: Invalid repo, token or network issue!";  exit 1; }
    echo "Make release from tag $TRAVIS_TAG: $GH_RELEASES"
    API_JSON=$(printf '{"tag_name": "%s","target_commitish": "master","name": "%s","body": "Release of version %s","draft": false,"prerelease": false}' "$TRAVIS_TAG" "$TRAVIS_TAG" "$TRAVIS_TAG")
    echo "$API_JSON"
    response=$(curl --data "$API_JSON" -H "$AUTH" "$GH_RELEASES")
    echo "Release response: $response"
    echo "verify $GH_TAG"
    response=$(curl -sH "$AUTH" "$GH_TAG")
    echo "$response"
    eval $(echo "$response" | grep -m 1 "id.:" | grep -w id | tr : = | tr -cd '[[:alnum:]]=')
    echo "id = $id"
    for filename in docs/_build/artifacts/*; do
        GH_ASSET="https://uploads.github.com/repos/$TRAVIS_REPO_SLUG/releases/$id/assets?name=$(basename $filename)"
        echo "Uploading $filename as release asset to $GH_ASSET"
        response=$(curl "$GITHUB_OAUTH_BASIC" --data-binary @"$filename" -H "$AUTH" -H "Content-Type: application/octet-stream" "$GH_ASSET")
        echo "Uploaded $filename: $response"
        echo $response | python -c 'import json,sys;print(json.load(sys.stdin)["browser_download_url"])' >> docs/_build/html/_downloads
    done
    echo "docs/_build/html/_downloads:"
    cat docs/_build/html/_downloads

    # upload to bintray
    echo "Upload artifacts to bintray"
    for filename in docs/_build/artifacts/*; do
        BINSTAR_UPLOAD="https://api.bintray.com/content/$BINTRAY_USER/$BINTRAY_ORG/pypkg_x8uqn/$TRAVIS_TAG/$(basename $filename)"
        echo "Uploading $filename artifact to $BINSTAR_UPLOAD"
        response=$(curl -T "$filename" "-u$BINTRAY_USER:$BINTRAY_TOKEN" "$BINSTAR_UPLOAD")
        echo "Uploaded $filename: $response"
    done
    echo "Publishing release on bintray"
    response=$(curl -X POST "-u$BINTRAY_USER:$BINTRAY_TOKEN" "https://api.bintray.com/content/$BINTRAY_USER/$BINTRAY_ORG/pypkg_x8uqn/$TRAVIS_TAG/publish")
    echo "Finished bintray release : $response"

    rm -rf docs/_build/artifacts

fi

# Deploy
echo "## pip install doctr"
python -m pip install doctr
echo "## doctr deploy"
if [[ -z "$TRAVIS_TAG" ]]; then
    DEPLOY_DIR="$TRAVIS_BRANCH"
else
    DEPLOY_DIR="$TRAVIS_TAG"
fi
python -m doctr deploy --key-path docs/doctr_deploy_key.enc \
    --command="git show $TRAVIS_COMMIT:.travis/doctr_post_process.py > post_process.py && git show $TRAVIS_COMMIT:.travis/versions.py > versions.py && python post_process.py" \
    --built-docs docs/_build/html --no-require-master --build-tags "$DEPLOY_DIR"
echo "# DOCTR - DONE"
