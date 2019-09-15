#
# Cookbook:: chef_software
# Recipe:: chef_automatev2
#
# Copyright:: 2019, Corey Hemminger
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

chef_automatev2 'Create Automate server' do
  node['chef_software']['chef_automatev2']&.each do |key, value|
    send(key, value)
  end
end

execute 'apply license' do
  command 'chef-automate license apply /opt/support/license/automate2.txt'
  only_if { ::File.exist?('/opt/support/license/automate2.txt') }
  not_if { shell_out("chef-automate license status").stdout.include?('License ID:')}
end

execute 'IAM upgrade to v2' do
  command 'chef-automate iam upgrade-to-v2'
  only_if {node['chef_software']['automate_IAM_version'] == "v2" }
  not_if {shell_out("chef-automate iam version").stdout.include?("V.20")}
  end

execute 'restore admin password after IAM upgrade' do
  command "chef-automate iam admin-access restore #{node['chef_software']['adm_password']}"
  only_if {node['chef_software']['automate_IAM_version'] == "v2" }
  not_if {shell_out("chef-automate iam version").stdout.include?("V.20")}
end


if node['chef_software']['automate_admin_token']
  node['chef_software']['automatev2_local_users']&.each do |name, hash|
    execute "create local user #{name}" do
      command "curl --insecure -H \"api-token: #{node['chef_software']['automate_admin_token']}\" -H \"Content-Type: application/json\" -d '{\"name\":\"#{hash['full_name']}\", \"username\":\"#{name}\", \"password\":\"#{hash['password']}\"}' https://localhost/api/v0/auth/users"
      not_if { shell_out("curl --insecure -H \"api-token: #{node['chef_software']['automate_admin_token']}\" https://localhost/api/v0/auth/users/#{name}").stdout.include?(name) }
      sensitive true
    end
  end

  node['chef_software']['automatev2_iam_policies']&.each do |name, hash|
    execute "generate iam policy #{name}" do
      command "curl --insecure -s -H \"api-token: #{node['chef_software']['automate_admin_token']}\" -H \"Content-Type: application/json\" -d '#{hash['policy_json'].to_json}' https://localhost/api/v0/auth/policies -v"
      not_if { shell_out("curl --insecure -s -H \"api-token: #{node['chef_software']['automate_admin_token']}\" https://localhost/api/v0/auth/policies -v").stdout.include?(hash['policy_json']['subjects'].first) }
      sensitive true
    end
  end
end
