# Openvas to wiki Processing Script (Beta)

openvas-to-wiki allows you to process openVAS HTML output to mediawiki format.

The script assumes you're running linux, have a ruby version > 1.8.7 installed as well as the html2wiki package (and mediawiki module) and have the following gems installed:

chronic
open3
active_support
active_record

openvas-to-wiki is predominantly written in ruby, but with elements of bash and perl.

### Notes
I've run this script, mostly unedited on both Fedora (F16,17) and Ubuntu (10.04, 11.10) machines.
The main issue that I encounter is the setup of openVAS (information about openvas setup: <a href="http://www.openvas.org/install-packages.html">Installing openVas through packages</a>

There is, in this repository, code which allows for parsing of kismet log files into mediawiki format. This will be removed and pushed into a separate repository very soon.

### Usage

In order to use the script, make sure that openVas is set up and running (see "Notes" section above for link to openVAS package installation guide), and that you have the required ruby version and gems, as well as html2wiki (with themediawiki plugin).

Once these are installed and working, you'll need to make the script "automate_security_scans" executable and then run it with the following: ./automate_security_scanss openvas .

This will then bring a prompt with the date for the scans to be processed. Enter the date, or hit enter to collect the last scans (before this, you'll need to set the last scan day in the script).

The script will execute and output the wiki files into "processed_files/yyyy/mm/dd/dd_month_yyyy.wiki.

Done!

#### License

This is licensed under GNU GPL version 3: [http://www.gnu.org/licenses/gpl.html](http://www.gnu.org/licenses/gpl.html). See COPYING for more information.
