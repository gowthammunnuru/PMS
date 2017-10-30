
### How to deploy perform
 - Checkout master `git checkout master`
 - run `./utils/buildtools/deploy -release_type <type>`
 -- `type` can be one of "major", "minor" or "patch"
 - Push changes everywhere `git checkout master; git push` and `git checkout develop; git push`
 -- `git push --tags`
