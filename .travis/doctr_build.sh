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

    echo "### [zip]"
    cp -r docs/_build/html "docs/pypkg_x8uqn_$TRAVIS_TAG"
    cd docs/ || exit
    zip -r "pypkg_x8uqn_$TRAVIS_TAG.zip" "pypkg_x8uqn_$TRAVIS_TAG"
    cd ../ || exit
    mkdir docs/_build/artifacts
    mv docs/*.zip docs/_build/artifacts

    # upload as release assets
    GH_API="https://api.github.com"
    GH_REPO="$GH_API/repos/$TRAVIS_REPO_SLUG"
    GH_TAGS="$GH_REPO/releases/tags/$TRAVIS_TAG"
    AUTH="Authorization: token $GITHUB_TOKEN"
    WGET_ARGS="--content-disposition --auth-no-challenge --no-cookie"
    CURL_ARGS="-LJO#"
    curl -o /dev/null -sH "$AUTH" $GH_REPO || { echo "Error: Invalid repo, token or network issue!";  exit 1; }
    response=$(curl -sH "$AUTH" $GH_TAGS)
    eval $(echo "$response" | grep -m 1 "id.:" | grep -w id | tr : = | tr -cd '[[:alnum:]]=')
    for filename in docs/_build/artifacts/*; do
        GH_ASSET="https://uploads.github.com/repos/$TRAVIS_REPO_SLUG/releases/$id/assets?name=$(basename $filename)"
        curl "$GITHUB_OAUTH_BASIC" --data-binary @"$filename" -H "Authorization: token $github_api_token" -H "Content-Type: application/octet-stream" $GH_ASSET
    done

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
