# Copyright 2019 Google Inc. All rights reserved.
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

require 'json'
require 'open-uri'

require 'fluent/plugin/filter'
require "google/cloud/dlp"

module Fluent::Plugin
  class GcpDlpFilter < Fluent::Plugin::Filter

    module InternalConstants
      CREDENTIALS_PATH_ENV_VAR = 'GOOGLE_APPLICATION_CREDENTIALS'.freeze
      CLOUDPLATFORM_SCOPE = 'https://www.googleapis.com/auth/cloud-platform'.freeze
      METADATA_SERVICE_ADDR = '169.254.169.254'.freeze
      GOOGLE_CREDENTIAL_FILE = '/etc/google/auth/application_default_credentials.json'.freeze      
    end
    
    include self::InternalConstants

    Fluent::Plugin.register_filter('gcp_dlp', self)

    PLUGIN_NAME = 'Fluentd Google Cloud Data Loss Prevention plugin'.freeze

    module Platform
      OTHER = 0  # Other/unkown platform
      GCE = 1    # Google Compute Engine
      EC2 = 2    # Amazon EC2
      AZURE = 3  # Azure
    end

    module CredentialsInfo
      def self.project_id
        creds = Google::Auth.get_application_default(InternalConstants::CLOUDPLATFORM_SCOPE)
        if creds.respond_to?(:project_id)
          return creds.project_id if creds.project_id
        end
        if creds.issuer
          id = extract_project_id(creds.issuer)
          return id unless id.nil?
        end
        if creds.client_id
          id = extract_project_id(creds.client_id)
          return id unless id.nil?
        end
        nil
      end

      def self.extract_project_id(str)
        [/^.*@(?<project_id>.+)\.iam\.gserviceaccount\.com/,
         /^(?<project_id>\d+)-/].each do |exp|
          match_data = exp.match(str)
          return match_data['project_id'] unless match_data.nil?
        end
        nil
      end
    end

    def fetch_gce_metadata(metadata_path)
      raise "Called fetch_gce_metadata with platform=#{@platform}" unless
        @platform == Platform::GCE
      open('http://' + METADATA_SERVICE_ADDR + '/computeMetadata/v1/' +
           metadata_path, 'Metadata-Flavor' => 'Google', &:read)
    end    

    def detect_platform
      unless @use_metadata_service
        @log.info 'use_metadata_service is false; not detecting platform'
        return Platform::OTHER
      end

      begin
        open('http://' + METADATA_SERVICE_ADDR) do |f|
          if f.meta['metadata-flavor'] == 'Google'
            @log.info 'Detected GCE platform'
            return Platform::GCE
          end
          if f.meta['server'] == 'EC2ws'
            @log.info 'Detected EC2 platform'
            return Platform::EC2
          end
        end
      rescue OpenURI::HTTPError => error
        response = error.io
        if response.meta['server'] == 'Microsoft-IIS/10.0'
          @log.info 'Detected Azure platform'
          return Platform::AZURE
        end
      rescue StandardError => e
        @log.error 'Failed to access metadata service: ', error: e
      end

      @log.info 'Unable to determine platform'
      Platform::OTHER
    end

    config_param :info_types, :array, value_type: :string
    config_param :use_metadata_service, :bool, :default => false
    config_param :google_credential_file, :string, :default => nil
    config_param :project_id, :string, :default => nil

    dlp = nil

    def initialize
      super
      @log = $log
    end

    def configure(conf={})
      super

      ENV.delete(CREDENTIALS_PATH_ENV_VAR) if
        ENV[CREDENTIALS_PATH_ENV_VAR] == '' 
      ENV[CREDENTIALS_PATH_ENV_VAR] = google_credential_file if google_credential_file

    end

    def set_project_id
      @project_id ||= CredentialsInfo.project_id
      @project_id ||= fetch_gce_metadata('project/project-id') if
        @platform == Platform::GCE
    end    

    def start
      super
      @platform = detect_platform
      set_project_id
      @dlp = Google::Cloud::Dlp.new      
    end

    def shutdown
      super
    end

    def filter(tag, time, record)

      selected_info_types = []
      info_types.each {|i| selected_info_types.push({name: i} ) }

      inspect_config = {
        info_types: selected_info_types,
      }

      deidentify_config = {
        info_type_transformations:{
          transformations: [
            {
              primitive_transformation: {
                replace_with_info_type_config: {},
              },
            },
          ],
        }
      }

      begin
        rows_to_inspect = []
        record.each { |k,v|
          rows_to_inspect.push({ values: [ { string_value: v} ]})
        }

        item_to_inspect = { table: {
            headers: [ { name: record.hash.to_s } ],
            rows: rows_to_inspect,
          },
        }
        
        parent = "projects/#{project_id}"
        response = @dlp.deidentify_content parent,
          inspect_config: inspect_config,
          deidentify_config: deidentify_config,
          item:  item_to_inspect

        @log.debug response.inspect

        # DLP sends back the rows and values in the order it got them
        # this means we can aquire the ordinal values predictably (eg[0])
        i = 0
        record.each { |k,v|
          record[k] = response.item.table.rows[i].values[0].string_value
          i += 1
        }
      
      rescue StandardError => e
        @log.error "Error: ", error: e
        return nil    
      end    
      record     
    end
  end
end