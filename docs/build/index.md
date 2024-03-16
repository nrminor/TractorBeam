
<a id='TractorBeam-Documentation'></a>

<a id='TractorBeam-Documentation-1'></a>

# TractorBeam Documentation


An unidentified flying infrastructure that beams files up, analyzes them, and then drops them back down.

- [TractorBeam Documentation](index.md#TractorBeam-Documentation)
    - [Overview](index.md#Overview)
    - [API Reference](index.md#API-Reference)
        - [Composite Types](index.md#Composite-Types)
        - [Functions](index.md#Functions)


<a id='Overview'></a>

<a id='Overview-1'></a>

## Overview


TractorBeam is an infrastructure for transferring files onto an HPC cluster (or any remote location), running a configurable command on them, and transferring the results back. It is available via a command line interface or (soon!) through a Pluto-based GUI that can be served and interacted with in a browser. TractorBeam makes running a complicated setup process like, for example, configuring and running [nf-core/viralrecon](https://nf-co.re/viralrecon) (its original use case) on a Slurm-based HPC cluster simple. It comes with [complete documentation](docs/build/index.md), unit-testing, and GitHub workflows to make sure everything is in working order and ready to run on your machine.


<a id='API-Reference'></a>

<a id='API-Reference-1'></a>

## API Reference


<a id='Composite-Types'></a>

<a id='Composite-Types-1'></a>

### Composite Types


!!! warning "Missing docstring."
    Missing docstring for `Credentials`. Check Documenter's build log for details.



!!! warning "Missing docstring."
    Missing docstring for `TransferFile`. Check Documenter's build log for details.



!!! warning "Missing docstring."
    Missing docstring for `TransferQueue`. Check Documenter's build log for details.



<a id='Functions'></a>

<a id='Functions-1'></a>

### Functions


!!! warning "Missing docstring."
    Missing docstring for `generate_config`. Check Documenter's build log for details.



!!! warning "Missing docstring."
    Missing docstring for `interpolate_remote`. Check Documenter's build log for details.



!!! warning "Missing docstring."
    Missing docstring for `parse_config`. Check Documenter's build log for details.



!!! warning "Missing docstring."
    Missing docstring for `make_local_file_queue`. Check Documenter's build log for details.



!!! warning "Missing docstring."
    Missing docstring for `oversee_transfers`. Check Documenter's build log for details.



!!! warning "Missing docstring."
    Missing docstring for `run_remote_command`. Check Documenter's build log for details.



!!! warning "Missing docstring."
    Missing docstring for `make_result_file_queue`. Check Documenter's build log for details.


