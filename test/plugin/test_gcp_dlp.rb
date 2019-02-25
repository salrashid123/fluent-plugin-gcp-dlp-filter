
require "test-unit"
require "fluent/test"
require 'fluent/test/driver/output'
require "fluent/test/helpers"

require_relative '../../lib/fluent/plugin/filter_gcp_dlp'
require_relative '../helper'

class GcpDlpFilterTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    info_types ALL_BASIC
    google_credential_file /path/to/your/local/application_default_credentials.json
    use_metadata_service false
  ]

  DEIDENTIFY_CONFIG_EMAIL = %[
    info_types EMAIL_ADDRESS
    google_credential_file /path/to/your/local/application_default_credentials.json
    use_metadata_service false
  ]

  DEIDENTIFY_CONFIG_EMAIL_SSN = %[
    info_types EMAIL_ADDRESS,US_SOCIAL_SECURITY_NUMBER
    google_credential_file /path/to/your/local/application_default_credentials.json
    use_metadata_service false
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::GcpDlpFilter).configure(conf)
  end

  test 'configure' do
    d = create_driver(CONFIG)
    assert_equal ['ALL_BASIC'], d.instance.info_types
  end

  test 'deidentify_email' do
    d = create_driver(DEIDENTIFY_CONFIG_EMAIL)
    record = {
      "key1": "hi sal, your email is sal@domain.com",
      "key2": "hi sal",
    }
    d.run(default_tag: "test") do
     d.feed(record)
    end

    filtered_records = d.filtered_records
    assert_equal(1, filtered_records.size)
    record = filtered_records[0]
    assert_equal 'hi sal, your email is [EMAIL_ADDRESS]', record["key1".to_sym]
    assert_equal 'hi sal', record["key2".to_sym]
  end

  test 'deidentify_email_ssn' do
    d = create_driver(DEIDENTIFY_CONFIG_EMAIL_SSN)
    record = {
      "key1": "hi sal, your email is sal@domain.com and ssn is 223-22-2222",
    }
    d.run(default_tag: "test") do
     d.feed(record)
    end

    filtered_records = d.filtered_records
    assert_equal(1, filtered_records.size)
    record = filtered_records[0]
    assert_equal 'hi sal, your email is [EMAIL_ADDRESS] and ssn is [US_SOCIAL_SECURITY_NUMBER]', record["key1".to_sym]

  end

end