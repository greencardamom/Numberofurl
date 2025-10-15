Numberofurl
===================
by User:GreenC (en.wikipedia.org)

October 2025

MIT License

Files
========

Numberofurl is a Wikipedia bot that creates and maintains:

* [Commons:Data:Wikipedia_statistics/exturls.tab](https://commons.wikimedia.org/wiki/Data:Wikipedia_statistics/exturls.tab) 

..which are external link statistics for Wikimedia projects. Related project:

* [Numberof](https://github.com/greencardamom/Numberof) 

Dependencies 
========
* GNU Awk 4.1+
* [BotWikiAwk](https://github.com/greencardamom/BotWikiAwk) (version December 2023 or later)
* [Findlinks](https://github.com/greencardamom/Findlinks) (version October 2025 or later)
** This tool requires a Toolforge account (free registration) however it makes SQL queries through a ssh tunnel and can be run from anywhere
* A bot User account with bot permissions on Commons

Installation
========

1. Install BotWikiAwk following setup instructions. 

2. Add OAuth credentials to wikiget (installed with BotWikiAwk), which is the utility that uploads pages to Commons. See [EDITSETUP](https://github.com/greencardamom/Wikiget/blob/master/EDITSETUP).

3. Clone Numberofurl. For example:
	git clone https://github.com/greencardamom/Numberofurl

4. Set ~/Numberofurl/numberofurl.awk to mode 750, and change the first shebang line to the location of awk.

5. In numberofurl.awk in the "BEGIN {" section is a place for home directory and an email address for error reports.

Running
========

1. Run it from cron every x days.
