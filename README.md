# Site monitor

Checks the home page of every site in `sites.txt` every 5 minutes, from GitHub (outside SiteGround, where all the
sites are hosted). When a site doesn't return a full page within 30 seconds, twice in a row, an issue **DOWN: site**
opens and GitHub emails the owner; when the site works again the issue gets a "back up" comment and closes.

- Add or remove a site: edit `sites.txt`.
- Run a check now: Actions → Check sites → Run workflow.
- History of outages: the closed issues.

Set up 1 Nov 2026 after two outages on italianhomesunder100k.com (31 Oct and 1 Nov) that nobody was told about.
Public so GitHub Actions minutes are free; it holds only public site addresses.
