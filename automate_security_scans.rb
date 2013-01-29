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
  require 'csv'
  include FileUtils

  def initialize
    ARGV.map! &:downcase
    if ARGV.include?("openvas")
      check_for_target_config
      if !@skip_config
        setup_target_config
      end
      get_openvas_data
      get_targets_and_names
      give_date_selection
      get_individual_scans
      return_scan_results
      sync_nvt
    elsif ARGV.include?("kismet")
      run_kismet
      get_kismet_results
    end
  end

  def check_for_target_config
    # In here, we'll need to see if the file "network_segments.txt" exists, and read in the contents to create the network segment arrays.
    if !File.exists?("config/")
      FileUtils.mkdir_p "config"
    end
    if File.exists?("config/network_segments.txt")
      @overall_segments = []
      CSV.foreach("config/network_segments.txt") do |csv|
        @overall_segments << csv
      end
      @skip_config = true
    else
      @skip_config = false
    end
  end

  def setup_target_config
    puts "Please enter number of network segments. If you have only one (or just want all results), hit enter:"
    @network_segments = STDIN.gets.chomp
    if !@network_segments.empty?
      # We have more than one segment. We need to initialise the correct number of arrays and gather in the names for each segment.
      @overall_segment_data = []
      @network_segments.to_i.times do |segment|
        puts " "
        puts "*************************** "
        puts "Please enter a name for this network segment (if none given, name will be 'network_segment_#{segment + 1}'):"
        name = STDIN.gets.chomp
        if name.nil?
          name = (segment +1)
        end
        name.downcase!
        name.gsub!(' ', '_')
        puts " "
        puts "*************************** "
        puts "Please enter the scan target names as they appear when running omp -G for network segment #{name}, with each name separated by a space:"
        @targets = []
        # Grab user input for target names, push the name of segment into the
        # first element.
        @targets = STDIN.gets.chomp.split(' ').unshift(name)
        # Flatten to string
        @targets.flatten!
        # Add string to array.
        @overall_segment_data << @targets
      end
    else
      @one_segment = true
      @single_segment_data = []
      # We should store that there is one segment, but not bother initialising arrays
      puts " "
      puts "*************************** "
      puts "Please enter a name for this network segment (if none given, name will be 'network_segment_1'):"
      name = ""
      name = STDIN.gets.chomp
      if name.length == 0
        puts "NAME IS EMPTY"
        name = "network_segment_1"
      else
        puts "Name is: #{name}"
        name.downcase!
        name.gsub!(' ', '_')
      end

      puts " "
      puts "*************************** "
      puts "Please enter the scan target names as they appear when running omp -G, with each name separated by a space:"
      @single_segment_data << STDIN.gets.chomp.split(' ').unshift(name)
    end
    # Create a new file and write to it
    CSV.open("#{Dir.pwd}/config/network_segments.txt", "w") do |csv|
      if @one_segment
        csv << @single_segment_data.flatten
      else
        @overall_segment_data.each do |segment_data|
            csv << segment_data
        end
      end
    end
    check_for_target_config
  end

  def get_user_date(date_entered)
    @user_day = date_entered[2].to_i
    @user_month = date_entered[1].to_i
    @user_year = date_entered[0].to_i

    # This needs to be examined - this should be stored as a config option!
    # Set up the date params for grabbing the scans from other time periods
    @other_scan_day = Chronic.parse('next Monday', :now => Time.parse("#{@user_year}-#{@user_month}-#{@user_day}")).strftime("%d")
    @other_scan_month = Chronic.parse('next Monday', :now => Time.parse("#{@user_year}-#{@user_month}-#{@user_day}")).strftime("%m")
    @other_scan_year = Chronic.parse('next Monday', :now => Time.parse("#{@user_year}-#{@user_month}-#{@user_day}")).strftime("%Y")
  end

  def get_openvas_data
    @list_targets = `omp -G`
    @target_ids = Array.new
    @output_html_name = Array.new
    @reports_list = Array.new
    @user_date = ""
    # id for HTML output
    omp_formats = `omp -F`.split("\n").collect! {|n| n.to_s}
    @html_id = omp_formats[1].split.first

    # Get directory for this script
    @current_dir = Dir.pwd.strip

    # Get date
    @year = Chronic.parse("last Saturday").strftime("%Y").to_i
    @month = Chronic.parse("last Saturday").strftime("%B").downcase
    @month_number = Chronic.parse("last Saturday").strftime("%m").to_i
    @day = Chronic.parse("last Saturday").strftime("%d").to_i
    @scan_date = "#{@day}_#{@month}_#{@year}"
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
      @output_html_name << target_details.last.to_s
    end
  end

  def give_date_selection
    # In here, we'll give the user a numerical choice to select one from the
    # last five dates, or input a date of their own.
    system("clear")
    puts "/**************** Scan Dates ****************/"
    @overall_dates = []
    # We need to find the latest date from *all* the targets.
    @target_ids.each do |target|
      report = `omp -G #{target}`.split("\n").collect! {|n| n.to_s}
      # Get rid of the first element - it contains the target details (not a report)
      @name_of_target = report.shift.to_s.split
      # Iterate through the individual reports (for a specific target)
      report.each do |individual_reports|
        # Get each report to analyse against user date.
        selected_report = individual_reports.to_s.split
        # The report dates are formatted like this: 2012-12-22T09:00:13Z. We need to parse this!
        report_date = selected_report[6].split("T").first.split("-")
        # We now have the date (yyyy-mm-dd) to use.
        report_day = report_date[2]
        report_month = report_date[1]
        report_year = report_date[0]
        if !@overall_dates.include?("#{report_year}/#{report_month}/#{report_day}")
          # Only gather dates if they are Saturdays
          if Time.parse("#{report_year}/#{report_month}/#{report_day}").saturday?
            @overall_dates << "#{report_year}/#{report_month}/#{report_day}"
          end
        end
      end
    end
    @overall_dates.sort!
    @overall_dates.uniq!
    @overall_dates.reverse!

    @dates_list = @overall_dates.take 5
    # We now give the user the choice of the last 5 scan dates.
    @dates_list.each_with_index do |date, index|
      correctly_formatted_date = date.split("/").reverse
      puts "#{index +1}. #{correctly_formatted_date[0]}/#{correctly_formatted_date[1]}/#{correctly_formatted_date[2]}"
    end
    puts "NOTE: Some targets may not have any results for a given date, and as such, will not show any results."
    puts " "
    puts "Enter number for date, 'D' to enter a date, or 'A' to see all dates:"
    date = STDIN.gets.chomp.downcase
    if date == "d"
      puts "Please enter date in the form dd/mm/yyyy:"
      entered_date = STDIN.gets.chomp.split("/")
      get_user_date(entered_date)
    elsif date == "a"
      # View all dates!
      system("clear")
      @overall_dates.each_with_index do |date,index|
        puts "#{index+1}. #{date}"
      end
      puts "Please enter the number of a date from the list:"
      entered_date = STDIN.gets.chomp
      system("clear")
      puts "Date selected: #{@overall_dates[entered_date.to_i]}"
      puts " "
      get_user_date(@overall_dates[entered_date.to_i].split("/"))
    else
      # We have a selected date.
      get_user_date(@dates_list[date.to_i-1].split("/"))
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
      # Get rid of the first element - it contains the target details (not a report)
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
    puts " "
    puts "Running sed commands..."
    @overall_segments.each do |segment|
      @gathered_reports.each_pair do |key, value|
        # Set up network location for html file output
        if segment.include?(key)
          network_segment = segment.first
          @html_file_path = "#{@current_dir}/html_files/#{network_segment}/#{@date_location}"
          @wiki_file_path = "#{@current_dir}/processed_files/#{network_segment}/#{@date_location}"

          # Create the HTML file storage structure.
          if !File.exists?(@html_file_path)
            FileUtils.mkdir_p "#{@html_file_path}"
          end

          # Create the wiki file storage structure.
          if !File.exists?(@wiki_file_path)
            FileUtils.mkdir_p "#{@wiki_file_path}"
          end

          # Get HTML formatted output files from openVAS.
          `omp --get-report #{value} --format #{@html_id} > #{@html_file_path}/#{key}_#{@scan_date}.html`
          i = i + 1
          #puts "find #{@remove_from_target_array_1} -type f -exec sed -i ':a;N;$!ba;s@'$(echo \342\206\265)'\\n@@g' {} \\;"
          #puts "#{@remove_from_target_array_1} sed -i ':a;N;$!ba;s@'$(echo \342\206\265)'\\n@@g'"
          #`find #{@remove_from_target_array_1} -type f -exec sed -i ':a;N;$!ba;s@'$(echo "\342\206\265")'\\n@@g' {} \\;`
          #`sed -i ':a;N;$!ba;s@'$(echo "\342\206\265")'\\n@@g' *.html`

          #Clean up the files
          Dir.chdir "#{@html_file_path}"
          `sed -i ':a;N;$!ba;s@↵\\n@@g' *.html`
          # We need to process the scan results.
          process_scan_results(network_segment)
          puts "Processed: #{key} (#{value})"
        end
      end
    end
    puts " "
    puts "'sed' commands completed successfully."
  end

  def process_scan_results(network_segment)
    # Change back the 'home' DIR for the script
    Dir.chdir "#{@current_dir}"
    puts " "

    # In here we'll run the processing script on the results, gathering wiki output.
    today = Chronic.parse("today").strftime("%d")
    month = Chronic.parse("today").strftime("%m")
    year =  Chronic.parse("today").strftime("%Y")

    `./format_report_for_wiki "html_files/#{network_segment}/#{@date_location}" #{@current_dir} #{@date_location}`
    FileUtils.mv "/tmp/#{today}_#{month}_#{year}.wiki", "#{@current_dir}/processed_files/#{network_segment}/#{@date_location}/#{@wiki_name}.wiki"

    # Find all the wiki files and remove lines concerning IE 6.
    `find  #{@current_dir}/processed_files/#{network_segment}/#{@date_location} -maxdepth 1 -type f -name "*.wiki" -exec sed -i '/if IE 6/d' {} \\;`
  end

  def sync_nvt
    # Update the usable nvt's (scan algorithms)
    puts " "
    puts "Update NVT feed:"
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
    FileUtils.mkdir_p "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/main_html_file"
    FileUtils.mkdir_p "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file"
    # Move the xml file to the html_files/month/day/xml_file directory.
    puts "Move #{@kismet_file_name} to #{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml"
    FileUtils.mv "#{@kismet_file_name}", "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml"
    # Update kismet xml output file name
    @kismet_file_name = "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml"
    # Get rid of other Kismet output files - don't need them (only XML file is processed).
    FileUtils.rm "#{kismet_folder}Kismet*"
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
    FileUtils.mv "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml.html", "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/main_html_file/Kismet_#{day}_#{month_number}_#{year}.netxml.html"
    # Remove the unecessary clients/info html files, grab html file name for processing.
    FileUtils.rm "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/xml_file/Kismet_#{day}_#{month_number}_#{year}.netxml-*"
    @kismet_html_file_name = "#{kismet_folder}html_files/#{year}/#{month_number}/#{day}/main_html_file/Kismet_#{day}_#{month_number}_#{year}.netxml.html"
    puts "Kismet file name: #{@kismet_html_file_name}"
    # Run the wiki script.
    wiki_script = "#{kismet_folder}format_kismet_for_wiki #{@kismet_html_file_name} #{kismet_folder}"
    puts "Kismet Processing script: #{wiki_script}"
    system(wiki_script)
    FileUtils.mkdir_p "#{kismet_folder}wiki_files/#{year}/#{month_number}/"
    FileUtils.mv "#{kismet_folder}wiki_files/#{day}_#{month_number}_#{year}.wiki", "#{kismet_folder}wiki_files/#{year}/#{month_number}/#{day}_#{month_number}_#{year}.wiki"
  end
end

automation = Automate.new
