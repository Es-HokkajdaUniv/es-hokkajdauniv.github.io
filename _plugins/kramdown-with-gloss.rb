# _plugins/leipzig_gloss.rb
require 'cgi'
require 'yaml'

module LeipzigPlugin
  class Leipzig
    DEFAULTS = {
      selector: '[data-gloss]',
      last_line_free: true,
      first_line_orig: false,
      spacing: true,
      auto_tag: true,
      lexer: /\{(.*?)\}|([^\s]+)/m,
      classes: {
        glossed: "gloss--glossed",
        no_space: "gloss--no-space",
        words: "gloss__words",
        word: "gloss__word",
        spacer: "gloss__word--spacer",
        abbr: "gloss__abbr",
        line: "gloss__line",
        line_num_prefix: "gloss__line--",
        original: "gloss__line--original",
        free_translation: "gloss__line--free",
        no_align: "gloss__line--no-align",
        hidden: "gloss__line--hidden"
      },
      abbreviations: {
        "1"=>"first person","2"=>"second person","3"=>"third person",
        "A"=>"agent-like argument of canonical transitive verb","ABL"=>"ablative","ABS"=>"absolutive",
        "ACC"=>"accusative","ADJ"=>"adjective","ADV"=>"adverb(ial)","AGR"=>"agreement","ALL"=>"allative",
        "ANTIP"=>"antipassive","APPL"=>"applicative","ART"=>"article","AUX"=>"auxiliary","BEN"=>"benefactive",
        "CAUS"=>"causative","CLF"=>"classifier","COM"=>"comitative","COMP"=>"complementizer","COMPL"=>"completive",
        "COND"=>"conditional","COP"=>"copula","CVB"=>"converb","DAT"=>"dative","DECL"=>"declarative","DEF"=>"definite",
        "DEM"=>"demonstrative","DET"=>"determiner","DIST"=>"distal","DISTR"=>"distributive","DU"=>"dual","DUR"=>"durative",
        "ERG"=>"ergative","EXCL"=>"exclusive","F"=>"feminine","FOC"=>"focus","FUT"=>"future","GEN"=>"genitive","IMP"=>"imperative",
        "INCL"=>"inclusive","IND"=>"indicative","INDF"=>"indefinite","INF"=>"infinitive","INS"=>"instrumental","INTR"=>"intransitive",
        "IPFV"=>"imperfective","IRR"=>"irrealis","LOC"=>"locative","M"=>"masculine","N"=>"neuter","NEG"=>"negation / negative",
        "NMLZ"=>"nominalizer / nominalization","NOM"=>"nominative","OBJ"=>"object","OBL"=>"oblique","P"=>"patient-like argument of canonical transitive verb",
        "PASS"=>"passive","PFV"=>"perfective","PL"=>"plural","POSS"=>"possessive","PRED"=>"predicative","PRF"=>"perfect","PRS"=>"present",
        "PROG"=>"progressive","PROH"=>"prohibitive","PROX"=>"proximal / proximate","PST"=>"past","PTCP"=>"participle","PURP"=>"purposive",
        "Q"=>"question particle / marker","QUOT"=>"quotative","RECP"=>"reciprocal","REFL"=>"reflexive","REL"=>"relative","RES"=>"resultative",
        "S"=>"single argument of canonical intransitive verb","SBJ"=>"subject","SBJV"=>"subjunctive","SG"=>"singular","TOP"=>"topic","TR"=>"transitive",
        "VOC"=>"vocative"
      }
    }

    def initialize(options = {})
      @cfg = deep_merge(DEFAULTS, options)
      @classes = @cfg[:classes]
      @abbrev = @cfg[:abbreviations]
      @lexer = @cfg[:lexer]
      @first_line_orig = @cfg[:first_line_orig]
      @last_line_free = @cfg[:last_line_free]
      @spacing = @cfg[:spacing]
      @auto_tag = @cfg[:auto_tag]
    end

    # --- utilities ---
    def escape(s)
      CGI.escapeHTML(s.to_s)
    end

    def deep_merge(a, b)
      result = {}
      a.each { |k,v| result[k] = v }
      b.each do |k,v|
        if v.is_a?(Hash) && result[k].is_a?(Hash)
          result[k] = deep_merge(result[k], v)
        else
          result[k] = v
        end
      end
      result
    end

    # --- lexer ---
    def lex(str)
      return [] if str.nil? || str.strip.empty?
      tokens = []
      str.scan(@lexer) do |brace_group, nonspace|
        if brace_group && !brace_group.empty?
          tokens << brace_group
        elsif nonspace
          tokens << nonspace
        end
      end
      tokens
    end

    # --- tag abbreviations ---
    def tag(token)
      return "" if token.nil?
      s = token.dup
      pattern = /(\b[0-4])(?=[A-Z]|\b)|(N?[A-Z]+\b)/
      s.gsub(pattern) do |match|
        key = match
        if key.start_with?('N') && key.length > 1
          plain = key[1..-1]
          if @abbrev[key]
            "<abbr class=\"#{@classes[:abbr]}\" title=\"#{escape(@abbrev[key])}\">#{escape(key)}</abbr>"
          elsif @abbrev[plain]
            "<abbr class=\"#{@classes[:abbr]}\" title=\"non-#{escape(@abbrev[plain])}\">#{escape(key)}</abbr>"
          else
            "<abbr class=\"#{@classes[:abbr]}\">#{escape(key)}</abbr>"
          end
        else
          if @abbrev[key]
            "<abbr class=\"#{@classes[:abbr]}\" title=\"#{escape(@abbrev[key])}\">#{escape(key)}</abbr>"
          else
            "<abbr class=\"#{@classes[:abbr]}\">#{escape(key)}</abbr>"
          end
        end
      end
    end

    # --- align ---
    def align(lines_tokens)
      return [] if lines_tokens.nil? || lines_tokens.empty?
      max_len = lines_tokens.map(&:length).max || 0
      (0...max_len).map { |i| lines_tokens.map { |ln| ln[i] || "" } }
    end

    # --- format ---
    def format(aligned_cols, tag_name = "div", lines_offset = 0)
      html = +"" 
      html << "<#{tag_name} class=\"#{@classes[:words]}\">\n"

      aligned_cols.each_with_index do |col, _|
        inner = +"" 
        col.each_with_index do |cell, i|
          ln_num = i + lines_offset
          cls = "#{@classes[:line]} #{@classes[:line_num_prefix]}#{ln_num}"
          content = (@auto_tag && !cell.strip.empty?) ? tag(cell) : escape(cell)
          inner << "  <p class=\"#{escape(cls)}\">#{content}</p>\n"
        end

        word_cls = @classes[:word]
        all_blank = !@spacing && col.all? { |c| c.strip.empty? }
        word_cls += " #{@classes[:spacer]}" if all_blank
        html << "  <div class=\"#{escape(word_cls)}\">\n"
        html << inner
        html << "  </div>\n"
      end

      html << "</#{tag_name}>\n"
      html
    end

    # --- gloss_block ---
    def gloss_block(block_text)
      lines = block_text.to_s.lines.map(&:chomp)
      return "" if lines.empty?

      first_is_original = @first_line_orig
      last_is_free = @last_line_free && lines.length >= 2

      original_index = first_is_original ? 0 : nil
      free_index = last_is_free ? lines.length - 1 : nil

      gloss_line_indices = (0...lines.length).select { |i| i != original_index && i != free_index }
      tokens_per_line = gloss_line_indices.map { |i| lex(lines[i]) }

      if tokens_per_line.empty?
        return lines.each_with_index.map do |ln, i|
          cls = [@classes[:line], "#{@classes[:line_num_prefix]}#{i}"]
          cls << @classes[:original] if i == original_index
          cls << @classes[:free_translation] if i == free_index
          "<p class=\"#{cls.compact.join(' ')}\">#{escape(ln)}</p>"
        end.join("\n")
      end

      aligned = align(tokens_per_line)
      first_line_num = gloss_line_indices.first || 0
      formatted = format(aligned, "div", first_line_num)

      out = +""
      lines.each_with_index do |ln, i|
        if i == original_index
          cls = [@classes[:line], "#{@classes[:line_num_prefix]}#{i}", @classes[:original]]
          out << "<p class=\"#{escape(cls.join(' '))}\">#{escape(ln)}</p>\n"
        elsif i == free_index
          cls = [@classes[:line], "#{@classes[:line_num_prefix]}#{i}", @classes[:free_translation]]
          out << "<p class=\"#{escape(cls.join(' '))}\">#{escape(ln)}</p>\n"
        else
          if i == gloss_line_indices.first
            out << formatted
          end
          cls = [@classes[:line], "#{@classes[:line_num_prefix]}#{i}", @classes[:hidden]]
          out << "<p class=\"#{escape(cls.join(' '))}\">#{escape(ln)}</p>\n"
        end
      end
      out
    end
  end

  # --- Liquid block ---
  class GlossBlock < Liquid::Block
    def initialize(tag_name, markup, tokens)
      super
      @options = {}
      markup.scan(/([\w-]+)\s*:\s*(\w+)/) do |key, value|
        normalized_key = key.tr('-', '_').to_sym
        @options[normalized_key] = case value.downcase
                                   when "true" then true
                                   when "false" then false
                                   else value
                                   end
      end
    end

    def render(context)
      content = super.to_s.strip
      leipzig = Leipzig.new(@options)
      "<div class=\"gloss\">\n" + leipzig.gloss_block(content) + "</div>"
    end
  end
end

Liquid::Template.register_tag('gloss', LeipzigPlugin::GlossBlock)
