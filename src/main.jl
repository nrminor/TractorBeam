#!/usr/bin/env -S julia  --threads auto --gcthreads=3 --compile=all --output-asm determinist.s --optimize=3

using ArgParse
using Base.Threads: @threads
using Logging
using Pipe: @pipe
using MD5
using TractorBeam

const INPUT_DIR::String = ""
const FILE_EXTENSION::String = ""
const HPC_DESTINATION::String = ""
const FINAL_DESTINATION::String = ""

"""
"""
struct Credentials
    address::String, username::String, password::String
end

"""
"""
struct Command
    in_path::String, out_path::String, config_path::String
end

"""
"""
mutable struct ResultFile
    relative_path::String,
    dest_path::String,
    origin_hash::String,
    return_hash::String
end


"""
"""
mutable struct TransferQueue
    member_count::Int,
    remaining::Int
end


"""
"""
function parse_commandline()
    arg_settings = ArgParseSettings()

    @add_arg_table arg_settings begin
        "--source_dir", "-s"
        help = "an option with an argument"
        arg_type = String
        default = "."
        "--destination", "-d"
        help = "another option with an argument"
        arg_type = String
        default = 0
        "--config", "-c"
        help = "an option without argument, i.e. a flag"
        action = :store_true
        """
        arg1
        """
        help = "a positional argument"
        required = true
    end

    return parse_args(s)
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
