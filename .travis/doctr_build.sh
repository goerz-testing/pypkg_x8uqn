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
    python -m pip install githubrelease

    echo "### [zip]"
    cp -r docs/_build/html "docs/pypkg_x8uqn_$TRAVIS_TAG"
    cd docs/ || exit
    zip -r "pypkg_x8uqn_$TRAVIS_TAG.zip" "pypkg_x8uqn_$TRAVIS_TAG"
    cd ../ || exit
    mkdir docs/_build/artifacts
    mv docs/*.zip docs/_build/artifacts
    githubrelease asset "$TRAVIS_REPO_SLUG" "$TRAVIS_TAG" "docs/_build/artifacts/*"

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
