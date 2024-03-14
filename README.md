# TractorBeam

An unidentified flying infrastructure that beams files up, analyzes them, and then drops them back down.

### Overview
TractorBeam is an infrastructure for transferring files onto an HPC cluster (or any remote location), running a configurable command on them, and transferring the results back. It is available via a command line interface or (soon!) through a Pluto-based GUI that can be served and interacted with in a browser. TractorBeam makes running a complicated setup process like, for example, configuring and running [nf-core/viralrecon](https://nf-co.re/viralrecon) (its original use case) on a Slurm-based HPC cluster simple. It comes with complete documentation, unit-testing, and GitHub workflows to make sure everything is in working order and ready to run on your machine. 

### A note on the Julia Language and Configuration
In large part, TractorBeam is a glue-language wrapper around shell commands. This is because Julia has ended up being the glue language where I feel the most productive, which is to say, I can get things working (and working *well*) faster in Julia than in other languages. Julia's syntax for string interpolation, shell command running, and spreading tasks across available CPU cores made it surprisingly easy to put this project together—it took little more than a couple afternoons, but has been remarkably robust in my own weekly usage of it.

That said, I recognize that Julia is not commonly known compared to languages like Python, BASH, and R, the usual picks for glue languages in academia and data science. So, despite being written in and benefiting from Julia, TractorBeam aims to make not knowing Julia immaterial—just work with it in your browser (again, WIP!) and get results quickly. The hard part won't be needing to learn Julia or decoding Julia errors (which can be as unhelpful as Python traceback-style errors). Instead, the hardest part will be writing a configuration file that tells TractorBeam where it needs to transfer to and from, and how it needs to configure its commands. 

TractorBeam uses Apple's simple Pkl language for configuration, which makes it possible a) to auto-generate elements of the configuration based on other parts of the configuration, and b) provides validation utilities that aren't available for JSON, YAML, or TOML. Because configuation is the hardest part of using TractorBeam, I'll continue to add guards to the Pkl file so users can catch their mistakes before they even fire up TractorBeam.
