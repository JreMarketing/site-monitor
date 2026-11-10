# Site monitor

Checks the home page of every site in `sites.txt` every 5 minutes, from GitHub (outside SiteGround, where all the
sites are hosted). When a site doesn't return a full page within 30 seconds, twice in a row, an issue **Website down: name**
opens and GitHub emails the owner; when the site works again the issue gets a "working again" comment and closes.

- **Bot checks are not outages.** SiteGround sometimes shows GitHub's runners (datacenter addresses) its "verifying
  you're human" page with code 202, or Cloudflare shows "Just a moment". Since 1 Nov 2026 that counts as "challenged":
  a warning in the run log, no issue opened or closed. A real outage still shows as a timeout or a 5xx error.
  (The alerts at 13:56 UK on 1 Nov, issues #2-#4, were this: code 202 on the three SiteGround sites at once.)
- Each site gets a second check 20 seconds after a failure; an issue opens only if both fail.
- Add or remove a site: edit `sites.txt`.
- Run a check now: Actions → Check sites → Run workflow.
- History of outages: the closed issues.

Set up 1 Nov 2026 after two outages on italianhomesunder100k.com (31 Oct and 1 Nov) that nobody was told about.
Public so GitHub Actions minutes are free; it holds only public site addresses.

## The monitoring server (since 10 Nov 2026)

GitHub only ran the 5-minute schedule about 30 times a day, so the checks now also run every 5 minutes from the
DigitalOcean droplet (`ssh droplet`), which SiteGround's bot check doesn't challenge. `droplet/run-monitor.sh` is
installed at `/opt/site-monitor/` with `check.sh` and `sites.txt`, run by root's cron. It checks with
`CHECK_ONLY=1 bash check.sh` and hands the results to this workflow (`workflow_dispatch`, input `report`) when a site
isn't OK, right after a problem clears, and at least once an hour. GitHub's bot then opens and closes the
"Website down" issues as before, so the emails still come from GitHub (issues opened with the owner's own key send
no email). The key is a fine-grained token in `/opt/site-monitor/gh-token` (this repository only; Actions and Issues
read/write), saved there by the owner. Log: `/opt/site-monitor/monitor.log`. The GitHub schedule stays as a backup.
After changing `check.sh` or `sites.txt`, copy them to `/opt/site-monitor/` as well.
