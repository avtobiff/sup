#!/usr/bin/ruby

require 'test/unit'
require 'sup'
require 'stringio'

include Redwood

class TestMBoxParsing < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  def test_normal_headers
    h = Source.parse_raw_email_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>
To: Sally <sally@sally.com>
EOS

    assert_equal "Bob <bob@bob.com>", h["from"]
    assert_equal "Sally <sally@sally.com>", h["to"]
    assert_nil h["message-id"]
  end

  def test_multiline
    h = Source.parse_raw_email_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>
Subject: one two three
  four five six
To: Sally <sally@sally.com>
References: <seven>
  <eight>
Seven: Eight
EOS

    assert_equal "one two three four five six", h["subject"]
    assert_equal "Sally <sally@sally.com>", h["to"]
    assert_equal "<seven> <eight>", h["references"]
  end

  def test_ignore_spacing
    variants = [
      "Subject:one two  three   end\n",
      "Subject:    one two  three   end\n",
      "Subject:   one two  three   end    \n",
    ]
    variants.each do |s|
      h = Source.parse_raw_email_header StringIO.new(s)
      assert_equal "one two  three   end", h["subject"]
    end
  end

  def test_message_id_ignore_spacing
    variants = [
      "Message-Id:     <one@bob.com>       \n",
      "Message-Id:<one@bob.com>       \n",
    ]
    variants.each do |s|
      h = Source.parse_raw_email_header StringIO.new(s)
      assert_equal "<one@bob.com>", h["message-id"]
    end
  end

  def test_blank_lines
    h = Source.parse_raw_email_header StringIO.new("")
    assert_equal nil, h["message-id"]
  end

  def test_empty_headers
    variants = [
      "Message-Id:       \n",
      "Message-Id:\n",
    ]
    variants.each do |s|
      h = Source.parse_raw_email_header StringIO.new(s)
      assert_equal "", h["message-id"]
    end
  end

  def test_detect_end_of_headers
    h = Source.parse_raw_email_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>

To: a dear friend
EOS
  assert_equal "Bob <bob@bob.com>", h["from"]
  assert_nil h["to"]

  h = Source.parse_raw_email_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>
\r
To: a dear friend
EOS
  assert_equal "Bob <bob@bob.com>", h["from"]
  assert_nil h["to"]

  h = Source.parse_raw_email_header StringIO.new(<<EOS)
From: Bob <bob@bob.com>
\r\n\r
To: a dear friend
EOS
  assert_equal "Bob <bob@bob.com>", h["from"]
  assert_nil h["to"]
  end

  def test_from_line_splitting
    l = MBox.new StringIO.new(<<EOS)
From sup-talk-bounces@rubyforge.org Mon Apr 27 12:56:18 2009
From: Bob <bob@bob.com>
To: a dear friend

Hello there friend. How are you?

From sea to shining sea

From bob@bob.com I get only spam.

From bob@bob.com

From bob@bob.com

(that second one has spaces at the endj

This is the end of the email.
EOS
    offset, labels = l.next
    assert_equal 0, offset
    offset, labels = l.next
    assert_nil offset
  end

  def test_more_from_line_splitting
    l = MBox.new StringIO.new(<<EOS)
From sup-talk-bounces@rubyforge.org Mon Apr 27 12:56:18 2009
From: Bob <bob@bob.com>
To: a dear friend

Hello there friend. How are you?

From bob@bob.com Mon Apr 27 12:56:19 2009
From: Bob <bob@bob.com>
To: a dear friend

Hello again! Would you like to buy my products?
EOS
    offset, labels = l.next
    assert_not_nil offset

    offset, labels = l.next
    assert_not_nil offset

    offset, labels = l.next
    assert_nil offset
  end
end
