# Site monitor

Checks the home page of every site in `sites.txt` every 5 minutes, from the DigitalOcean droplet (outside SiteGround,
where the sites are hosted). When a site doesn't return a full page within 30 seconds, twice in a row, an issue
**Website down: names** opens and GitHub emails the owner.

**One outage = two emails** (since 10 Nov 2026; one 5-minute blip on Realpoint and 100k had sent 10). All sites that
are down share one issue (label `outage`); a site that goes down later is added by editing it, which sends no email.
When every site works again the issue is renamed **Back to normal: names** and closed with no comment: the second
email. Luxury's own 10-minute SiteGround cron check (Luxury repo `scripts/uptime/check.php`) was switched off the same
day, so this is the only site alert.

- **Bot checks are not outages.** SiteGround sometimes shows GitHub's runners (datacenter addresses) its "verifying
  you're human" page with code 202, or Cloudflare shows "Just a moment". Since 1 Nov 2026 that counts as "challenged":
  a warning in the run log, no issue opened or closed. A real outage still shows as a timeout or a 5xx error.
  (The alerts at 13:56 UK on 1 Nov, issues #2-#4, were this: code 202 on the three SiteGround sites at once.)
- Each site gets a second check 20 seconds after a failure; an issue opens only if both fail.
- Add or remove a site: edit `sites.txt`.
- Run a check now: Actions → Check sites → Run workflow.
- History of outages: the closed issues (#1-#8 are the old one-issue-per-site alerts).

Set up 1 Nov 2026 after two outages on italianhomesunder100k.com (31 Oct and 1 Nov) that nobody was told about.
Public so GitHub Actions minutes are free; it holds only public site addresses.

## The monitoring server (since 10 Nov 2026)

GitHub only ran the 5-minute schedule about 30 times a day, so the checks now run every 5 minutes from the
DigitalOcean droplet (`ssh droplet`), which SiteGround's bot check doesn't challenge. `droplet/run-monitor.sh` is
installed at `/opt/site-monitor/` with `check.sh` and `sites.txt`, run by root's cron. It checks with
`CHECK_ONLY=1 bash check.sh` and hands the results to this workflow (`workflow_dispatch`, input `report`) when a site
isn't OK, right after a problem clears, and at least once an hour. GitHub's bot then opens and closes the
outage issue, so the emails still come from GitHub (issues opened with the owner's own key send
no email). The key is a fine-grained token in `/opt/site-monitor/gh-token` (this repository only; Actions and Issues
read/write), saved there by the owner. Log: `/opt/site-monitor/monitor.log`. GitHub's own schedule was removed on 10 Nov 2026 (one source of alerts); the daily watchdog task flags it if the droplet stops handing over for 2 hours.
After changing `check.sh` or `sites.txt`, copy them to `/opt/site-monitor/` as well.
