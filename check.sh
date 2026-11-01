#!/usr/bin/env bash
# Checks every site in sites.txt. A site is down when its home page doesn't return a full page (HTTP 200 and </html>)
# within 30 seconds, twice in a row 20 seconds apart. A down site gets an open issue "Website down: <name>" (GitHub
# emails the owner); when it works again the issue gets a "working again" comment and is closed (another email).
set -u
uk_time() { TZ=Europe/London date '+%H:%M on %-d %b'; }

check() { # prints "ok" or, in plain English, what went wrong
	local out code
	out=$(curl -sS -L -m 30 -A 'Mozilla/5.0 (site-monitor; +https://github.com/JreMarketing/site-monitor)' \
		-o body.html -w '%{http_code}' "$1?uptime=$(date +%s)" 2>/dev/null) || { echo "it didn't load within 30 seconds"; return; }
	code=$out
	case "$code" in
		200) grep -qi '</html>' body.html && echo ok || echo "only part of the page loaded" ;;
		5*) echo "it shows a server error (code $code)" ;;
		404) echo "the page was not found (code 404)" ;;
		*) echo "it gave an unexpected answer (code $code)" ;;
	esac
}

grep -v '^\s*#' sites.txt | grep . | while IFS='|' read -r site name; do
	site=$(echo $site); name=$(echo $name)
	r=$(check "$site")
	[ "$r" != ok ] && { sleep 20; r=$(check "$site"); }
	title="Website down: $name"
	open=$(gh issue list --state open --limit 100 --json number,title --jq ".[] | select(.title == \"$title\") | .number" | head -1)
	echo "$name: $r${open:+ (issue #$open open)}"
	if [ "$r" != ok ] && [ -z "$open" ]; then
		gh issue create --title "$title" --body "**$name is not working.** $site
${r^} (checked at $(uk_time) UK time, twice).

You'll get another email as soon as it's working again.

_Automatic alert for @JreMarketing._" >/dev/null
	elif [ "$r" = ok ] && [ -n "$open" ]; then
		gh issue comment "$open" --body "**$name is working again** (checked at $(uk_time) UK time).

_Automatic alert for @JreMarketing._" >/dev/null
		gh issue close "$open" >/dev/null
	fi
done
