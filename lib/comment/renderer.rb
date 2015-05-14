
require 'bundler/setup'
require 'kramdown'
require 'sanitize'
require 'rack'

class Comment
  class Renderer
    class Markdown

      # Maybe "auto_ids"?
      MD_OPTIONS = {
        auto_id: false
      }

      # Convert a markdown text to html and sanitize it
      # @param [String] markdown text
      # @return [String] sanitized html
      def render(text)
        html = Kramdown::Document.new(text, MD_OPTIONS).to_html
        Sanitize.clean(html, Sanitize::Config::RELAXED)
      end

      # Used for Content-Type
      def type
        'text/html'
      end
    end

    class Plain

      # Returns escaped text
      # @param [String] plain text
      # @return [String] escaped text
      def render(text)
        Rack::Utils.escape_html(text)
      end

      # Used for Content-Type
      def type
        'text/plain'
      end
    end

    # Create markdown object
    def self.create
      Markdown.new
    end
  end
end
