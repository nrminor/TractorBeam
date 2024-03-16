# TractorBeam Documentation

An unidentified flying infrastructure that beams files up, analyzes them, and then drops them back down.

```@contents
Depth = 3
```

## Overview
TractorBeam is an infrastructure for transferring files onto an HPC cluster (or any remote location), running a configurable command on them, and transferring the results back. It is available via a command line interface or (soon!) through a Pluto-based GUI that can be served and interacted with in a browser. TractorBeam makes running a complicated setup process like, for example, configuring and running [nf-core/viralrecon](https://nf-co.re/viralrecon) (its original use case) on a Slurm-based HPC cluster simple. It comes with [complete documentation](docs/build/index.md), unit-testing, and GitHub workflows to make sure everything is in working order and ready to run on your machine.

## API Reference

### Composite Types

```@docs
Credentials
```

```@docs
TransferFile
```

```@docs
TransferQueue
```

### Functions

```@docs
generate_config
```

```@docs
interpolate_remote
```

```@docs
parse_config
```

```@docs
make_local_file_queue
```

```@docs
oversee_transfers
```

```@docs
run_remote_command
```

```@docs
make_result_file_queue
```
