# frozen_string_literal: true

module Ruly
  module Checks
    # Validates that markdown anchor links don't reference headers that exist multiple times
    # This prevents ambiguous references after squashing multiple files together
    class AmbiguousLinks < Base
      class << self
        def call(local_sources, command_files = [])
          anchor_occurrences = build_anchor_map(local_sources, command_files)
          all_links = extract_all_links(local_sources, command_files)
          ambiguous_anchors = find_ambiguous_anchors(anchor_occurrences)
          ambiguous_links = find_ambiguous_links(all_links, ambiguous_anchors)

          errors = ambiguous_links.map do |link|
            {
              link:,
              message: "[#{link[:text]}](##{link[:anchor]})",
              occurrences: ambiguous_anchors[link[:anchor]]
            }
          end

          result = build_result(errors:)
          report(result) unless result[:passed]
          result
        end

        private

        def report(result)
          puts "\n⚠️  CRITICAL: Ambiguous markdown link references detected!"
          puts '   These links point to anchors that exist multiple times in the output.'
          puts '   After squashing, these links may not resolve to the intended target.'
          puts ''

          result[:errors].each do |error|
            puts "   ❌ #{error[:message]}"
            puts "      └─ in #{error[:link][:source]}:#{error[:link][:line]}"
            puts '      └─ This anchor exists in multiple locations:'
            error[:occurrences].each do |occurrence|
              puts "         • #{occurrence[:source]}:#{occurrence[:line]} - \"#{occurrence[:text]}\""
            end
            puts ''
          end

          puts '   💡 Fix: Use unique section names, or reference with more specific anchors.'
          puts '   💡 See [CRITICAL: Never Reference Filenames in Rules] in CLAUDE.md'
          puts ''
        end

        def build_anchor_map(local_sources, command_files)
          anchor_occurrences = Hash.new { |h, k| h[k] = [] }

          process_sources(local_sources, anchor_occurrences)
          process_sources(command_files, anchor_occurrences)

          anchor_occurrences
        end

        def process_sources(sources, anchor_occurrences)
          sources.each do |source|
            content = source[:content].dup.force_encoding('UTF-8')
            path = source[:path]

            content.each_line.with_index do |line, line_num|
              next unless line =~ /^(#+)\s+(.+)$/

              text = Regexp.last_match(2).strip
              anchor = generate_anchor(text)
              anchor_occurrences[anchor] << {
                line: line_num + 1,
                source: path,
                text:
              }
            end
          end
        end

        def extract_all_links(local_sources, command_files)
          all_links = []

          extract_links_from_sources(local_sources, all_links)
          extract_links_from_sources(command_files, all_links)

          all_links
        end

        def extract_links_from_sources(sources, all_links)
          sources.each do |source|
            content = source[:content].dup.force_encoding('UTF-8')
            path = source[:path]

            content.each_line.with_index do |line, line_num|
              line.scan(/\[([^\]]*)\]\(#([^)]+)\)/).each do |link_text, anchor_ref|
                all_links << {
                  anchor: anchor_ref,
                  line: line_num + 1,
                  source: path,
                  text: link_text
                }
              end
            end
          end
        end

        def find_ambiguous_anchors(anchor_occurrences)
          anchor_occurrences.select { |_anchor, occurrences| occurrences.size > 1 }
        end

        def find_ambiguous_links(all_links, ambiguous_anchors)
          all_links.select { |link| ambiguous_anchors.key?(link[:anchor]) }
        end

        def generate_anchor(text)
          text.downcase
              .gsub(/[^\w\s-]/, '')
              .gsub(/\s+/, '-')
              .squeeze('-')
              .gsub(/^-|-$/, '')
        end
      end
    end
  end
end
