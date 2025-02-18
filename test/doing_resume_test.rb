require 'fileutils'
require 'tempfile'
require 'time'

require 'doing-helpers'
require 'test_helper'

# Tests for entry modifying commands
class DoingResumeTest < Test::Unit::TestCase
  include DoingHelpers
  ENTRY_TS_REGEX = /\s*(?<ts>[^|]+) \s*\|/.freeze
  ENTRY_DONE_REGEX = /@done\((?<ts>.*?)\)/.freeze

  def setup
    @tmpdirs = []
    @result = ''
    @basedir = mktmpdir
    @wwid_file = File.join(@basedir, 'wwid.md')
    @config_file = File.join(File.dirname(__FILE__), 'test.doingrc')
  end

  def teardown
    FileUtils.rm_rf(@tmpdirs)
  end

  def test_resume_task
    subject = 'Test task'
    doing('done', subject)
    result = doing('--stdout', 'again')

    assert_match(/Added "#{subject}" to Currently/, result, 'Task should be added again')
  end

  def test_resume_tag
    3.times { |i| doing('done', '--back', "#{i+5}m", "Task #{i + 1} with @tag#{i + 1}") }
    result = doing('--stdout', 'again', '--tag', 'tag2')
    assert_match(/Added \"Task 2 with @tag2\"/, result, 'Task 2 should be repeated')

    result = doing('last').uncolor.strip

    assert_match(/Task 2 with @tag2/, result, 'Task 2 should be added again')
    assert_no_match(ENTRY_DONE_REGEX, result, 'Task 2 should not be @done')
  end

  def test_finish_and_resume
    doing('now', '--back', '5m', 'Task 4 with @tag4')
    doing('again')
    result = doing('show', '@done').uncolor.strip
    assert_match(/Task 4 with @tag4 @done/, result, 'Task 4 should be completed')
    result = doing('last').uncolor.strip
    assert_no_match(ENTRY_DONE_REGEX, result, 'New Task 4 should not be @done')
  end

  private

  def mktmpdir
    tmpdir = Dir.mktmpdir
    @tmpdirs.push(tmpdir)

    tmpdir
  end

  def doing(*args)
    doing_with_env({}, '--config_file', @config_file, '--doing_file', @wwid_file, *args)
  end
end

