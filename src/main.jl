#!/usr/bin/env -S julia  --threads auto --gcthreads=3 --compile=all --output-asm determinist.s --optimize=3

using ArgParse
using Base.Threads: @threads
using Logging
using Pipe: @pipe
using MD5
using TractorBeam: Credentials, Command, TransferFile, TransferQueue

const SOURCE_DIR::String = ""
const FILE_EXTENSION::String = ""
const HPC_DESTINATION::String = ""
const FINAL_DESTINATION::String = ""

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
        default = "tractorbeam.yaml"

        """
        --gui
        """
        help = "whether to run in the browser through a GUI instead of through the cli"
        action = :store_true
    end

    return parse_args(arg_settings)
end

"""
"""
function transfer_to_hpc() end
precompile(transfer_to_hpc, ())

"""
"""
function run_hpc_command() end
precompile(run_hpc_command, ())

"""
"""
function collect_hpc_results() end
precompile(collect_hpc_results, ())

"""
"""
function transfer_from_hpc() end
precompile(transfer_from_hpc, ())

"""
"""
function main() end

main()
