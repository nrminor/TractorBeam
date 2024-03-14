#!/usr/bin/env -S julia --threads auto --gcthreads=3 --compile=all --optimize=3

using Pkg
Pkg.activate(".")

using ArgParse
using Base.Threads: @threads
using Logging
using Pipe: @pipe
using MD5
using YAML
using TractorBeam

# dev imports
using Revise
using Documenter
using JET
using OhMyREPL

"""
"""
function parse_command_line_args()
    arg_settings = ArgParseSettings()

    @add_arg_table arg_settings begin
        "--source_dir", "-s"
        help = "The source directory full of input data to be transferred."
        arg_type = String
        default = "."

        "--destination", "-d"
        help = "The destination directory where the results files should be placed."
        arg_type = String

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
"""
function main()
    # parse command line args
    arg_dict = parse_command_line_args()

    # attempt to generate static config from Pkl file
    yaml_name = generate_config(arg_dict["config"])

    # parse config
    credentials, local_dir, results_dir, command = parse_config(yaml_name)

    # catalog local files to be sent
    queue = make_local_file_queue(local_dir, remote_dir)

    # run the transfer onto the remote host
    oversee_transfers(queue, credentials, true)

    # once the transfer has completed, run the command
    run_hpc_command(command, credentials)

    # catalog the results files to be transferred
    results_queue = make_result_file_queue(
        credentials,
        results_dir,
        "$local_dir/$results_dir",
    )

    # bring 'em home
    oversee_transfers(results_queue, credentials, false)

end
precompile(main, ())

main()
