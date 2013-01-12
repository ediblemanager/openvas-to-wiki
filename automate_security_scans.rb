#!/bin/env ruby
# encoding: utf-8

# This will take the output from OMP and process it using ruby, placing the results into
# appropriate folders under the repo directory.
# HTML files are put under the correct network segment, year, month, day
# Processed wiki files are stored under processed_files/network_segment/dd_month_yyyy.wiki
# These can then be copied and pasted into the wiki.
#
# 27/02/2012: Now works on dates entered at prompt (dd/mm/yyyy).
# In order to find out when scans have been run, type "omp -G" into a console, select
# one of the ids on the left, and then run "omp -G <id>". This will give you all
# the dates of the scans for the selected target.

class Automate

  require 'rubygems'
  require 'chronic'
  require 'open3'
  require 'fileutils'
  gem 'activesupport'
  gem 'activerecord'
  require 'active_support'
  require 'active_record'
  include FileUtils

	def initialize
    ARGV.map! &:downcase
    if ARGV.include?("openvas")
      get_openvas_data
      get_user_date
      get_targets_and_names
      get_individual_scans
      return_scan_results
      process_scan_results
    elsif ARGV.include?("kismet")
      run_kismet
      get_kismet_results
    end
	end

  def get_user_date
    puts "Scans are run on <insert day>. Please enter a date you want to retrieve scans for (dd/mm/yyyy), or hit enter to get the latest scans:"
    @user_date = STDIN.gets.chomp.split("/")
    if @user_date.length > 1
      @user_day = @user_date[0].to_i
      @user_month = @user_date[1].to_i
      @user_year = @user_date[2].to_i
      # Set up the date params for grabbing the scans from other time periods
      @other_scan_day = Chronic.parse('next Monday', :now => Time.parse("#{@user_year}-#{@user_month}-#{@user_day}")).strftime("%d")
      @other_scan_month = Chronic.parse('next Monday', :now => Time.parse("#{@user_year}-#{@user_month}-#{@user_day}")).strftime("%m")
      @other_scan_year = Chronic.parse('next Monday', :now => Time.parse("#{@user_year}-#{@user_month}-#{@user_day}")).strftime("%Y")
      puts "  "
      puts "Scan date: #{@user_day}/#{@user_month}/#{@user_year}"
    else
      puts "  "
      puts "Scan date: #{@day}/#{@month_number}/#{@year}"
    end
  end

  def get_openvas_data
    @list_targets = `omp -G`
		@target_ids = Array.new
		@output_html_name = Array.new
		@reports_list = Array.new
    @user_date = ""
		# id for HTML output - this will vary between installations. In future release automatically picked up.
		@html_id = "b993b6f5-f9fb-4e6e-9c94-dd46c00e058d"

    # Get directory for this script
    @current_dir = Dir.pwd.strip

    # Get date
    @year = Chronic.parse("last Saturday").strftime("%Y").to_i
    @month = Chronic.parse("last Saturday").strftime("%B").downcase
    @month_number = Chronic.parse("last Saturday").strftime("%m").to_i
    @day = Chronic.parse("last Saturday").strftime("%d").to_i
    @scan_date = "#{@day}_#{@month}_#{@year}"

		# Create an array/s for the targets specified in OMP - this must match the output from omp
		@target_array_1 = []
		@target_array_2 = []
  end

	def get_targets_and_names
		# Go through the data gathered, strip out the ids and the names.
    @targets = @list_targets.split("\n").collect! {|n| n.split("\t")}
		@targets.each do |element|
      # This will give me the first target's details as an array
      target_details = element.first.split
      # Now that we have the target's details, grab the id
			@target_ids << target_details.first
			# name formatted for html file name use.
			@output_html_name << target_details.last.to_s# + (split_element[4] ? "-" + split_element[4].to_s : "")
		end
	end

  def get_individual_scans
    # Iterate through the scan targets, and grab the data about the scan:
    # i) ID's
    # ii) Dates (for viewing/selecting specific dates)
    @gathered_reports = Hash.new
    @name_of_target = Array.new
    i=0
    puts "  "
    puts "/**************** Scan Targets: ****************/"
    puts "  "
    # Iterate through all scan targets
    @target_ids.each do |target|
      # Find the reports for each target
      reports = `omp -G #{target}`.split("\n").collect! {|n| n.to_s}
      # Get rid fo the first element - it contains the target details (not a report)
      @name_of_target = reports.shift.to_s.split
      # Give the user some output - target details
      puts @name_of_target.inspect
      # Iterate through the individual reports (for a specific target)
      reports.each do |individual_reports|
        # Get each report to analyse against user date.
        selected_report = individual_reports.to_s.split
        # The report dates are formatted like this: 2012-12-22T09:00:13Z. We need to parse this!
        report_date = selected_report[6].split("T").first.split("-")
        report_day = report_date[2]
        report_month = report_date[1]
        report_year = report_date[0]
        # Grab the report for the other scan day (if such data exists!)
        if report_day.to_i == @other_scan_day.to_i && report_month.to_i == @other_scan_month.to_i && report_year.to_i == @other_scan_year.to_i
            @gathered_reports[@name_of_target[2]] = selected_report.first
        end
        # We want to grab either the latest, or all from the date given by user.
        # dd/mm/yyyy => selected_report[8]/[7]/[10]
        if report_day.to_i == @user_day.to_i && report_month.to_i == @user_month.to_i && report_year.to_i == @user_year.to_i
          # There are reports that match the users date input
          @gathered_reports[@name_of_target[2]] = selected_report.first
          @scan_date = "#{@user_day}_#{Date::MONTHNAMES[@user_month.to_i].downcase}_#{@user_year}"
          @date_location = "#{@user_year}/#{@user_month}/#{@user_day}"
          @wiki_name = "#{@user_day}_#{Date::MONTHNAMES[@user_month.to_i].downcase}_#{@user_year}"
        elsif @user_day.nil? && @user_month.nil? && @user_year.nil?
          # We have no date entered. Grab the latest reports.
          # Note: we don't need to specify anything to gather in the scan on
          # another scan day - because it falls in the last set of scans, it is
          # caught here.
          @gathered_reports[@name_of_target[2]] = selected_report.first
          @date_location = "#{@year}/#{@month_number}/#{@day}"
          @wiki_name = "#{@day}_#{Date::MONTHNAMES[@month_number.to_i].downcase}_#{@year}"
        end
      end
      i = i+1
    end
    if @gathered_reports.length == 0
      puts "No reports found with that date. Please re-run the script and try again"
      exit
    end
  end

	def return_scan_results
		i = 0
		@gathered_reports.each_pair do |key, value|
			# Set up network location for html file output
      if @target_array_1.include?(key)
        @network_location = "target_array_1"
			end
			if @target_array_2.include?(key)
        @network_location = "target_array_2"
			end
      @output_file_path = "#{@current_dir}/#{@network_location}/#{@date_location}"
      # Create vars to hold paths for the removal of bad characters.
      @remove_from_target_array_1 = "#{@current_dir}/target_array_1/#{@date_location}"
      @remove_from_target_array_2 = "#{@current_dir}/target_array_2/#{@date_location}"
      # If the base output file path exists
      if !File.exists?(@output_file_path) #&& File.directory?(@output_file_path)
        `mkdir -p #{@output_file_path}`
      end

      if !File.exists?("#{@current_dir}/processed_files/#{@network_location}/#{@date_location}") #&& File.directory?(@output_file_path)
        `mkdir -p #{@current_dir}/processed_files/#{@network_location}/#{@date_location}`
      end
      # This is where we are grabbing the scan results
      `omp --get-report #{value} --format #{@html_id} > #{@output_file_path}/#{key}_#{@scan_date}.html`
      i = i+1
		end
    puts " "
    puts "Running sed commands..."
    #puts "find #{@remove_from_target_array_1} -type f -exec sed -i ':a;N;$!ba;s@'$(echo \342\206\265)'\\n@@g' {} \\;"
    #puts "#{@remove_from_target_array_1} sed -i ':a;N;$!ba;s@'$(echo \342\206\265)'\\n@@g'"
    #`find #{@remove_from_target_array_1} -type f -exec sed -i ':a;N;$!ba;s@'$(echo "\342\206\265")'\\n@@g' {} \\;`
    #`sed -i ':a;N;$!ba;s@'$(echo "\342\206\265")'\\n@@g' *.html`
    Dir.chdir "#{@remove_from_target_array_1}"
    `sed -i ':a;N;$!ba;s@↵\\n@@g' *.html`
    Dir.chdir "#{@remove_from_target_array_2}"
    `sed -i ':a;N;$!ba;s@↵\\n@@g' *.html`
    Dir.chdir "#{@current_dir}"
    puts " "
	end

	def process_scan_results
		# In here we'll run the processing script on the results, gathering wiki output.
      today = Chronic.parse("today").strftime("%d")
      month = Chronic.parse("today").strftime("%m")
      year =  Chronic.parse("today").strftime("%Y")

      puts "  "
      puts "/**************** Processing to MediaWiki format - Target array 1 ****************/"
      puts `./format_report_for_wiki target_array_1/#{@date_location} #{@current_dir}`
      `mv /tmp/#{today}_#{month}_#{year}.wiki #{@current_dir}/processed_files/target_array_1/#{@date_location}/#{@wiki_name}.wiki`

      puts "  "
      puts "/**************** Processing to MediaWiki format - Target array 2 ****************/"
      puts `./format_report_for_wiki target_array_2/#{@date_location} #{@current_dir}`
      `mv /tmp/#{today}_#{month}_#{year}.wiki #{@current_dir}/processed_files/target_array_2/#{@date_location}/#{@wiki_name}.wiki`
      `find  #{@current_dir}/processed_files/target_array_2/#{@date_location} -maxdepth 1 -type f -name "*.wiki" -exec sed -i '/if IE 6/d' {} \\;`
      `find  #{@current_dir}/processed_files/target_array_1/#{@date_location} -maxdepth 1 -type f -name "*.wiki" -exec sed -i '/if IE 6/d' {} \\;`
      # Update the usable nvt's (scan algorithms)
      `sudo openvas-nvt-sync --wget`
	end

  def run_kismet
    @current_dir = Dir.pwd.strip
    puts "Current directory: #{@current_dir} "
    Dir.chdir "#{@current_dir}/kismet"
    new_dir = Dir.pwd.strip
    puts "Moved to #{new_dir}"
    puts "New dir: #{Dir.pwd.strip}"
    puts "Starting Kismet Server"
    kismet_location = `which kismet_server`.chomp
    puts "kismet location: #{kismet_location}"
    Open3.popen3(kismet_location.to_s)
    #wait for 30 min
    puts "Time started: #{Time.now}"
    puts "Running Kismet..."
    minutes_to_wait = 30
    sleep(minutes_to_wait*60)
    puts "Killing kismet server"
    `killall kismet_server`
    sleep(30)
  end

	def get_kismet_results
    # Kismet puts its results from the current directory.
    # I try to run it from the location of the processing script.
    # The file that's needed for processing is the xml one, filename similar to this: Kismet-20111125-15-28-27-1.netxml
    # Need today's date in order to create the folder for Kismet.
    # Check script location
    location = Dir.pwd.strip
    puts "In #{location}"
    day = Chronic.parse("today").strftime("%d")
    month = Chronic.parse("today").strftime("%B").downcase
    month_number = Chronic.parse("today").strftime("%m")
    year = Chronic.parse("today").strftime("%Y")
    kismet_folder = "#{location}/"
    @kismet_file_name = `find #{kismet_folder.to_s} -maxdepth 1 -mindepth 1 -name '*.netxml'`.strip
    puts "kismet file name: #{@kismet_file_name}"

    # Make the correct directories
    `mkdir -p #{kismet_folder}html_files/#{year}/#{month_number}/#{day}/main_html_file`
    `mkdir -p #{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file`
    # Move the xml file to the html_files/month/day/xml_file directory.
    puts "mv #{@kismet_file_name} #{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml"
    `mv #{@kismet_file_name} #{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml`
    # Update kismet xml output file name
    @kismet_file_name = "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml"
    # Get rid of other Kismet output files - don't need them (only XML file is processed).
    `rm #{kismet_folder}Kismet* `
    # Now need to call the processing script, which will create a whole bunch of files: we however, are only interested
    # in the main html file, which we will grab, store, and then wiki-fy.
    run_script = "#{kismet_folder}klv.pl #{@kismet_file_name}"
    puts run_script
    system(run_script)

    # Now we need to clean up:
    # Move the xml and html file to their right places
    # Get rid of unnecessary log files
    # Run the wiki processing script on the kismet file.
    # Move the html file ready for processing by the HTML2Wiki script.
    `mv #{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml.html #{kismet_folder}html_files/#{year}/#{month_number}/#{day}/main_html_file/Kismet_#{day}_#{month_number}_#{year}.netxml.html`
    # Remove the unecessary clients/info html files, grab html file name for processing.
    `rm #{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml-*`
    @kismet_html_file_name = "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/main_html_file/Kismet_#{day}_#{month_number}_#{year}.netxml.html"
    puts "Kismet file name: #{@kismet_html_file_name}"
    # Run the wiki script.
    wiki_script = "#{kismet_folder}format_kismet_for_wiki #{@kismet_html_file_name} #{kismet_folder}"
    puts "Kismet Processing script: #{wiki_script}"
    system(wiki_script)
    `mkdir -p #{kismet_folder}wiki_files/#{year}/#{month_number}/`
    `mv #{kismet_folder}wiki_files/#{day}_#{month_number}_#{year}.wiki #{kismet_folder}wiki_files/#{year}/#{month_number}/#{day}_#{month_number}_#{year}.wiki`
	end
end

automation = Automate.new
