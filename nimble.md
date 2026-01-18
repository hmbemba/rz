# Locally install package

nimble uninstall pkgName ; nimble install

# Publish

nimble publish

# Update Pkg

git add . ; git status ; git commit -m 'Updated tests'; git tag "v0.1.2" ; git push origin master --tags

