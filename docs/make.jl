#!/usr/bin/env -S julia --threads auto --gcthreads=3 --compile=all --optimize=3

push!(LOAD_PATH,"../src/")
using AbbreviatedStackTraces, Documenter, DocumenterMarkdown, TractorBeam

# render HTML docs that can be hosted
# makedocs(sitename="TractorBeam Documentation")

# render markdown docs that can be viewed natively in the github repo
makedocs(sitename="TractorBeam Documentation", format = Markdown())
