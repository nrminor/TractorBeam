module TractorBeam

using ArgParse
using Base.Iterators
using Base.Threads: @threads
using Logging
using Pipe: @pipe
using MD5
using YAML


export Credentials,
    TransferFile,
    TransferQueue,
    generate_config,
    interpolate_remote,
    parse_config,
    make_local_file_queue,
    oversee_transfers,
    run_remote_command,
    make_result_file_queue

"""
"""

struct Credentials
    address::String
    username::String
    remote_dir::String
end


"""
"""
mutable struct TransferFile
    source_path::String
    dest_path::String
    origin_hash::String
    destination_hash::String
end


"""
"""
mutable struct TransferQueue
    files::Vector{TransferFile}
    member_count::Int
    remaining::Int
    progress::Float32
end


"""
"""
function generate_config(config_path::String)
    @assert isfile(config_path) "Provided config file name/path does not exist."
    yaml_name = "tractorbeam.yml"
    run(
        pipeline(
            `/usr/local/bin/pkl eval --format yaml $config_path`,
            yaml_name,
        ),
    )

    return yaml_name
end
precompile(generate_config, (String,))


"""
"""
function interpolate_remote(
    username::String,
    address::String,
    file_path::String,
)
    return "$(username)@$(address):$(file_path)"
end
precompile(interpolate_remote, (String, String, String))


"""
"""
function parse_config(yaml_name::String)
    # load the YAML with strict type enforcement (Pkl should already be
    # taking care of this, but it doesn't hurt to double-check)
    config_dict = YAML.load_file(yaml_name; dicttype = Dict{String, Any})

    credentials = Credentials(
        config_dict["address"],
        config_dict["username"],
        config_dict["remote_working_dir"],
    )
    results_dir = config_dict["local_results_dir"]
    local_dir = config_dict["inputs_to_transfer"]
    command = config_dict["command"]

    return (credentials, local_dir, results_dir, command)
end
precompile(parse_config, (String,))


"""
"""
function make_local_file_queue(
    dir_to_send::String,
    remote_dir::String,
)::TransferQueue

    # use a functional programming style pipeline to collect a vector of
    # all the local relative paths for all the files that will be sent.
    rel_paths = @pipe walkdir(dir_to_send) |>
          map(x -> [x[1], x[3]], _) |>
          flatmap(x -> [joinpath(x[begin], file) for file in x[end]], _) |>
          collect |>
          filter(
              x ->
                  !contains(x, ".DS_Store") & isfile(x) & !startswith(x, "._"),
              _,
          )

    # TODO
    # generate hashes for all the files to be transferred

    # create a vector of TransferFile instances that will themselves be
    # contained in an instance of the TransferQueue struct
    transfer_files = [
        TransferFile(source_path, remote_dir, "", "") for
        source_path in rel_paths
    ]

    # return the TransferQueue
    return TransferQueue(
        transfer_files,
        length(transfer_files),
        length(transfer_files),
        0.0,
    )
end
precompile(make_local_file_queue, (String, String))


"""
"""
function transfer_to_remote(input_file::TransferFile, credentials::Credentials)
    @info "Now using thread $(Threads.threadid()) to transfer $(basename(input_file.source_path)) to destination."

    @assert isfile(input_file.source_path) """
    Input file path does not point to a file path that exists:\n$(input_file.source_path)
    """

    # pull out the source path and interpolate the destination
    source_path = input_file.source_path
    destination = interpolate_remote(
        credentials.username,
        credentials.address,
        input_file.dest_path,
    )

    # run the transfer asynchronously with rsync
    run(`rsync -aqzR $source_path $destination`)

    # TODO:
    # hash the original and destination files. The origin hash will take
    # place while the transfer finishes
    input_file.origin_hash = open(MD5.md5, source_path) |> bytes2hex
    # input_file.destination_hash = open(MD5.md5, destination) |> bytes2hex

    # TODO:
    # log a non-fatal error if the transfer fails according to hashes
    # if input_file.origin_hash != input_file.destination_hash
    #     @error "$destination failed to transfer successfully and may be corrupted or absent on the remote destination."
    # end

end
precompile(transfer_to_remote, (TransferFile, Credentials))


"""
"""
function oversee_transfers(
    queue::TransferQueue,
    creds::Credentials,
    to_or::Bool,
)
    # print a warning if running on a single thread
    if Threads.nthreads() < 2
        @warn "TractorBeam appears to be running on a single thread, meaning that only one file can be transferred at a time. Performance may be slow."
    end

    # run as many transfers as there are CPU cores available to the Julia runtime
    @threads for file in queue.files
        if to_or
            transfer_to_remote(file, creds)
        else
            transfer_from_remote(file)
        end

        # TODO
        # this will probably cause a data race but oh well
        # queue.remaining = queue.member_count - i
        # queue.progress = queue.remaining / queue.member_count
    end
end
precompile(oversee_transfers, (TransferQueue, Bool))


"""
"""
function run_remote_command(command::String, creds::Credentials)
    # put together details for ssh
    ssh_details = "$(creds.username)@$(creds.address)"

    # run the command on the remote host
    return run(`ssh $ssh_details cd $(creds.remote_dir) \&\& $command`)
end
precompile(run_remote_command, (String, Credentials))


"""
"""
function make_result_file_queue(
    credentials::Credentials,
    remote_results_dir::String,
    local_results_dir::String,
)::TransferQueue

    username = credentials.username
    address = credentials.address
    host = "$username@$address"

    # lazily generate the the list of relative paths to be transferred back
    bring_em_home = @pipe read(
              `ssh $host cd $remote_results_dir \&\& find . -type f`,
              String,
          ) |>
          split(_, '\n') |>
          filter(x -> x != "") |>
          filter(x -> x |> !contains(".DS_Store")) |>
          replace.(_, "./" => "")

    # fill in the remaining parts for each relative path so we have
    # complete remote host address
    remote_paths = @pipe bring_em_home |>
          map(x -> "$host:$remote_results_dir/$x", _) |>
          collect

    # fill in the local output directory information so we know where
    # the files will eventually end up
    dest_paths = @pipe bring_em_home |>
          map(x -> "$local_results_dir/$x", _) |>
          collect |>
          dirname.(_) |>
          map(x -> "$x/", _)

    # TODO generate hashes for all the files to be transferred

    # create a vector of TransferFile instances that will themselves be
    # contained in an instance of the TransferQueue struct
    transfer_files = [
        TransferFile(source_path, dest_path, "", "") for
        (source_path, dest_path) in zip(remote_paths, dest_paths)
    ]

    # return the TransferQueue
    return TransferQueue(
        transfer_files,
        length(transfer_files),
        length(transfer_files),
        0.0,
    )
end
precompile(make_result_file_queue, (String, String))


"""
"""
function transfer_from_remote(result_file::TransferFile)
    @info "Now transferring $(basename(result_file.source_path)) back to local destination on thread $(Threads.threadid())."

    # run the transfer with rsync
    run(`mkdir -p $(result_file.dest_path)`)
    run(`rsync -aqz $(result_file.source_path) $(result_file.dest_path)`)

    # TODO:
    # hash the original and destination files. The origin hash will take
    # place while the transfer finishes
    # result_file.origin_hash = open(MD5.md5, source_path) |> bytes2hex
    # result_file.destination_hash = open(MD5.md5, destination) |> bytes2hex

    # TODO:
    # log a non-fatal error if the transfer fails according to hashes
    # if result_file.origin_hash != result_file.destination_hash
    #     @error "$destination failed to transfer successfully and may be corrupted or absent."
    # end

    return
end
precompile(transfer_from_remote, (TransferFile,))


end # module TractorBeam
