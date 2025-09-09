# prepare.rb
# Finds AsciiDoc codeblock callouts and injects them as comments in the codeblock
require 'asciidoctor'

Asciidoctor::Extensions.register do
  preprocessor do
    process do |doc, reader|
      lines = reader.read_lines
      out = []
      i = 0

      # languages to process
      lang_rx = /\b(?:ya?ml|bash|sh|shell|console|terminal|cmd)\b/i

      while i < lines.length
        # [source, ... <lang> ...] followed by opening fence
        if lines[i] =~ /^\[\s*source\s*,\s*([^\]]*#{lang_rx}[^\]]*)\]\s*$/i &&
           (i + 1) < lines.length && lines[i + 1].strip == '----'

          header = lines[i]
          # keep literal <n> markers until we inject comments
          if header !~ /subs\s*=\s*[^\\\]]*callouts/i
            header = header.sub(/\]\s*$/i, ',subs=-callouts]')
          end
          out << header
          out << lines[i + 1]
          i += 2

          # Buffer the whole code block (do not emit yet)
          code_buf = []
          while i < lines.length && lines[i].strip != '----'
            code_buf << lines[i]
            i += 1
          end
          had_close = (i < lines.length && lines[i].strip == '----')
          i += 1 if had_close

          # Read the immediately-following callout list into a map num=>comment lines
          comments = {}
          while i < lines.length && lines[i] =~ /^\s*<(\d+)>\s*(.*)$/
            num  = Regexp.last_match(1).to_i
            lead = Regexp.last_match(2).to_s.strip
            block_lines = []
            block_lines << "# #{lead}" unless lead.empty?

            j = i + 1
            while j < lines.length
              l = lines[j]
              break if l.strip.empty?            # blank line ends this item
              break if l =~ /^\s*<\d+>\s*/       # next item starts

              if l =~ /^\s*[\*\-+]\s+(.*\S.*)$/
                block_lines << "# - #{Regexp.last_match(1).strip}"
              else
                block_lines << "# #{l.strip}"
              end
              j += 1
            end

            comments[num] = block_lines
            i = j
          end

          # Inject comment blocks at code lines that end with <n> or "# <n>"
          rewritten = []
          code_buf.each do |line|
            if line =~ /^([ \t]*)(.*?)(?:[ \t]*#?\s*<(\d+)>\s*)$/
              indent = Regexp.last_match(1)
              core   = Regexp.last_match(2).rstrip
              n      = Regexp.last_match(3).to_i

              if comments[n] && !comments[n].empty?
                comments[n].each { |cl| rewritten << "#{indent}#{cl}" }
              end
              rewritten << "#{indent}#{core}"
            else
              rewritten << line
            end
          end

          # emit code + closing fence
          rewritten.each { |l| out << l }
          out << '----' if had_close
          next
        end

        # passthrough
        out << lines[i]
        i += 1
      end

      Asciidoctor::Reader.new(out)
    end
  end
end
