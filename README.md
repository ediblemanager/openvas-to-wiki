# Openvas to wiki Processing Script (Beta)

openvas-to-wiki allows you to process openVAS HTML output to mediawiki format.

The script assumes you're running linux, have a ruby version > 1.8.7 installed as well as the html2wiki package (and mediawiki module) and have the following gems installed:

chronic
active_support
active_record

openvas-to-wiki is predominantly written in ruby, but with elements of bash and perl.

### Notes
I've run this script, mostly unedited on both Fedora (F16,17) and Ubuntu (10.04, 11.10) machines.
The main issue that I encounter is the setup of openVAS (information about openvas setup: <a href="http://www.openvas.org/install-packages.html">Installing openVas through packages</a>).

In this repository, there is code which allows for parsing of kismet log files into mediawiki format. This will be removed and pushed into a separate repository very soon.

### Set-up

As previously said, you'll need openVAS up and running before this script will work. Currently, the script needs to have a variable set (the html_id from omp) and two (or more) arrays initialised with the names of scan targets. I'll cover how to do this now.

## Find the html-id from omp.

Running the following command will give you the various different output formats supported by omp:
`omp -F`

This should give you something like the following:

`5ceff8ba-1f62-11e1-ab9f-406186ea4fc5  CPE
6c248850-1f62-11e1-b082-406186ea4fc5  HTML
77bd6c4a-1f62-11e1-abf0-406186ea4fc5  ITG
a684c02c-b531-11e1-bdc2-406186ea4fc5  LaTeX
9ca6fe72-1f62-11e1-9e7c-406186ea4fc5  NBE
c402cc3e-b531-11e1-9163-406186ea4fc5  PDF
a3810a62-1f62-11e1-9219-406186ea4fc5  TXT
a994b278-1f62-11e1-96ac-406186ea4fc5  XML`

The script requires the HTML id (the many digits to the left of 'HTML' above) to
be set in the script.

Line 66 is where the variable currently resides, @html_id.

## Set up the arrays of network segments and targets.

Currently the script can process two separate network segments, outputting the
results from the processing into separate folders. In order to do so, it uses
two arrays (found on lines 79-80) which store the names (as stored by openVAS - they must be **exactly** the same) of the scan targets.

There are future plans to allow for a more flexible setup allowing for the number of segments to be specified along with corresponding targets.

For now, set these arrays up and run the script.

### Running the script

In order to use the script, make sure that openVAS is set up and running (see "Notes" section above for link to openVAS package installation guide), and that you have the required ruby version and gems, as well as html2wiki (with the mediawiki plugin).

Once these are installed and working, you'll need to make the script "automate_security_scans" executable and then run it with the following: ./automate_security_scanss openvas .

This will then bring a prompt with the date for the scans to be processed. Enter the date, or hit enter to collect the last scans (before this, you'll need to set the last scan day in the script).

The script will execute and output the wiki files into "processed_files/yyyy/mm/dd/dd_month_yyyy.wiki.

Done!

#### License

This is licensed under GNU GPL version 3: [http://www.gnu.org/licenses/gpl.html](http://www.gnu.org/licenses/gpl.html). See COPYING for more information.
