#!/usr/bin/env bash
# Checks every site in sites.txt. A site is down when its home page doesn't return a full page (HTTP 200 and </html>)
# within 30 seconds, twice in a row 20 seconds apart. A down site gets an open issue "Website down: <name>" (GitHub
# emails the owner); when it works again the issue gets a "working again" comment and is closed (another email).
# A bot check (SiteGround's "verifying you're human" page answers 202, Cloudflare's "Just a moment") means the server
# answered but wouldn't show GitHub's runner the page: that is "challenged", not down, so it opens and closes nothing.
# A real outage still shows as a timeout or a server error. False alarms on 1 Nov 2026 13:56 (issues #2-#4).
#
# Two extra modes (10 Nov 2026), because GitHub only ran the 5-minute schedule ~30 times a day:
# - CHECK_ONLY=1: just check and print "name<TAB>result" lines, no issues (the DigitalOcean droplet runs this every
#   5 minutes from cron, see droplet/run-monitor.sh; it isn't challenged by SiteGround's bot check).
# - REPORT="name<TAB>result" lines: use those results instead of checking (the droplet passes its results to the
#   "Check sites" workflow, so GitHub's bot opens and closes the issues and GitHub emails the owner as before; issues
#   opened with the owner's own key send no email). A site missing from the report is checked here as usual.
set -u
uk_time() { TZ=Europe/London date '+%H:%M on %-d %b'; }

check() { # prints "ok" or, in plain English, what went wrong
	local out code
	out=$(curl -sS -L -m 30 -A 'Mozilla/5.0 (site-monitor; +https://github.com/JreMarketing/site-monitor)' \
		-D headers.txt -o body.html -w '%{http_code}' "$1?uptime=$(date +%s)" 2>/dev/null) || { echo "it didn't load within 30 seconds"; return; }
	code=$out
	if [ "$code" = 202 ] || grep -qiE 'sgcaptcha|Just a moment|challenge-platform' body.html; then
		{ echo "::group::Bot check details for $1 ($(date -u '+%Y-%m-%d %H:%M:%S UTC'), runner IP $(curl -s -m 5 https://api.ipify.org))"
		  grep -iE '^(HTTP|server|cf-ray|cf-mitigated|date|location|x-|sg-)' headers.txt; head -c 400 body.html; echo; echo "::endgroup::"; } >&2
		echo challenged; return
	fi
	case "$code" in
		200) grep -qi '</html>' body.html && echo ok || echo "only part of the page loaded" ;;
		5*) echo "it shows a server error (code $code)" ;;
		404) echo "the page was not found (code 404)" ;;
		*) echo "it gave an unexpected answer (code $code)" ;;
	esac
}

grep -v '^\s*#' sites.txt | grep . | while IFS='|' read -r site name; do
	site=$(echo $site); name=$(echo $name)
	r=$(printf '%s\n' "${REPORT:-}" | awk -F'\t' -v n="$name" '$1 == n { print $2; exit }')
	if [ -z "$r" ]; then
		r=$(check "$site")
		[ "$r" != ok ] && { sleep 20; r=$(check "$site"); }
	else
		case "$r" in ok | challenged) ;; *) r="$r, seen from the monitoring server" ;; esac
	fi
	if [ -n "${CHECK_ONLY:-}" ]; then
		printf '%s\t%s\n' "$name" "$r"
		continue
	fi
	title="Website down: $name"
	open=$(gh issue list --state open --limit 100 --json number,title --jq ".[] | select(.title == \"$title\") | .number" | head -1)
	echo "$name: $r${open:+ (issue #$open open)}"
	if [ "$r" = challenged ]; then
		echo "::warning::$name: bot check (code 202 or a challenge page), not counted as down or up"
	elif [ "$r" != ok ] && [ -z "$open" ]; then
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
