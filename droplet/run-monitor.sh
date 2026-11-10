#!/usr/bin/env bash
# Site monitor on the DigitalOcean droplet (10 Nov 2026, owner: "Yes, move them"). Installed at
# /opt/site-monitor/run-monitor.sh with check.sh and sites.txt beside it, run by root's cron every 5 minutes.
# Why: GitHub only ran the "Check sites" schedule ~30 times a day instead of 288.
# It checks every site here (CHECK_ONLY=1 bash check.sh), then hands the results to the "Check sites" workflow
# (workflow_dispatch, input "report"), whose bot opens/closes the "Website down" issues so GitHub emails the owner.
# (Issues opened with the owner's own key send no email: tested 10 Nov, issue #6.)
# It hands over when a site isn't ok, when the last hand-over wasn't all ok (so "working again" is sent), and at
# least once an hour. Key: /opt/site-monitor/gh-token (fine-grained, site-monitor only: Actions + Issues read/write),
# saved by the owner. Log: /opt/site-monitor/monitor.log (last 3000 lines kept).
set -u
cd /opt/site-monitor || exit 1
exec 9>/opt/site-monitor/.lock
flock -n 9 || exit 0
log=/opt/site-monitor/monitor.log
{
	echo "=== $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
	tmp=$(mktemp -d)
	cp check.sh sites.txt "$tmp"/
	report=$(cd "$tmp" && CHECK_ONLY=1 timeout 240 bash check.sh 2>/dev/null)
	rm -rf "$tmp"
	printf '%s\n' "$report"
	allok=$( [ -n "$report" ] && ! printf '%s\n' "$report" | awk -F'\t' '$2 != "ok"' | grep -q . && echo 1 || echo 0 )
	last=$(cat last-allok 2>/dev/null || echo 0)
	age=$(( $(date +%s) - $(stat -c %Y last-sent 2>/dev/null || echo 0) ))
	if [ -z "$report" ]; then
		echo "ERROR: the check printed nothing"
	elif [ "$allok" = 0 ] || [ "$last" = 0 ] || [ "$age" -gt 3600 ]; then
		if [ ! -s gh-token ]; then
			echo "ERROR: no GitHub key in /opt/site-monitor/gh-token, so nothing can be sent"
		elif GH_TOKEN=$(cat gh-token) gh workflow run monitor.yml -R JreMarketing/site-monitor -f report="$report" 2>&1; then
			echo "sent to the Check sites workflow"
			echo "$allok" > last-allok
			touch last-sent
		else
			echo "ERROR: couldn't start the Check sites workflow (key expired or missing the Actions permission?)"
		fi
	fi
} >> "$log" 2>&1
tail -n 3000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
