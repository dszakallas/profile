---

title: Set up multiple Git users on your machine
key: 2017-11-11-set-up-multiple-git-users-on-your-machine
tags:
  - git
  - developer tools
  - tutorial
---
It is quite common to have separate users for different git repos. For example having a public account
for all your open-source GitHub stuff, and a work account for your employer's private git remote.

If you regularly have to clone new repos in each 'role', defaulting to one and changing the
local repository config in all others quickly becomes cumbersome. Fortunately git can do better!

Since git 2.13, you can have [conditional includes](https://git-scm.com/docs/git-config#_conditional_includes)
in config files. You can use a path selector to determine which config files will be included for which paths.
Then if you place your projects into directories according to the user you want to use for
it by default and have separate include files for the users, you are done!

So, if you have this tree

```
.
├── personal
│   ├── proj_1
│   └── proj_2
└── work
    └── proj_3
```

create two include files, and add different config for them, e.g.
```
cat ~/.personal.git.inc

[user]
	name = Me
	email = me@person.al
```


```
cat~/.work.git.inc

[user]
	name = Me
	email = me@workpla.ce
```
then remove user related stuff from `~/.gitconfig` and add the conditional inclusion instead:

```
[includeIf "gitdir:./personal/"]
	path = ./.personal.gitconfig.inc
[includeIf "gitdir:./work/"]
	path = ./.work.gitconfig.inc
```
The selector path syntax is a bit special, an ending `/` will expand to a `/**` glob so it will work recursively.

You a can test it with e.g. printing out `user.email` in your repo:

```
git config user.email
```

should be `me@workpla.ce` for repositories under `work`.

Hope this helps!
