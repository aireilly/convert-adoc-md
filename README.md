# convert-adoc-md

Opinionated Get-out-of-AsciiDoc POC.

Opinions:

- Use Asciidoctor Docbook XML as the basis for conversion
- Chop h2 and below to topics, include anything under h2 in the parent topic. No h3 or smaller in topics.
- Markdown should be legible in GH, using GFM
- Markdown should be ready to drop into industry standard mkdocs builds
- Use markdown-include for snippets
    ```cmd
    markdown_extensions:
        - markdown_include
    ```

    `{! docs/intro.md !}`

- Use GFM admonitions
    ```markdown
    > [!NOTE]
    > This is a WIP project playing with moving adoc to md.
    ```

- Allow in-repo relative links, FQ URL links otherwise  
- Markdown should be LLM ingestion friendly
- Kill ifdefs with fire
- Reduce all conditional and attributes markup. Conditions and attributes make the content mostly illegible at the file level. 

Install latest [pandoc](https://github.com/jgm/pandoc/releases), asciidoctor, asciidoctor-reducer (optional).

```cmd
sudo gem install asciidoctor asciidoctor-reducer
```

For quick testing, start with a reduced AsciiDoc document. e.g,

```cmd
asciidoctor-reducer cnf-numa-aware-scheduling.adoc > ~/convert-adoc-md/test/cnf-numa-aware-scheduling.adoc
```

Copy images folder to test/images.

Generate Docbook:

```cmd
asciidoctor -b docbook -a product-title=OpenShift -a product-version=4.18 -a data-uri! test/cnf-numa-aware-scheduling.adoc -o test/cnf-numa-aware-scheduling.xml
```

Generate docbook

```cmd
$ asciidoctor -b docbook -a product-title=OpenShift -a product-version=4.18 -a data-uri! -o callouts.xml test/callouts.adoc
```

Generate Pandoc AST from docbook XML:

```cmd
pandoc docs/callouts.xml -f docbook -t xml > docs/ast.xml
```

## Prepare AsciiDoc and then process with Pandoc

All in one:

```cmd
asciidoctor -r ./prepare.rb -b docbook5 -o - test/callouts.adoc \
| pandoc --wrap=none -f docbook - -t gfm+footnotes+implicit_figures+footnotes+definition_lists \
  --lua-filter=figures.lua \
  --lua-filter=title.lua \
  --lua-filter=tables.lua \
  --lua-filter=callouts.lua \
  > docs/out.md
```

## AsciiDoc rework before conversion

- prepare.rb


## TODO

- xrefs
- links
- tables
- mkdocs
- How to handle table titles?
- Splitting content to h1 modules?
- Highlight broken or missing content in the conversion
- Create opinionated `mkdocs.yml` config
- Create an opinionated md frontmatter set up