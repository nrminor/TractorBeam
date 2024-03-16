#!/usr/bin/env -S julia --threads auto --gcthreads=3 --compile=all --optimize=3

using Pkg
Pkg.activate(".")
Pkg.precompile()

using ArgParse
using Logging
using MD5

import TractorBeam as TB

"""
    parse_command_line_args()

Parse command-line arguments for a project that involves transferring a
hierarchy of files to a remote cluster, executing a configurable command there,
and then transferring a hierarchy of results files back to the local machine.

### Arguments

- None

### Returns

- `ArgParse`: A structure containing the parsed command-line arguments.

### Options

- `--source_dir`, `-s`: The source directory full of input data to be
transferred. Defaults to `"input"`.
- `--destination`, `-d`: The destination directory where the results files
should be placed. Defaults to `"results"`.
- `--config`, `-c`: Specifies the configuration file to use. Defaults to
`"tractorbeam.pkl"`.
- `--gui`, `-g`: Enable running in the browser through a GUI instead of the
CLI. This is a flag; it does not require a value.

"""
function parse_command_line_args()
    arg_settings = ArgParseSettings()

    @add_arg_table arg_settings begin
        "--source_dir", "-s"
        help = "The source directory full of input data to be transferred."
        arg_type = String
        default = "input"

        "--destination", "-d"
        help = "The destination directory where the results files should be placed."
        arg_type = String
        default = "results"

        "--config", "-c"
        help = "an option without argument, i.e. a flag"
        arg_type = String
        default = "tractorbeam.pkl"

        "--gui", "-g"
        help = "whether to run in the browser through a GUI instead of through the cli"
        action = :store_true
    end

    return parse_args(arg_settings)
end
precompile(parse_command_line_args, ())


"""
    main()

The main function orchestrates the workflow of transferring a hierarchy of
files to a remote cluster, executing a highly configurable command there, and
then transferring a hierarchy of results files back to the local machine. This
function leverages command-line arguments to control its behavior, including
    the option to launch a GUI for interaction.

### Workflow

1. **Command-Line Argument Parsing**: If arguments are provided, the function
parses them to configure the operation. If no arguments are found, the script
exits.
2. **GUI Launch**: If the `--gui` flag is set, the function logs an
informational message and exits, indicating that GUI functionalities are yet to
be implemented.
3. **Configuration Generation and Parsing**: Generates a static configuration
from a `.pkl` file and parses this configuration to obtain necessary details
like credentials, directory paths, and the command to execute on the remote
cluster.
4. **File Transfer to Remote Cluster**: Catalogs local files to be sent and
oversees their transfer to the remote cluster.
5. **Remote Command Execution**: Executes the specified command on the remote
cluster using the provided credentials.
6. **Results Transfer Back to Local Machine**: Catalogs the result files on the
remote cluster and oversees their transfer back to the local machine.

### Command-Line Arguments

The function supports several command-line arguments to configure its
operation, parsed by `parse_command_line_args`. These include:

- `--source_dir`, `-s`: Specifies the source directory of input data.
- `--destination`, `-d`: Specifies the destination directory for result files.
- `--config`, `-c`: Specifies the path to the configuration file.
- `--gui`, `-g`: If present, indicates that the operation should proceed
through a GUI rather than the CLI.

### Examples

Running with command-line arguments:

```sh
julia scripts/main.jl -s path/to/source -d path/to/destination -c config.pkl
```
"""
function main()

    # check for command line arguments
    if length(ARGS) > 0
        @info "Command line arguments provided. Running in script mode."
        # parse command line args
        arg_dict = parse_command_line_args()
    else
        exit(0)
    end

    # check for a gui call
    if arg_dict["gui"]
        @info "Running TractorBeam GUI"
        # TODO: call to launch GUI functions
        exit(0)
    end

    # attempt to generate static config from Pkl file
    yaml_name = TB.generate_config(arg_dict["config"])

    # parse config
    credentials, local_dir, results_dir, command = TB.parse_config(yaml_name)

    # catalog local files to be sent
    queue = TB.make_local_file_queue(local_dir, credentials.remote_dir)

    # run the transfer onto the remote host
    TB.oversee_transfers(queue, credentials, true)

    # once the transfer has completed, run the command
    TB.run_remote_command(command, credentials)

    # catalog the results files to be transferred
    results_queue = TB.make_result_file_queue(
        credentials,
        "$(credentials.remote_dir)/$results_dir",
        results_dir,
    )

    # bring 'em home
    TB.oversee_transfers(results_queue, credentials, false)

end
precompile(main, ())

main()
