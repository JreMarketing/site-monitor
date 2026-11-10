#!/usr/bin/env bash
# Checks every site in sites.txt. A site is down when its home page doesn't return a full page (HTTP 200 and </html>)
# within 30 seconds, twice in a row 20 seconds apart. Down sites share one open issue "Website down: <names>" (GitHub
# emails the owner); when every site works again it is renamed "Back to normal: <names>" and closed (one more email).
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

down=""; downnames=""
while IFS='|' read -r site name; do
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
	echo "$name: $r"
	if [ "$r" = challenged ]; then
		echo "::warning::$name: bot check (code 202 or a challenge page), not counted as down or up"
	elif [ "$r" != ok ]; then
		down="$down- **$name** ($site): ${r}"$'\n'
		downnames="${downnames:+$downnames, }$name"
	fi
done < <(grep -v '^\s*#' sites.txt | grep .)
[ -n "${CHECK_ONLY:-}" ] && exit 0

# One issue per outage (10 Nov 2026, owner: one short blip had sent 10 emails). It opens once, listing every site that
# is down (1 email); sites that go down later are added by editing it (edits send no email); when every site works
# again it is renamed "Back to normal: ..." and closed with no comment (1 email). So one outage = 2 emails.
open=$(gh issue list --state open --label outage --limit 1 --json number --jq '.[0].number // empty')
if [ -n "$down" ]; then
	body="**Not working** (checked at $(uk_time) UK time, twice):

$down
You'll get one more email when every site is working again.

_Automatic alert for @JreMarketing._"
	if [ -z "$open" ]; then
		gh label create outage --color B60205 --description 'Site monitor: websites down' >/dev/null 2>&1 || true
		gh issue create --title "Website down: $downnames" --label outage --body "$body" >/dev/null && echo "opened an outage issue"
	else
		old=$(gh issue view "$open" --json title --jq .title)
		if [ "$old" != "Website down: $downnames" ]; then # another site went down (or one came back): update the list
			gh issue edit "$open" --title "Website down: $downnames" --body "${body%%_Automatic alert*}" >/dev/null
		fi
		echo "outage issue #$open still open"
	fi
elif [ -n "$open" ]; then
	was=$(gh issue view "$open" --json title --jq .title | sed 's/^Website down: //')
	gh issue edit "$open" --title "Back to normal: $was" --body "**Every site is working again** (checked at $(uk_time) UK time). Was down: $was." >/dev/null
	gh issue close "$open" --reason completed >/dev/null && echo "outage issue #$open closed: back to normal"
fi
