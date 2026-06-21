# ts
Package manager for CraftOS

## Getting started
To get started using ts run
```
pastebin get ASbu8DXY programs/ts.lua
programs/ts.lua update
```

## Installing, updating and removing programs
You can install programs using the command `ts install <name>` (i.e. `ts install ftp`).
To update a program, simply run the install command again.
To update all installed programs, run `ts update` (optional but recommended) and then `ts upgrade`.
Remove programs by running `ts remove <name>`.

## Adding your own repositories
You are not limited to my software; You can add your own repositories either from github or other hosts.

### Github
To add a repository from github, run `ts config repo-add -github <owner> <repo> <branch>` where owner is the username,
repo is the repository name and branch is the branch name. To find these values, simply look at the repository url.
For example, when you are looking at this file, the url is *https[]()://github.com/**TunaAlert**/**ts**/blob/**main**/README.md*
where TunaAlert is the owner name, ts is the repo name and main is the branch name. So, to add this repository you would run
`ts config repo-add -github TunaAlert ts main`. You can also remove repos by running the same command with `repo-remove` instead.

### Other hosts
To add a repo from another host, run `ts config repo-add -url <url>` where url leads to the root of the repository.
So, to add this repository you would run `ts config repo-add -url https://raw.githubusercontent.com/TunaAlert/ts/refs/heads/main`.
To make software in these repositories installable, make sure there is a suitable file matching the path ts/&lt;name&gt;.yaml for each
program you want to host. I.e., my repository has the file *https[]()://github.com/TunaAlert/ts/blob/main/ts/ftp.yaml* for my ftp program.

## Listing programs and repos
You can see a list of installed programs or repos by running `ts list programs` or `ts list repos`.

