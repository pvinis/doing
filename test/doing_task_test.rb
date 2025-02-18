require 'fileutils'
require 'tempfile'
require 'time'

require 'doing-helpers'
require 'test_helper'

# Tests for entry modifying commands
class DoingTaskTest < Test::Unit::TestCase
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

  def test_new_task
    # Add a task
    subject = 'Test new task @tag1'
    doing('now', subject)
    assert_match(/#{subject}\s*$/, doing('show', '-c 1'), 'should have added task')
  end

  def test_new_task_finishing_last
    subject = 'Test new task'
    subject2 = 'Another task'
    doing('now', subject)
    doing('now', '--finish_last', subject2)
    assert_matches([
      [/#{subject} @done/, 'First task should be @done'],
      [/#{subject2}\s*$/, 'Second task should be added']
    ], doing('show'))
  end

  def test_section_rejects_empty_args
    assert_raises(RuntimeError) { doing('now', '--section') }
  end

  def test_add_section
    doing('add_section', 'Test Section')
    assert_match(/^Test Section$/, doing('sections', '-c'), 'should have added section')
  end

  def test_add_to_section
    section = 'Test Section'
    subject = 'Test task @testtag'
    doing('add_section', section)
    doing('now', '--section', section, subject)
    assert_match(/#{subject}/, doing('show', section), 'Task should exist in new section')
  end

  def test_done_task
    subject = 'Test finished task @tag1'
    now = Time.now.round_time(1)
    doing('done', subject)
    r = doing('show').uncolor.strip
    t = r.match(ENTRY_TS_REGEX)
    d = r.match(ENTRY_DONE_REGEX)

    assert(d, "#{r} should have @done tag with timestamp")

    assert_equal(t['ts'], d['ts'], 'Timestamp and @done timestamp should match')
    assert_equal(Time.parse(d['ts']).round_time(1), now,
                 'Finished time should be equal to the nearest minute')
  end

  def test_finish_task
    subject = 'Test new task @tag1'
    doing('now', subject)
    doing('finish')
    r = doing('show').uncolor.strip
    m = r.match(ENTRY_DONE_REGEX)
    assert(m, "#{r} should have @done timestamp")
    now = Time.now.round_time(1)
    assert_equal(Time.parse(m['ts']).round_time(1), now,
                 'Finished time should be equal to the nearest minute')
  end

  def test_finish_tag
    doing('now', 'Test new task @tag1')
    doing('now', 'Another new task @tag2')
    doing('finish', '--tag', 'tag1')
    t1 = doing('show', '@tag1').uncolor.strip
    assert_match(ENTRY_DONE_REGEX, t1, "@tag1 task should have @done timestamp")
    t2 = doing('show', '@tag2').uncolor.strip
    assert_no_match(ENTRY_DONE_REGEX, t2, "@tag2 task should not have @done timestamp")
  end

  def test_later_task
    subject = 'Test later task'
    result = doing('--stdout', 'later', subject)
    assert_matches([
      [/Added section "Later"/, 'should have added Later section'],
      [/Added "#{subject}" to Later/, 'should have added task to Later section']
    ], result)
    assert_equal(1, doing('show', 'later').uncolor.strip.split("\n").count, 'Later section should have 1 entry')
  end

  def test_cancel_task
    doing('now', 'Test task')
    doing('cancel')
    assert_match(/@done$/, doing('show'), 'should have @done tag with no timestamp')
  end

  def test_archive_task
    subject = 'Test task'
    doing('done', subject)
    result = doing('--stdout', 'archive')

    assert_match(/Added section "Archive"/, result, 'Archive section should have been added')
    assert_match(/#{subject}/, doing('show', 'Archive'), 'Archive section should contain test task')
  end

  def test_archive_by_search
    subject = 'Test task'
    prefixes = %w[consuming eating]
    search_terms = %w[bagels bacon eggs brunch breakfast lunch]
    search_terms.each do |food|
      prefixes.each do |prefix|
        doing('done', "#{prefix.capitalize} @#{food}")
      end
    end

    result = doing('--stdout', 'archive', '--search', '/consuming.*?bagels/')

    assert_match(/Added section "Archive"/, result, 'Archive section should have been added')
    assert_match(/Archived 1 items from Currently to Archive/, result, '1 item should have been archived')
    assert_match(/consuming @bagels/i, doing('show', 'Archive'), 'Archive section should contain test entry')

    result = doing('--stdout', 'archive', '--search', 'eating')
    assert_match(/Archived 6 items from Currently to Archive/, result, '6 items should have been archived')
  end

  private

  def assert_matches(matches, shown)
    matches.each do |regexp, msg, opt_refute|
      if opt_refute
        assert_no_match(regexp, shown, msg)
      else
        assert_match(regexp, shown, msg)
      end
    end
  end

  def mktmpdir
    tmpdir = Dir.mktmpdir
    @tmpdirs.push(tmpdir)

    tmpdir
  end

  def doing(*args)
    doing_with_env({}, '--config_file', @config_file, '--doing_file', @wwid_file, *args)
  end
end

