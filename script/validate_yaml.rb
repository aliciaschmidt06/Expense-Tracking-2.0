#!/usr/bin/env ruby
# script/validate_yaml.rb
# Usage: ruby script/validate_yaml.rb path/to/config.yaml
# Attempts to parse YAML with Psych.safe_load and prints a helpful context if a Psych::SyntaxError occurs.

require 'yaml'

if ARGV.empty?
  puts "Usage: ruby script/validate_yaml.rb PATH_TO_YAML"
  exit 1
end

path = ARGV[0]
unless File.exist?(path)
  puts "File not found: #{path}"
  exit 2
end

text = File.read(path)
lines = text.lines

begin
  YAML.safe_load(text)
  puts "YAML parsed successfully: #{path}"
  exit 0
rescue Psych::SyntaxError => e
  puts "YAML Syntax Error: #{e.message}"
  lineno = nil
  col = nil

  if e.respond_to?(:line) && e.line && e.line > 0
    lineno = e.line
    col = e.column if e.respond_to?(:column)
  else
    # try to extract from message
    m = e.message.match(/line\s*(\d+).*column\s*(\d+)/i) || e.message.match(/at line (\d+) column (\d+)/i)
    if m
      lineno = m[1].to_i
      col = m[2].to_i
    end
  end

  if lineno
    start_line = [1, lineno - 3].max
    end_line = [lines.size, lineno + 3].min
    puts "\nContext (lines #{start_line}-#{end_line}):\n\n"
    (start_line..end_line).each do |i|
      prefix = i == lineno ? '>>' : '  '
      line_text = lines[i-1].rstrip
      puts sprintf("%s %4d | %s", prefix, i, line_text)
      if i == lineno && col && col > 0
        # print caret under the column (account for multibyte chars)
        caret_pos = [col - 1, line_text.length].min
        caret = ' ' * (6 + 5 + caret_pos) + '^' # 6 for prefix and space, 5 for digits/pipes
        # simpler: show indicator under the text portion
        puts ' ' * 9 + ' ' * (caret_pos) + '^'
      end
    end
  else
    puts "Could not determine exact line/column from parser error. Here are the first 40 lines for inspection:\n\n"
    puts lines.first(40).map.with_index(1) { |l,i| sprintf('%4d | %s', i, l.rstrip) }.join("\n")
  end

  puts "\nTips:\n - YAML is sensitive to indentation and list items must start with a leading '-'\n - Look for a mapping that should contain a list (e.g. 'keywords:') but its items are not prefixed with '-'\n - Ensure you use spaces (not tabs) for indentation\n - Check for stray characters or unclosed brackets/quotes on previous lines\n"
  exit 3
rescue StandardError => e
  puts "Unexpected error while parsing YAML: #{e.class} - #{e.message}"
  puts e.backtrace.first(10)
  exit 4
end
