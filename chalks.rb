require 'cgi'

class Chalk

  COMMENT_START_CHARS = {
      ruby: /#./,
      cpp: /\/\*|\/\//,
      c: /\/\//
  }
  COMMENT_END_CHARS = {
      cpp: /\*\/|.\n/,
      ruby: /.\n/,
      c: /.\n/,
  }

  STRING_SEP = %w(' ")
  SEPARATORS = " @(){}[],.:;\"\'`<>=+-*/\t\n\\?|&#"
  SEPARATORS_RX = /[@\(\)\{\}\[\],\.\:;"'`\<\>=\+\-\*\/\t\n\\\?\|\&#]/

  def initialize(file)
    @file = File.new(file)
    @rnd = Random.new(file.hash)
    @tokens = {}
    reset
  end

  def parse &block
    reset()

    @file.read.each_char do |char|
      @last_couple = ((@last_couple.size < 2) ? @last_couple : @last_couple[1]) + char

      case(@state)
        when :source
          if start_comment?(@last_couple)
            @state = :comment
          elsif STRING_SEP.include?(char)
              @string_started_with = char
              @state = :string
          else
            process_entity(&block) if (@entity.length == 1 && SEPARATORS.index(@entity))  || SEPARATORS.index(char)
          end

        when :comment
          process_entity(:source, &block) if end_comment?(@last_couple)

        when :string
          if (STRING_SEP.include?(char) && @string_started_with == char)
            @entity += char
            process_entity(:source, &block)
            char = ''
          elsif char == '\\'
            @state = :escaped_char
          else
          end
        when :escaped_char
          @state = :string
      end
      @entity += char
    end
  end

  def to_html
    html = '<html><style> a {color:#777; text-decoration:none;}
a.ten {color:#BBB; text-decoration:none;}
a:hover {color:#CBC}
body { background-color:#000; color:#BAB; background: linear-gradient(90deg, #030303 0%, #080808 50%, #030303 100%);}
.comment { color: green !important }
.string { color: gray; font-style: italic; }</style><body><table><tr><td><pre>'

    line_n = 1
    @file.readlines.each do
      html += "<a href='#'><b>#{line_n}</b></a>\n"
      line_n += 1
    end

    @file.rewind
    html += '</pre></td><td><pre>'
    parse do |entity, type|
      entity = entity.gsub("\t", '  ')
      html += highlight( entity , type)
    end
    html + '</pre><td></tr></table></body></html>'
  end

  def language
    @language ||= case(@file.path.to_s.split('.').last.to_sym)
      when :rb
        :ruby
      when :cpp, :hpp
        :cpp
      when  :c, :h
        :c
      when :py
        :python
      else
        @file.path.to_s.split('.').last.to_s
    end
  end

  private


  def process_entity(new_state = nil, &block)
    block.call @entity, @state if block
    @entity.clear
    @state = new_state if new_state
  end

  def reset
    @file.rewind if @file
    @state = :source
    @string_started_with = ''
    @entity = ''
    @last_couple = ''
  end

  def color(entity)
    entity = entity.strip

    entity.gsub! SEPARATORS_RX, ''

    token = ''
    return token if entity.empty?
    return token if token = @tokens[entity]

    return '' if entity[0].ord >= 128

    rgb = [ @rnd.rand(150) + 100, @rnd.rand(150) + 100, @rnd.rand(150) + 100 ]

    token = "#%02X%02X%02X" % rgb
    @tokens[entity] = token
    return token
  end

  def highlight(entity, type)
    esc_entity = CGI.escapeHTML( entity )
    case type
      when :string, :comment
        "<span class='#{type}'>#{esc_entity}</span>"
      else

        rgb = color(entity)
        if rgb.empty?
          esc_entity
        else
          "<span rel='t#{rgb.hash}' style='color: #{rgb}' >#{esc_entity}</span>"
        end

    end
  end

  def start_comment?(char)
    rx = COMMENT_START_CHARS[language]
    char.match rx if rx
  end

  def end_comment?(char)
    rx = COMMENT_END_CHARS[language]
    char.match rx if rx
  end
end

ch = Chalk.new(ARGV[0] || "tmp/src2.rb")
File.open(ARGV[1] || "out.html", 'w').write ch.to_html

#ch.parse do |e, t|
#  print e
#end

