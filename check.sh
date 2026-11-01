#!/usr/bin/env bash
# Checks every site in sites.txt. A site is down when its home page doesn't return a full page (HTTP 200 and </html>)
# within 30 seconds, twice in a row 20 seconds apart. A down site gets an open issue "DOWN: <site>" (GitHub emails the
# owner); when it answers again the issue gets a "back up" comment and is closed (another email).
set -u
now() { date -u '+%d %b %Y %H:%M UTC'; }

check() { # prints "ok" or the reason it failed
	local out code time
	out=$(curl -sS -L -m 30 -A 'Mozilla/5.0 (site-monitor; +https://github.com/JreMarketing/site-monitor)' \
		-o body.html -w '%{http_code} %{time_total}' "$1?uptime=$(date +%s)" 2>&1) || { echo "no answer (${out##*) })"; return; }
	code=${out%% *}; time=${out##* }
	if [ "$code" != 200 ]; then echo "HTTP $code after ${time}s"; return; fi
	grep -qi '</html>' body.html || { echo "incomplete page after ${time}s"; return; }
	echo ok
}

grep -v '^\s*#' sites.txt | grep . | while read -r site; do
	name=${site#https://}; name=${name%/}
	r=$(check "$site")
	[ "$r" != ok ] && { sleep 20; r=$(check "$site"); }
	open=$(gh issue list --state open --limit 100 --json number,title --jq ".[] | select(.title == \"DOWN: $name\") | .number" | head -1)
	echo "$name: $r${open:+ (issue #$open open)}"
	if [ "$r" != ok ] && [ -z "$open" ]; then
		gh issue create --title "DOWN: $name" --body "@JreMarketing $site is not working: $r (checked $(now), twice 20 seconds apart).

This issue closes itself with a comment when the site answers again." >/dev/null
	elif [ "$r" = ok ] && [ -n "$open" ]; then
		gh issue comment "$open" --body "@JreMarketing $site is back up ($(now))." >/dev/null
		gh issue close "$open" >/dev/null
	fi
done
