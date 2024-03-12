# TractorBeam

An unidentified flying infrastructure that beams files up, analyzes them, and then drops them back down.

TractorBeam is a work-in-progress infrastructure for transferring files onto an HPC cluster, running a configurable command on them, and transferring the results back. It is available via a command line interface or through a Pluto-based GUI that can be served and interacted with in a browser. TractorBeam makes running a complicated setup process like, for example, configuring and running [nf-core/viralrecon]() (its original use case) on a Slurm-based HPC cluster simple. It comes with complete documentation, unit-testing, and GitHub workflows to make sure everything is in working order and ready to run on your machine.
