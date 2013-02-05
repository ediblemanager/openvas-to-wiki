# Openvas to wiki Processing Script (Beta)

openvas-to-wiki allows you to process openVAS HTML output to mediawiki format.

The script assumes you're running linux, have a ruby version > 1.8.7 installed as well as the html2wiki package (and mediawiki module) and have the chronic gem installed.

openvas-to-wiki is predominantly written in ruby, but with elements of bash and perl. I hope in the future to make this a pure ruby experience (but don't have the time at the moment).

### Notes
I've run this script, mostly unedited on both Fedora (F16,17) and Ubuntu (10.04, 11.10) machines.
The main issue that I encounter is the setup of openVAS (information about openvas setup: <a href="http://www.openvas.org/install-packages.html">Installing openVAS through packages</a>).

In this repository, there is code which allows for parsing of kismet log files into mediawiki format. This will be removed and pushed into a separate repository very soon.

### Set-up

The script is now fully automated, with the output format automatically set to be HTML.

On the first run of the script, you'll be prompted to give details about the network configuration (such as number of segments, names for the segments and targets). This data will be stored in:

	config/network_segments.txt

On subsequent runs, the config data will be loaded and you'll be prompted only to select a date, after which all scans that were run on the date will be processed.

As previously said, you'll need openVAS up and running before this script will work.

In order to check that it is, run:

	omp -G

and you should see output. If you don't, then there's probably an issue (either it isn't running, or another problem exists. Check the logs.

### Running the script

In order to use the script, make sure that openVAS is set up and running (see "Notes" section above for link to openVAS package installation guide), and that you have the required ruby version and chronic, as well as html2wiki (with the mediawiki plugin).

Once these are installed and working, you can run the script with the following:

	ruby automate_security_scans.rb openvas

This will then bring a prompt with the date for the scans to be processed. Enter the date, or hit enter to collect the last scans (before this, you'll need to set the last scan day in the script).

The script will execute and output the wiki files into "processed_files/".

Done!

#### License

This is licensed under GNU GPL version 3: [http://www.gnu.org/licenses/gpl.html](http://www.gnu.org/licenses/gpl.html). See COPYING for more information.
