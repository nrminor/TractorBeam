# TractorBeam

An unidentified flying infrastructure that beams files up, analyzes them, and then drops them back down.

### Overview
TractorBeam is an infrastructure for transferring files onto an HPC cluster (or any remote location), running a configurable command on them, and transferring the results back. It is available via a command line interface or (soon!) through a Pluto-based GUI that can be served and interacted with in a browser. TractorBeam makes running a complicated setup process like, for example, configuring and running [nf-core/viralrecon](https://nf-co.re/viralrecon) (its original use case) on a Slurm-based HPC cluster simple. It comes with [complete documentation](docs/build/index.md), unit-testing, and GitHub workflows to make sure everything is in working order and ready to run on your machine. 

### A note on the Julia Language and Configuration
TractorBeam can be considered a high-performance prototype, which the Julia language is very good for. In addition to be fast after the first execution of each function, Julia's syntax for string interpolation, shell command running, and spreading tasks across available CPU cores made quick and enjoyable to put together this project. 

That said, I recognize that Julia is not commonly known compared to the usual picks for glue languages, e.g., Python, BASH, and R. So, despite being written in and benefiting from Julia, TractorBeam aims to make not knowing Julia immaterial—just work with it in your browser (again, WIP!) and get your results. The hard part won't be needing to learn Julia or decoding Julia errors. Instead, the hardest part will be writing a configuration file that tells TractorBeam where it needs to transfer to and from, and how it needs to configure its commands.

Configuration itself can be highly error-prone. To get around this, TractorBeam uses Apple's new Pkl language for configuration. Pkl is readable like TOML or YAML, but it brings with it the ability to a) auto-generate elements of the configuration based on other parts of the configuration, b) validate data in ways that aren't available with native JSON, YAML, or TOML, and c) separate user-facing settings from auto-generated settings with modules. Because configuration is the hardest part of using TractorBeam, I'll continue to add guards to the Pkl configuration so users can catch their mistakes before they even fire up TractorBeam.
