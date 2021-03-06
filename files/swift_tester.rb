#!/usr/bin/env ruby
#
# This is a script that uses
# instructions here: https://docs.openstack.org/swift/latest/howto_installmultinode.html
# Even though I expect this script will work with a wide range
# of swift versions, it is currently only tested with: 1.4.6
require 'open3'
require 'fileutils'

# connection variables
proxy_local_net_ip='127.0.0.1'
user='test:tester'
password='testing'

# headers for curl requests
user_header="-H 'X-Storage-User: #{user}'"
password_header="-H 'X-Storage-Pass: #{password}'"
get_cred_command="curl -k -v #{user_header} #{password_header} http://#{proxy_local_net_ip}:8080/auth/v1.0"

# verify that we can retrieve credentials from our user
result_hash = {}
puts "getting credentials: #{get_cred_command}"
Open3.popen3(get_cred_command) do |stdin, stdout, stderr|
  result_hash[:stderr] = stderr.read
  result_hash[:stderr].split("\n").each do |line|
    if line =~ /^< HTTP\/\d\.\d (\d\d\d)/
      result_hash[:status_code]=$1
    end
    if line =~ /< X-Storage-Url: (http\S+)/
      result_hash[:auth_url]=$1
    end
    if line =~ /< X-Storage-Token: (AUTH_\S+)/
      result_hash[:auth_token]=$1
    end
  end
end
raise(Exception, "Call to get auth tokens failed:\n#{result_hash[:stderr]}") unless result_hash[:status_code] == '200'

# verify that the credentials are valid
auth_token_header="-H 'X-Auth-Token: #{result_hash[:auth_token]}'"
get_account_head="curl -k -v #{auth_token_header} #{result_hash[:auth_url]}"
# what is the expected code?
puts "verifying connection auth: #{get_account_head}"
Open3.popen3(get_account_head) do |stdin, stdout, stderr|
  #puts stdout.read
  #puts stderr.read
end


proxy_local_net_ip='127.0.0.1'
user='test:tester'
password='testing'
swift_command_prefix="swift -A http://#{proxy_local_net_ip}:8080/auth/v1.0 -U #{user} -K #{password}"

swift_test_command="#{swift_command_prefix} stat"

puts "Testing swift: #{swift_test_command}"
status_hash={}
Open3.popen3(swift_test_command) do |stdin, stdout, stderr|
  status_hash[:stdout] = stdout.read
  status_hash[:stderr] = stderr.read
  status_hash[:stdout].split("\n").each do |line|
    if line =~ /\s*Containers:\s+(\d+)/
      status_hash[:containers] = $1
    end
    if line =~ /\s*Objects:\s+(\d+)/
      status_hash[:objects] = $1
    end
  end
end

unless(status_hash[:containers] =~ /\d+/ and status_hash[:objects] =~ /\d+/)
  raise(Exception, "Expected to find the number of containers/objects:\n#{status_hash[:stdout]}\n#{status_hash[:stderr]}")
else
  puts "found containers/objects: #{status_hash[:containers]}/#{status_hash[:objects]}"
end

# test that we can upload something
File.open('/tmp/foo1', 'w') do |fh|
  fh.write('test1')
end

container = 'my_container'

swift_upload_command="#{swift_command_prefix} upload #{container} /tmp/foo1"
puts "Uploading file to swift with command: #{swift_upload_command}"

Open3.popen3(swift_upload_command) do |stdin, stdout, stderr|
  puts stdout.read
  puts stderr.read
end

# test that we can download the thing that we uploaded
download_test_dir = '/tmp/test/downloadtest/'
FileUtils.rm_rf download_test_dir
FileUtils.mkdir_p download_test_dir

swift_download_command="#{swift_command_prefix} download #{container}"
puts "Downloading file with command: #{swift_download_command}"
Dir.chdir(download_test_dir) do
  Open3.popen3(swift_download_command) do |stdin, stdout, stderr|
    puts stdout.read
    puts stderr.read
  end
end

expected_file = File.join(download_test_dir, 'tmp', 'foo1')

if File.exists?(expected_file)
  if File.read(expected_file) == 'test1'
    puts "Dude!!!! It actually seems to work, we can upload and download files!!!!"
  else
    raise(Exception, "So close, but the contents of the downloaded file are not what I expected: Got: #{File.read(expected_file)}, expected: test1")
  end
else
  raise(Exception, "file #{expected_file} did not exist somehow, probably b/c swift is not installed correctly")
end

