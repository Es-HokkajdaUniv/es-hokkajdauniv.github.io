# _plugins/leipzig_gloss.rb
require 'cgi'

module LeipzigPlugin
  class Leipzig
    DEFAULTS = {
      selector: '[data-gloss]',
      last_line_free: true,
      first_line_orig: false,
      spacing: true,
      auto_tag: true,
      # lexer: tokens are either {...} groups or runs of non-whitespace
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
      # abbreviated mapping (taken from original JS a = {...})
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

    # --- lexer: return array of tokens from a string ---
    # tokens are either {...} contents or non-space sequences
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

    # --- tag: wrap morphological abbreviations in <abbr> with title ---
    # tries to emulate JS regex: /(\b[0-4])(?=[A-Z]|\b)|(N?[A-Z]+\b)/g
    def tag(token)
      return "" if token.nil?
      # We will replace occurrences of either:
      #  - single digit 0-4 as separate "0".."4" before an uppercase or word boundary
      #  - N? followed by one or more uppercase letters
      s = token.dup
      # Use gsub with block to preserve unmatched text
      pattern = /(\b[0-4])(?=[A-Z]|\b)|(N?[A-Z]+\b)/
      result = s.gsub(pattern) do |match|
        key = match
        # If starts with 'N' and length>1, attempt to lookup both forms
        if key.start_with?('N') && key.length > 1
          plain = key[1..-1]
          if @abbrev[key]
            title = @abbrev[key]
            "<abbr class=\"#{@classes[:abbr]}\" title=\"#{escape(title)}\">#{escape(key)}</abbr>"
          elsif @abbrev[plain]
            title = @abbrev[plain]
            "<abbr class=\"#{@classes[:abbr]}\" title=\"non-#{escape(title)}\">#{escape(key)}</abbr>"
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
      result
    end

    # --- align: input = array of token-arrays (each array = tokens of a line) ---
    # produce array of columns where each column is array of tokens for each line (filling "" if missing)
    def align(lines_tokens)
      return [] if lines_tokens.nil? || lines_tokens.empty?
      max_len = lines_tokens.map(&:length).max || 0
      cols = (0...max_len).map do |i|
        lines_tokens.map { |ln| ln[i] || "" }
      end
      cols
    end

    # --- format: given aligned columns, produce HTML string ---
    # lines_offset = first line number used for numbering classes (0-based)
    # tag_name = 'div' or 'li' etc.
    def format(aligned_cols, tag_name = "div", lines_offset = 0)
      words_class = @classes[:words]
      word_cls = @classes[:word]
      spacer_class = @classes[:spacer]
      line_class_prefix = @classes[:line_num_prefix]
      line_base = @classes[:line]

      # Build the wrapper element as string
      html = +""
      html << "<#{tag_name} class=\"#{words_class}\">\n"

      aligned_cols.each_with_index do |col, col_index|
        # build inner paragraphs for each line in this column
        inner = +""
        col.each_with_index do |cell, i|
          # the original code used i + lines_offset as the numeric suffix
          ln_num = i + lines_offset
          cls = "#{line_base} #{line_class_prefix}#{ln_num}"
          content = cell.to_s
          # if the cell is present and auto_tag enabled, tag abbreviations
          if @auto_tag && !content.strip.empty?
            content = tag(content)
          else
            content = escape(content)
          end
          inner << "  <p class=\"#{escape(cls)}\">#{content}</p>\n"
        end

        # if no spacing and every cell is empty, add spacer class as in original
        word_outer_class = word_cls.dup
        if !@spacing
          all_blank = col.all? { |c| c.to_s.strip.empty? }
          word_outer_class << " #{spacer_class}" if all_blank
        end

        html << "  <div class=\"#{escape(word_outer_class)}\">\n"
        html << inner
        html << "  </div>\n"
      end

      html << "</#{tag_name}>\n"
      html
    end

    # --- gloss_block: main entry ---
    # Accepts a block text (string with newline-separated lines).
    # Returns an HTML fragment (string) that contains:
    #  - paragraphs for original/free lines with proper classes,
    #  - the generated Leipzig-like gloss block inserted before the first gloss-line.
    def gloss_block(block_text)
      lines = block_text.to_s.lines.map(&:chomp)
      return "" if lines.empty?

      # Decide which lines are "original" and "free translation"
      first_is_original = @first_line_orig
      last_is_free = @last_line_free && lines.length >= 2

      # Identify indices
      first_gloss_index = 0
      last_gloss_index = lines.length - 1

      original_index = first_is_original ? 0 : nil
      free_index = last_is_free ? lines.length - 1 : nil

      # Build arrays for lexing: take lines that are gloss lines (neither original nor free)
      gloss_line_indices = (0...lines.length).select do |i|
        i != original_index && i != free_index
      end

      # Lex each gloss line
      tokens_per_line = gloss_line_indices.map { |i| lex(lines[i]) }

      # If there are no gloss lines, just output paragraphs with classes
      if tokens_per_line.empty?
        return lines.each_with_index.map do |ln, i|
          cls = []
          cls << @classes[:line]
          cls << "#{@classes[:line_num_prefix]}#{i}"
          cls << @classes[:original] if i == original_index
          cls << @classes[:free_translation] if i == free_index
          "<p class=\"#{cls.compact.join(' ')}\">#{escape(ln)}</p>"
        end.join("\n")
      end

      # Align tokens
      aligned = align(tokens_per_line) # columns x lines(within gloss) array

      # Format: tag name = div (static)
      # lines_offset: the numeric suffix for .gloss__line--N should be the first gloss line index
      first_line_num = gloss_line_indices.first || 0
      formatted = format(aligned, "div", first_line_num)

      # Now build output: iterate original, then insert formatted before first gloss line, then hidden gloss lines as needed, then free translation
      out = +""

      lines.each_with_index do |ln, i|
        if i == original_index
          cls = [@classes[:line], "#{@classes[:line_num_prefix]}#{i}", @classes[:original]]
          out << "<p class=\"#{escape(cls.join(' '))}\">#{escape(ln)}</p>\n"
        elsif i == free_index
          cls = [@classes[:line], "#{@classes[:line_num_prefix]}#{i}", @classes[:free_translation]]
          out << "<p class=\"#{escape(cls.join(' '))}\">#{escape(ln)}</p>\n"
        else
          # first gloss-line spot: insert the formatted block before the first gloss-line's paragraph,
          # but in original leipzig they insert formatted block and hide the original gloss lines (add hidden class).
          if i == gloss_line_indices.first
            # insert formatted
            out << formatted
          end
          # output original gloss line but as hidden (so original text remains in DOM but hidden)
          cls = [@classes[:line], "#{@classes[:line_num_prefix]}#{i}", @classes[:hidden]]
          out << "<p class=\"#{escape(cls.join(' '))}\">#{escape(ln)}</p>\n"
        end
      end

      # Add top-level glossed/no-space classes on wrapper? Original leipzig adds classes to the element container,
      # but here we just return fragment. Caller (Liquid) can wrap with container if wanted.
      out
    end
  end

  # Jekyll Liquid block
  # Usage:
  # {% gloss %}
  # line1
  # line2
  # line3
  # {% endgloss %}

  class GlossBlock < Liquid::Block
    def initialize(tag_name, markup, tokens)
      super
      @options = {}
      markup.scan(/(\w+)\s*:\s*(\w+)/).each do |k,v|
        @options[k.to_sym] = case v.downcase
                             when "true" then true
                             when "false" then false
                             else v
                             end
      end
    end

    def render(context)
      content = super.to_s.strip
    
      # オプションをシンボルキーで boolean に変換して明示
      opts = {}
      @options.each do |k,v|
        opts[k.to_sym] = case v
                         when true, "true" then true
                         when false, "false" then false
                         else v
                         end
      end
    
      # Leipzig に渡す
      leipzig = Leipzig.new(opts)
    
      # 結果を div.gloss でラップ
      "<div class=\"gloss\">\n" + leipzig.gloss_block(content) + "</div>"
    end
  end
end


Liquid::Template.register_tag('gloss', LeipzigPlugin::GlossBlock)
