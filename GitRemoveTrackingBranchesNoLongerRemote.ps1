# <https://stackoverflow.com/a/48411554> from <https://stackoverflow.com/questions/7726949/remove-tracking-branches-no-longer-on-remote>
git branch --list --format "%(if:equals=[gone])%(upstream:track)%(then)%(refname:short)%(end)" | ? { $_ -ne "" } | % { git branch -D $_ }
