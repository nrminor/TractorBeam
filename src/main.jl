#!/usr/bin/env -S julia  --threads auto --gcthreads=3 --compile=all --output-asm determinist.s --optimize=3

using ArgParse
using Base.Threads: @threads
using Logging
using Pipe: @pipe
using ResultTypes: @try
using MD5
using YAML
using TractorBeam

# dev imports
using Revise
using Documenter
using JET
using OhMyREPL

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

        "--gui", "-g"
        help = "whether to run in the browser through a GUI instead of through the cli"
        action = :store_true
    end

    return parse_args(arg_settings)
end
precompile(parse_command_line_args, ())

"""
"""
function transfer_to_hpc(input_file::TransferFile, credentials::Credentials)
    @info "Now transferring $input_file to destination."

    @assert isfile(input_file.relative_path) "Input file path does not point to a file path that exists:\n$input_file.relative_path"

    # pull out the source path and interpolate the destination
    source_path = input_file.relative_path
    destination = interpolate_remote(
        credentials.username,
        credentials.address,
        remote_dir,
        input_file.dest_path,
    )

    # run the transfer asynchronously with rsync
    @try run_transfer(source_path, destination)

    # hash the original and destination files. The origin hash will take
    # place while the transfer finishes
    input_file.origin_hash = open(MD5.md5, source_path) |> bytes2hex
    input_file.destination_hash = open(MD5.md5, destination) |> bytes2hex

    # log a non-fatal error if the transfer fails according to hashes
    if input_file.origin_hash != input_file.destination_hash
        @error "$source_path failed to transfer successfully and may be corrupted or absent on the remote destination."
    end

    return
end
precompile(transfer_to_hpc, (TransferFile, Credentials))

"""
"""
function catalog_result_files() end
precompile(catalog_result_files, ())

"""
"""
function transfer_from_hpc(result_file::TransferFile, credentials::Credentials)
    @info "Now transferring $(result_file.relative_path) to destination."

    # pull out the source path and interpolate the destination
    source_path = interpolate_remote(
        credentials.username,
        credentials.address,
        remote_dir,
        result_file.relative_path,
    )
    destination = result_file.dest_path

    # run the transfer asynchronously with rsync
    @try run_transfer(source_path, destination)

    # hash the original and destination files. The origin hash will take
    # place while the transfer finishes
    result_file.origin_hash = open(MD5.md5, source_path) |> bytes2hex
    result_file.destination_hash = open(MD5.md5, destination) |> bytes2hex

    # log a non-fatal error if the transfer fails according to hashes
    if result_file.origin_hash != result_file.destination_hash
        @error "$destination failed to transfer successfully and may be corrupted or absent."
    end

    return
end
precompile(transfer_from_hpc, (TransferFile, Credentials))

"""
"""
function main()
    # parse command line args
    arg_dict = @try parse_command_line_args()

    # attempt to generate static config from Pkl file
    yaml_name = @try generate_config(arg_dict["config"])

    # parse config
    return credentials, command = @try parse_config(yaml_name)

    # catalog local files to be sent
    # queue = 

    # run the transfer onto the remote host
    # @try oversee_transfers(queue, credentials, true)

    # once the transfer has completed, run the command
    # @try run_hpc_command(command, credentials)

    # catalog the results files to be transferred
    # results_queue = @try catalog_result_files()

    # bring 'em home
    # @try oversee_transfers(results_queue, credentials, false)

end
precompile(main, ())

# main()
